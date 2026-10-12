import Foundation

/// English UI language combined with the user's region (week start, 24h clock, number format).
enum AppLocale {
    static var current: Locale {
        Locale(identifier: "en_\(Locale.current.region?.identifier ?? "US")")
    }
}

extension Date {
    func appFormatted(_ style: Date.FormatStyle) -> String {
        formatted(style.locale(AppLocale.current))
    }
}
