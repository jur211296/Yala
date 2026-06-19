//
//  OnboardingMode.swift
//  Yala
//
//  Determines the onboarding experience based on how the user arrived.
//  Persisted via UserDefaults and synced via PreferenceSyncService (iCloud KV).
//

import Foundation

enum OnboardingMode: String, Codable {
    /// Default: new user without invitation, or existing user
    case full
    /// Arrived via group invitation link (reduced onboarding)
    case groupInvite
    /// Was groupInvite, activated full Yala experience
    case completed

    /// Ordering for never-downgrade merge rule.
    /// Remote sync never overwrites a higher-rank local value.
    var rank: Int {
        switch self {
        case .full: return 0
        case .groupInvite: return 1
        case .completed: return 2
        }
    }

    // MARK: - Persistence

    private static let key = "onboardingMode"

    /// Read from UserDefaults (fallback: .full)
    static func current() -> OnboardingMode {
        guard let raw = UserDefaults.standard.string(forKey: key),
              let mode = OnboardingMode(rawValue: raw) else { return .full }
        return mode
    }

    /// Write to UserDefaults
    static func setCurrent(_ mode: OnboardingMode) {
        UserDefaults.standard.set(mode.rawValue, forKey: key)
    }

    /// UserDefaults key (exposed for DataWipeService cleanup)
    static let userDefaultsKey = key
}
