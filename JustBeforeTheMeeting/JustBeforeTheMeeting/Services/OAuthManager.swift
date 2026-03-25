import AppKit
import AuthenticationServices
import CryptoKit
import Foundation

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
        (Bundle.main.object(forInfoDictionaryKey: "GoogleOAuthClientID") as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var redirectURI: String {
        (Bundle.main.object(forInfoDictionaryKey: "GoogleOAuthRedirectURI") as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "jbtm://oauth"
    }

    func accessToken() async throws -> String {
        guard let tokens else {
            throw OAuthError.notSignedIn
        }
        if tokens.expiry > Date().addingTimeInterval(60) {
            return tokens.accessToken
        }
        return try await refresh(using: tokens)
    }

    func signIn() async throws {
        guard !clientID.isEmpty else {
            throw OAuthError.missingClientID
        }

        let verifier = Self.randomCodeVerifier()
        let challenge = Self.codeChallenge(for: verifier)

        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent")
        ]

        guard let authURL = components.url else {
            throw OAuthError.invalidURL
        }

        let code = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: URL(string: redirectURI)?.scheme
            ) { callbackURL, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let callbackURL,
                      let items = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?.queryItems,
                      let code = items.first(where: { $0.name == "code" })?.value
                else {
                    continuation.resume(throwing: OAuthError.missingCode)
                    return
                }
                continuation.resume(returning: code)
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            if !session.start() {
                continuation.resume(throwing: OAuthError.sessionStartFailed)
            }
        }

        try await exchangeCode(code, verifier: verifier)
    }

    func signOut() {
        tokens = nil
        isAuthorized = false
        KeychainHelper.delete(account: keychainAccount)
    }

    private func exchangeCode(_ code: String, verifier: String) async throws {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "code": code,
            "client_id": clientID,
            "redirect_uri": redirectURI,
            "grant_type": "authorization_code",
            "code_verifier": verifier
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
        guard let refreshToken = current.refreshToken else {
            throw OAuthError.notSignedIn
        }

        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "client_id": clientID,
            "grant_type": "refresh_token",
            "refresh_token": refreshToken
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
        case sessionStartFailed
        case notSignedIn
        case tokenExchangeFailed(String)

        var errorDescription: String? {
            switch self {
            case .missingClientID:
                return "Set GoogleOAuthClientID in Info.plist (Google Cloud OAuth client)."
            case .invalidURL:
                return "Invalid OAuth URL."
            case .missingCode:
                return "OAuth did not return an authorization code."
            case .sessionStartFailed:
                return "Could not start sign-in session."
            case .notSignedIn:
                return "Not signed in to Google."
            case let .tokenExchangeFailed(msg):
                return "Token exchange failed: \(msg)"
            }
        }
    }
}

extension OAuthManager: ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        var anchor: ASPresentationAnchor!
        DispatchQueue.main.sync {
            if let w = NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isVisible }) {
                anchor = w
            } else {
                let w = NSWindow(
                    contentRect: NSRect(x: 0, y: 0, width: 1, height: 1),
                    styleMask: [.borderless],
                    backing: .buffered,
                    defer: false
                )
                w.alphaValue = 0.01
                w.orderFrontRegardless()
                anchor = w
            }
        }
        return anchor
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
