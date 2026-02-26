//
//  AppConstants.swift
//  Yala
//
//  App-wide constants (URLs, limits, etc.)
//

import Foundation

enum AppConstants {
    static var termsURL: URL {
        URL(string: "https://yala-app.pe/\(localePath)terms")!
    }

    static var privacyURL: URL {
        URL(string: "https://yala-app.pe/\(localePath)privacy")!
    }

    /// Returns locale prefix for web URLs (empty for es, "en/" for English, etc.)
    private static var localePath: String {
        guard let lang = Bundle.main.preferredLocalizations.first else { return "" }
        switch lang {
        case "es": return ""
        case "en": return "en/"
        case "de": return "de/"
        case "fr": return "fr/"
        case "it": return "it/"
        case "pt": return "pt/"
        default: return "en/"
        }
    }
    static let supportEmail = "admin@yala-app.pe"

    /// Default fallback color hex for categories/budgets (Electric Indigo)
    static let defaultColorHex = "#6366F1"
    /// Default subcategory fallback color hex (Neutral Gray)
    static let defaultSubcategoryColorHex = "#9CA3AF"
    /// Default "Others/Remaining" color hex (System Gray)
    static let othersColorHex = "#8E8E93"
}
