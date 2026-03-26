import Foundation

extension Notification.Name {
    /// Posted when the user changes app UI language in Settings (en / tr).
    static let jbtmUILanguageDidChange = Notification.Name("jbtmUILanguageDidChange")
}

/// Centralized `Localizable.strings` lookups. Language is chosen in Settings (default English), not from the system locale.
enum L10n {
    /// Must match `SettingsManager`’s UserDefaults key.
    static let uiLanguageDefaultsKey = "jbtm.uiLanguage"

    private static var englishBundle: Bundle {
        Bundle.main.path(forResource: "en", ofType: "lproj").flatMap { Bundle(path: $0) } ?? .main
    }

    private static var useTurkishUI: Bool {
        (UserDefaults.standard.string(forKey: uiLanguageDefaultsKey) ?? "en") == "tr"
    }

    private static var turkishBundle: Bundle? {
        Bundle.main.path(forResource: "tr", ofType: "lproj").flatMap { Bundle(path: $0) }
    }

    private static var formatLocale: Locale {
        Locale(identifier: useTurkishUI ? "tr_TR" : "en_US")
    }

    static func s(_ key: String) -> String {
        if useTurkishUI, let tr = turkishBundle {
            let r = tr.localizedString(forKey: key, value: nil, table: "Localizable")
            if r != key { return r }
        }
        return englishBundle.localizedString(forKey: key, value: nil, table: "Localizable")
    }

    static func s(_ key: String, _ args: CVarArg...) -> String {
        String(format: s(key), locale: formatLocale, arguments: args)
    }
}
