import Foundation

nonisolated enum L10n {
    static func text(_ key: String) -> String {
        AppResources.bundle.localizedString(forKey: key, value: key, table: nil)
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: text(key), locale: Locale.current, arguments: arguments)
    }

    static var language: String { AppResources.bundle.preferredLocalizations.first ?? "en" }
}
