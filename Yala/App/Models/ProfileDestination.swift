//
//  ProfileDestination.swift
//  Yala
//
//  Navigation destinations for ProfileView NavigationStack.
//

import Foundation

/// Destinations for Profile NavigationStack.
/// Extracted to its own file so other modules (e.g. SessionState) can reference it
/// without depending on ProfileView.
enum ProfileDestination: Hashable {
    case accounts
    case categories
    case tags
    case themes
    case personalization
    case currency
    case appIcon
    case notifications
    case favorites
    case budgets
    case planned
    case userDataReset
    case biometricSecurity
    case subscription
    case tips
    case faq
    case iCloudSync
    case siriShortcuts
}
