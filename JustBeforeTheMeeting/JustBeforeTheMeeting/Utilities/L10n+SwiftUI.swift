import SwiftUI

extension L10n {
    /// Renders a localized string that may contain inline Markdown (e.g. `**bold**`).
    static func markdown(_ key: String) -> Text {
        let raw = s(key)
        if let a = try? AttributedString(markdown: raw) {
            return Text(a)
        }
        return Text(raw)
    }

    static func markdownFormat(_ key: String, _ args: CVarArg...) -> Text {
        let formatted = String(format: s(key), locale: .current, arguments: args)
        if let a = try? AttributedString(markdown: formatted) {
            return Text(a)
        }
        return Text(formatted)
    }
}
