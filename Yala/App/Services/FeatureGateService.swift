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
    case proThemes
    case smartInsightsAI
    case cashFlowAdvanced    // Base feature is Free; advanced methods/horizon/charts are Pro
    case exportExtendedPeriods // Free: week/month periods; Pro: year, all time, custom
    case chatAssistant       // Ask Yala: AI chat assistant (Pro only)

    /// Free tier limit for countable features (nil = no limit in free tier)
    var freeLimit: Int? {
        switch self {
        case .accounts: return 4
        case .budgets: return 3
        default: return nil
        }
    }

    /// Whether this feature is completely unavailable in Free tier
    var isProOnly: Bool {
        switch self {
        case .voiceInput, .imageInput, .premiumIcons, .proThemes, .smartInsightsAI, .exportExtendedPeriods, .chatAssistant: return true
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
        case .proThemes: return L10n.FeatureGate.proThemes
        case .smartInsightsAI: return L10n.FeatureGate.smartInsightsAI
        case .cashFlowAdvanced: return L10n.FeatureGate.cashFlowAdvanced
        case .exportExtendedPeriods: return L10n.FeatureGate.exportExtendedPeriods
        case .chatAssistant: return L10n.FeatureGate.chatAssistant
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
        case .proThemes: return "paintpalette.fill"
        case .smartInsightsAI: return "sparkles"
        case .cashFlowAdvanced: return "arrow.left.arrow.right"
        case .exportExtendedPeriods: return "calendar.badge.clock"
        case .chatAssistant: return "bubble.left.and.text.bubble.right"
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

    // MARK: - Pro Status

    /// Whether the current user has Pro access (based on real subscription status)
    var isProUser: Bool {
        StoreKitManager.shared.isProUser
    }

    // MARK: - Setup Trial Bypass

    /// Features temporarily unlocked for setup checklist trial steps.
    private(set) var setupTrialFeatures: Set<ProFeature> = []

    /// Enable temporary access to a Pro feature during a setup trial step.
    func enableSetupTrial(for feature: ProFeature) {
        setupTrialFeatures.insert(feature)
    }

    /// Disable temporary access after the setup trial step completes or is dismissed.
    func disableSetupTrial(for feature: ProFeature) {
        setupTrialFeatures.remove(feature)
    }

    // MARK: - Access Checks

    /// Check if user can access a Pro-only feature
    /// - Parameter feature: The feature to check
    /// - Returns: true if user has access (either Pro or feature isn't Pro-only)
    func canAccess(_ feature: ProFeature) -> Bool {
        if isProUser { return true }
        if setupTrialFeatures.contains(feature) { return true }
        if feature.isProOnly {
            var params = TelemetryService.upsellParameters(source: "featureGate")
            params["feature"] = feature.rawValue
            TelemetryService.trackOnce(.featureGateHit, key: feature.rawValue, parameters: params)
        }
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
        static var proThemes: String {
            NSLocalizedString("featureGate.proThemes", comment: "Pro themes feature name")
        }
        static var smartInsightsAI: String {
            NSLocalizedString("featureGate.smartInsightsAI", comment: "Smart Insights AI feature name")
        }
        static var cashFlowAdvanced: String {
            NSLocalizedString("featureGate.cashFlowAdvanced", comment: "Cash flow advanced feature name")
        }
        static var exportExtendedPeriods: String {
            NSLocalizedString("featureGate.exportExtendedPeriods", comment: "Export extended periods feature name")
        }
        static var chatAssistant: String {
            NSLocalizedString("featureGate.chatAssistant", comment: "Chat assistant feature name")
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
