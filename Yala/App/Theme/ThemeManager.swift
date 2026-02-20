//
//  ThemeManager.swift
//  Yala
//
//  Observable theme manager that resolves the active YalaTheme
//  based on user choice and system color scheme.
//

import SwiftUI

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
        }
    }
}
