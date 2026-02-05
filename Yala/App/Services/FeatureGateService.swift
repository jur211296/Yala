//
//  FeatureGateService.swift
//  Yala
//
//  Centralized feature gating service for Pro vs Free tier.
//

import SwiftUI

// MARK: - Pro Feature Enum

/// All features that differ between Pro and Free tiers
enum ProFeature: String, CaseIterable {
    case accounts
    case budgets
    case voiceInput
    case imageInput
    case premiumIcons

    /// Free tier limit for countable features (nil = no limit in free tier)
    var freeLimit: Int? {
        switch self {
        case .accounts: return 2
        case .budgets: return 3
        default: return nil
        }
    }

    /// Whether this feature is completely unavailable in Free tier
    var isProOnly: Bool {
        switch self {
        case .voiceInput, .imageInput, .premiumIcons: return true
        default: return false
        }
    }

    /// Localized name for UI messages
    var localizedName: String {
        switch self {
        case .accounts: return L10n.FeatureGate.accounts
        case .budgets: return L10n.FeatureGate.budgets
        case .voiceInput: return L10n.FeatureGate.voiceInput
        case .imageInput: return L10n.FeatureGate.imageInput
        case .premiumIcons: return L10n.FeatureGate.premiumIcons
        }
    }

    /// SF Symbol icon for the feature
    var icon: String {
        switch self {
        case .accounts: return "building.columns.fill"
        case .budgets: return "chart.pie.fill"
        case .voiceInput: return "waveform"
        case .imageInput: return "camera.fill"
        case .premiumIcons: return "app.fill"
        }
    }
}

// MARK: - Feature Gate Service

/// Centralized service for checking feature access based on subscription status
@MainActor
@Observable
final class FeatureGateService {

    // MARK: - Singleton

    static let shared = FeatureGateService()

    private init() {}

    // MARK: - Build Detection

    /// Whether this is the Dev build (bundle ID ends with .dev)
    static var isDevBuild: Bool {
        guard let bundleID = Bundle.main.bundleIdentifier else { return false }
        return bundleID.lowercased().hasSuffix(".dev")
    }

    // MARK: - Dev Build Toggle

    /// Key for dev build Pro simulation toggle
    private static let devSimulateProKey = "dev.simulateProUser"

    /// In Dev builds: toggle to simulate Pro (default true)
    /// This is persisted and can be changed from Settings
    /// Using stored property so @Observable can track changes
    private var _devSimulatePro: Bool = {
        // Default to true (Pro) if key hasn't been set
        if UserDefaults.standard.object(forKey: devSimulateProKey) == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: devSimulateProKey)
    }()

    var devSimulatePro: Bool {
        get { _devSimulatePro }
        set {
            _devSimulatePro = newValue
            UserDefaults.standard.set(newValue, forKey: Self.devSimulateProKey)
        }
    }

    // MARK: - Pro Status

    /// Whether the current user has Pro access
    /// - Dev build: Based on devSimulatePro toggle (default Pro)
    /// - Production build: Based on real subscription status
    var isProUser: Bool {
        // Dev build uses toggle from Settings
        if Self.isDevBuild {
            return devSimulatePro
        }

        // Production build uses real subscription status
        return StoreKitManager.shared.isProUser
    }

    // MARK: - Access Checks

    /// Check if user can access a Pro-only feature
    /// - Parameter feature: The feature to check
    /// - Returns: true if user has access (either Pro or feature isn't Pro-only)
    func canAccess(_ feature: ProFeature) -> Bool {
        if isProUser { return true }
        return !feature.isProOnly
    }

    /// Check if user can create another item of a limited feature
    /// - Parameters:
    ///   - feature: The feature with limits (accounts, budgets)
    ///   - currentCount: Current number of active items
    /// - Returns: true if user can create more (either Pro or under limit)
    func canCreate(_ feature: ProFeature, currentCount: Int) -> Bool {
        if isProUser { return true }
        guard let limit = feature.freeLimit else { return true }
        return currentCount < limit
    }

    /// Get remaining count before hitting limit
    /// - Parameters:
    ///   - feature: The feature with limits
    ///   - currentCount: Current number of active items
    /// - Returns: Number of items user can still create (0 if at limit, Int.max if Pro)
    func remainingCount(_ feature: ProFeature, currentCount: Int) -> Int {
        if isProUser { return Int.max }
        guard let limit = feature.freeLimit else { return Int.max }
        return max(0, limit - currentCount)
    }

    /// Check if user has reached the free tier limit
    /// - Parameters:
    ///   - feature: The feature with limits
    ///   - currentCount: Current number of active items
    /// - Returns: true if at or over limit (and not Pro)
    func isAtLimit(_ feature: ProFeature, currentCount: Int) -> Bool {
        if isProUser { return false }
        guard let limit = feature.freeLimit else { return false }
        return currentCount >= limit
    }

    /// Get the free tier limit for a feature
    /// - Parameter feature: The feature to check
    /// - Returns: The limit, or nil if unlimited
    func freeLimit(for feature: ProFeature) -> Int? {
        feature.freeLimit
    }
}

// MARK: - L10n Extension for FeatureGate

extension L10n {
    enum FeatureGate {
        // Feature names
        static var accounts: String {
            NSLocalizedString("featureGate.accounts", comment: "Accounts feature name")
        }
        static var budgets: String {
            NSLocalizedString("featureGate.budgets", comment: "Budgets feature name")
        }
        static var voiceInput: String {
            NSLocalizedString("featureGate.voiceInput", comment: "Voice input feature name")
        }
        static var imageInput: String {
            NSLocalizedString("featureGate.imageInput", comment: "Image input feature name")
        }
        static var premiumIcons: String {
            NSLocalizedString("featureGate.premiumIcons", comment: "Premium icons feature name")
        }

        // Titles
        static var limitReachedTitle: String {
            NSLocalizedString("featureGate.limitReachedTitle", comment: "Limit reached sheet title")
        }
        static var proFeatureTitle: String {
            NSLocalizedString("featureGate.proFeatureTitle", comment: "Pro feature sheet title")
        }
        static var trialExpiredTitle: String {
            NSLocalizedString("featureGate.trialExpiredTitle", comment: "Trial expired sheet title")
        }

        // Messages
        static func limitReachedMessage(_ feature: String) -> String {
            String(
                format: NSLocalizedString("featureGate.limitReachedMessage", comment: ""),
                feature
            )
        }
        static func proFeatureMessage(_ feature: String) -> String {
            String(
                format: NSLocalizedString("featureGate.proFeatureMessage", comment: ""),
                feature
            )
        }
        static var trialExpiredMessage: String {
            NSLocalizedString("featureGate.trialExpiredMessage", comment: "Trial expired message")
        }

        // Actions
        static var upgradeToPro: String {
            NSLocalizedString("featureGate.upgradeToPro", comment: "Upgrade to Pro button")
        }
        static var upgrade: String {
            NSLocalizedString("featureGate.upgrade", comment: "Upgrade button short")
        }
        static var upgradeForMore: String {
            NSLocalizedString("featureGate.upgradeForMore", comment: "Upgrade for more subtitle")
        }

        // Limit info
        static func limitInfo(_ current: Int, _ max: Int) -> String {
            String(
                format: NSLocalizedString("featureGate.limitInfo", comment: ""),
                current,
                max
            )
        }
    }
}
