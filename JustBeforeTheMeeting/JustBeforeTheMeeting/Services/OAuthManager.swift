import AppKit
import CryptoKit
import Foundation
import Network

private struct OAuthTokens: Codable {
    var accessToken: String
    var refreshToken: String?
    var expiry: Date
}

@MainActor
final class OAuthManager: NSObject, ObservableObject {
    @Published private(set) var isAuthorized = false

    private let settings: SettingsManager
    private var tokens: OAuthTokens?

    private let keychainAccount = "google.oauth.tokens"
    private let scope = "https://www.googleapis.com/auth/calendar.readonly"

    init(settings: SettingsManager) {
        self.settings = settings
        super.init()
        loadTokensFromKeychain()
    }

    var clientID: String {
        (Bundle.main.object(forInfoDictionaryKey: "GoogleOAuthClientID") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    func accessToken() async throws -> String {
        guard let tokens else { throw OAuthError.notSignedIn }
        if tokens.expiry > Date().addingTimeInterval(60) {
            return tokens.accessToken
        }
        return try await refresh(using: tokens)
    }

    /// Opens the user's browser for Google sign-in using a local loopback redirect.
    func signIn() async throws {
        guard !clientID.isEmpty else { throw OAuthError.missingClientID }

        let verifier = Self.randomCodeVerifier()
        let challenge = Self.codeChallenge(for: verifier)

        let (port, codeFuture) = try await startLoopbackServer()
        let redirectURI = "http://127.0.0.1:\(port)"

        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent"),
        ]

        guard let authURL = components.url else { throw OAuthError.invalidURL }
        NSWorkspace.shared.open(authURL)

        let code = try await codeFuture()
        try await exchangeCode(code, verifier: verifier, redirectURI: redirectURI)
    }

    func signOut() {
        tokens = nil
        isAuthorized = false
        KeychainHelper.delete(account: keychainAccount)
    }

    // MARK: - Loopback HTTP server

    /// Starts a tiny HTTP server on a random port. Returns `(port, asyncClosure)`.
    /// The closure suspends until Google redirects the browser back with a `?code=`.
    private func startLoopbackServer() async throws -> (UInt16, () async throws -> String) {
        let serverSocket = try Self.createListeningSocket()
        let port = try Self.boundPort(of: serverSocket)

        let future: () async throws -> String = {
            try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    Self.acceptOneRequest(socket: serverSocket, continuation: continuation)
                }
            }
        }
        return (port, future)
    }

    private static func createListeningSocket() throws -> Int32 {
        let sock = socket(AF_INET, SOCK_STREAM, 0)
        guard sock >= 0 else { throw OAuthError.loopbackServerFailed }
        var reuse: Int32 = 1
        setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = 0 // random port
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")

        let bindResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.bind(sock, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
        }
        guard bindResult == 0 else { close(sock); throw OAuthError.loopbackServerFailed }
        guard listen(sock, 1) == 0 else { close(sock); throw OAuthError.loopbackServerFailed }
        return sock
    }

    private static func boundPort(of sock: Int32) throws -> UInt16 {
        var addr = sockaddr_in()
        var len = socklen_t(MemoryLayout<sockaddr_in>.size)
        let result = withUnsafeMutablePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(sock, $0, &len) }
        }
        guard result == 0 else { throw OAuthError.loopbackServerFailed }
        return UInt16(bigEndian: addr.sin_port)
    }

    private static func acceptOneRequest(socket serverSocket: Int32, continuation: CheckedContinuation<String, Error>) {
        let client = accept(serverSocket, nil, nil)
        close(serverSocket)
        guard client >= 0 else {
            continuation.resume(throwing: OAuthError.loopbackServerFailed)
            return
        }

        var buf = [UInt8](repeating: 0, count: 8192)
        let n = read(client, &buf, buf.count)
        let requestString = n > 0 ? String(bytes: buf[0 ..< n], encoding: .utf8) ?? "" : ""

        guard let firstLine = requestString.split(separator: "\r\n").first,
              let pathPart = firstLine.split(separator: " ").dropFirst().first,
              let urlComponents = URLComponents(string: String(pathPart)),
              let code = urlComponents.queryItems?.first(where: { $0.name == "code" })?.value
        else {
            let errorBody = """
            <html><body><h2>Sign-in failed</h2><p>No authorization code received. Close this tab and try again.</p></body></html>
            """
            Self.sendHTTPResponse(to: client, body: errorBody)
            close(client)
            continuation.resume(throwing: OAuthError.missingCode)
            return
        }

        let successBody = """
        <html><body style="font-family:-apple-system,sans-serif;text-align:center;padding:60px">
        <h2>Signed in!</h2><p>You can close this tab and return to <b>Just Before The Meeting</b>.</p>
        </body></html>
        """
        Self.sendHTTPResponse(to: client, body: successBody)
        close(client)
        continuation.resume(returning: code)
    }

    private static func sendHTTPResponse(to client: Int32, body: String) {
        let response = "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nConnection: close\r\n\r\n\(body)"
        _ = response.withCString { ptr in write(client, ptr, strlen(ptr)) }
    }

    // MARK: - Token exchange

    private func exchangeCode(_ code: String, verifier: String, redirectURI: String) async throws {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "code": code,
            "client_id": clientID,
            "redirect_uri": redirectURI,
            "grant_type": "authorization_code",
            "code_verifier": verifier,
        ]
        request.httpBody = Self.formURLEncoded(body).data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
            throw OAuthError.tokenExchangeFailed(String(data: data, encoding: .utf8) ?? "")
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let access = json?["access_token"] as? String else {
            throw OAuthError.tokenExchangeFailed("No access_token")
        }
        let refresh = json?["refresh_token"] as? String
        let expiresIn = (json?["expires_in"] as? NSNumber)?.doubleValue ?? 3600
        let expiry = Date().addingTimeInterval(expiresIn)

        let stored = OAuthTokens(accessToken: access, refreshToken: refresh ?? tokens?.refreshToken, expiry: expiry)
        tokens = stored
        isAuthorized = true
        try saveTokens(stored)
    }

    private func refresh(using current: OAuthTokens) async throws -> String {
        guard let refreshToken = current.refreshToken else { throw OAuthError.notSignedIn }

        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "client_id": clientID,
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
        ]
        request.httpBody = Self.formURLEncoded(body).data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
            throw OAuthError.tokenExchangeFailed(String(data: data, encoding: .utf8) ?? "")
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let access = json?["access_token"] as? String else {
            throw OAuthError.tokenExchangeFailed("No access_token on refresh")
        }
        let expiresIn = (json?["expires_in"] as? NSNumber)?.doubleValue ?? 3600
        let expiry = Date().addingTimeInterval(expiresIn)

        let updated = OAuthTokens(accessToken: access, refreshToken: refreshToken, expiry: expiry)
        tokens = updated
        try saveTokens(updated)
        return access
    }

    // MARK: - Keychain

    private func saveTokens(_ t: OAuthTokens) throws {
        let data = try JSONEncoder().encode(t)
        try KeychainHelper.save(data, account: keychainAccount)
    }

    private func loadTokensFromKeychain() {
        guard let data = try? KeychainHelper.load(account: keychainAccount),
              let decoded = try? JSONDecoder().decode(OAuthTokens.self, from: data)
        else {
            isAuthorized = false
            return
        }
        tokens = decoded
        isAuthorized = true
    }

    // MARK: - Helpers

    private static func formURLEncoded(_ dict: [String: String]) -> String {
        dict
            .map { key, value in
                let k = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
                let v = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
                return "\(k)=\(v)"
            }
            .joined(separator: "&")
    }

    private static func randomCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64URLEncodedString()
    }

    private static func codeChallenge(for verifier: String) -> String {
        let data = Data(verifier.utf8)
        let hash = SHA256.hash(data: data)
        return Data(hash).base64URLEncodedString()
    }

    enum OAuthError: LocalizedError {
        case missingClientID
        case invalidURL
        case missingCode
        case notSignedIn
        case tokenExchangeFailed(String)
        case loopbackServerFailed

        var errorDescription: String? {
            switch self {
            case .missingClientID:
                return "Set GoogleOAuthClientID in Info.plist (Google Cloud OAuth client)."
            case .invalidURL:
                return "Invalid OAuth URL."
            case .missingCode:
                return "OAuth did not return an authorization code."
            case .notSignedIn:
                return "Not signed in to Google."
            case let .tokenExchangeFailed(msg):
                return "Token exchange failed: \(msg)"
            case .loopbackServerFailed:
                return "Could not start local sign-in server."
            }
        }
    }
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
