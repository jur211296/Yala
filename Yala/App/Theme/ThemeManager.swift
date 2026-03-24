//
//  ThemeManager.swift
//  Yala
//
//  Observable theme manager that resolves the active YalaTheme
//  based on user choice and system color scheme.
//

import SwiftUI

// MARK: - Translucent Gradient Variant

enum TranslucentVariant: Int, CaseIterable, Identifiable {
    case indigo = 0
    case rosa = 1
    case teal = 2

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .indigo: return L10n.Settings.themeIndigo
        case .rosa: return L10n.Settings.themeRosa
        case .teal: return L10n.Settings.themeTeal
        }
    }

    var iconColor: Color {
        switch self {
        case .indigo: return .electricIndigo
        case .rosa: return .hotPink
        case .teal: return .priorityNeed
        }
    }
}

// MARK: - Theme Manager

@MainActor @Observable
final class ThemeManager {

    /// The user's persisted theme choice (stored property so @Observable tracks it)
    var userChoice: AppTheme = AppTheme(
        rawValue: UserDefaults.standard.integer(forKey: "userTheme")
    ) ?? .system {
        didSet {
            UserDefaults.standard.set(userChoice.rawValue, forKey: "userTheme")
        }
    }

    /// Gradient color variant for the Translucent theme
    var translucentVariant: TranslucentVariant = TranslucentVariant(
        rawValue: UserDefaults.standard.integer(forKey: "translucentVariant")
    ) ?? .indigo {
        didSet {
            UserDefaults.standard.set(translucentVariant.rawValue, forKey: "translucentVariant")
        }
    }

    /// Updated from YalaApp's onChange(of: colorScheme)
    var systemColorScheme: ColorScheme = .light

    /// The fully resolved theme palette
    var resolved: YalaTheme {
        switch userChoice {
        case .system:
            return systemColorScheme == .dark ? .dark : .light
        case .light:
            return .light
        case .dark:
            return .dark
        case .indigo:
            return .indigo
        case .rosa:
            return .rosa
        case .teal:
            return .teal
        case .minimalist:
            return .minimalist
        case .translucent:
            switch translucentVariant {
            case .indigo: return .translucent
            case .rosa: return .translucentRosa
            case .teal: return .translucentTeal
            }
        }
    }
}
