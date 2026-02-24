//
//  AppConstants.swift
//  Yala
//
//  App-wide constants (URLs, limits, etc.)
//

import Foundation

enum AppConstants {
    static let termsURL = URL(string: "https://yala-app.pe/terms")!
    static let privacyURL = URL(string: "https://yala-app.pe/privacy")!
    static let supportEmail = "admin@yala-app.pe"

    /// Default fallback color hex for categories/budgets (Electric Indigo)
    static let defaultColorHex = "#6366F1"
    /// Default subcategory fallback color hex (Neutral Gray)
    static let defaultSubcategoryColorHex = "#9CA3AF"
    /// Default "Others/Remaining" color hex (System Gray)
    static let othersColorHex = "#8E8E93"
}
