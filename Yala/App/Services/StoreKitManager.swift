//
//  StoreKitManager.swift
//  Yala
//
//  Manages in-app subscriptions using StoreKit 2.
//

import StoreKit
import SwiftUI

/// Manages StoreKit 2 subscription products, purchases, and entitlements.
@MainActor @Observable
final class StoreKitManager {

    static let shared = StoreKitManager()

    // MARK: - Product IDs

    /// Product identifiers configured in App Store Connect
    static let proMonthlyID = "com.yala.pro.monthly"
    static let proYearlyID = "com.yala.pro.yearly"

    // MARK: - State

    /// Available subscription products
    private(set) var products: [Product] = []

    /// Currently active subscription (if any)
    private(set) var activeSubscription: StoreKit.Transaction?

    /// Whether the user has an active Pro subscription
    private(set) var isProUser: Bool = false

    /// Loading state for purchases
    private(set) var isPurchasing: Bool = false

    /// Error message to display
    var errorMessage: String?

    // MARK: - Trial State

    /// Whether user is currently in a trial period
    private(set) var isInTrial: Bool = false

    /// Trial end date (if in trial)
    private(set) var trialEndDate: Date?

    /// Subscription expiration date
    private(set) var subscriptionExpirationDate: Date?

    /// Days remaining in trial
    var trialDaysRemaining: Int {
        guard let endDate = trialEndDate else { return 0 }
        let days = Calendar.current.dateComponents([.day], from: Date.now, to: endDate).day ?? 0
        return max(0, days)
    }

    /// Whether trial is expiring soon (5 days or less)
    var isTrialExpiringSoon: Bool {
        isInTrial && trialDaysRemaining <= 5 && trialDaysRemaining > 0
    }

    // MARK: - Downgrade Detection

    private let wasProUserKey = "yala.wasProUser"

    /// Whether user was previously a Pro user (persisted)
    var wasProUser: Bool {
        get { UserDefaults.standard.bool(forKey: wasProUserKey) }
        set { UserDefaults.standard.set(newValue, forKey: wasProUserKey) }
    }

    /// Whether user just downgraded from Pro to Free
    var justDowngraded: Bool {
        wasProUser && !isProUser
    }

    // MARK: - Post-Purchase State

    /// Flag to trigger celebration animation after successful purchase
    var didJustSubscribe: Bool = false

    // MARK: - App Group

    /// App Group identifier for sharing state with widgets
    private let appGroupID = "group.com.yala.shared"

    // MARK: - Private

    private var transactionListener: Task<Void, Never>?

    #if DEBUG
    private static let devForceFreeTierKey = "dev.forceFreeTier"
    private static let devForceProTierKey = "dev.forceProTier"

    /// Dev-only flag: when true, forces free tier regardless of StoreKit entitlements.
    /// Persisted to UserDefaults so it survives app restart. Only works with dev bundle.
    private(set) var devForceFreeTier: Bool = false

    /// Dev-only flag: when true, forces Pro tier regardless of StoreKit entitlements.
    /// Persisted to UserDefaults so it survives app restart. Only works with dev bundle.
    private(set) var devForceProTier: Bool = false
    #endif

    // MARK: - Init

    private init() {
        #if DEBUG
        if Bundle.main.bundleIdentifier?.hasSuffix(".dev") == true {
            devForceFreeTier = UserDefaults.standard.bool(forKey: Self.devForceFreeTierKey)
            devForceProTier = UserDefaults.standard.bool(forKey: Self.devForceProTierKey)
            // Enforce mutual exclusion — Pro wins if both set
            if devForceFreeTier && devForceProTier {
                devForceFreeTier = false
                UserDefaults.standard.removeObject(forKey: Self.devForceFreeTierKey)
            }
            if devForceProTier {
                isProUser = true
            }
        }
        #endif
        transactionListener = listenForTransactions()
    }

    nonisolated deinit {
        // transactionListener is cancelled automatically when StoreKitManager is deallocated
    }

    // MARK: - Load Products

    /// Fetches available subscription products from App Store Connect
    func loadProducts() async {
        do {
            let productIDs: Set<String> = [
                Self.proMonthlyID,
                Self.proYearlyID,
            ]
            #if DEBUG
            print("StoreKitManager: Loading products for IDs: \(productIDs)")
            #endif
            let storeProducts = try await Product.products(for: productIDs)
            #if DEBUG
            print("StoreKitManager: Loaded \(storeProducts.count) products")
            for p in storeProducts {
                let intro = p.subscription?.introductoryOffer
                print("  - \(p.id): \(p.displayPrice), hasIntro: \(intro != nil), period: \(intro?.period.debugDescription ?? "none")")
            }
            #endif
            // Sort: yearly first (better value), then monthly
            products = storeProducts.sorted { p1, _ in
                p1.id == Self.proYearlyID
            }
        } catch {
            #if DEBUG
            print("StoreKitManager: Error loading products: \(error)")
            #endif
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Purchase

    /// Purchase a subscription product
    func purchase(_ product: Product) async -> Bool {
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                #if DEBUG
                devForceFreeTier = false
                devForceProTier = false
                UserDefaults.standard.removeObject(forKey: Self.devForceFreeTierKey)
                UserDefaults.standard.removeObject(forKey: Self.devForceProTierKey)
                #endif
                await updateSubscriptionStatus()
                didJustSubscribe = true
                TelemetryService.track(.purchaseAttempted, parameters: ["productId": product.id, "result": "success"])
                var completionParams = TelemetryService.upsellParameters(source: "purchase")
                completionParams["productId"] = product.id
                completionParams["plan"] = product.id.localizedCaseInsensitiveContains("year") ? "anual" : "mensual"
                TelemetryService.track(.purchaseCompleted, parameters: completionParams)
                if isInTrial {
                    TelemetryService.track(.trialStarted, parameters: completionParams)
                }
                return true

            case .userCancelled:
                TelemetryService.track(.purchaseAttempted, parameters: ["productId": product.id, "result": "cancelled"])
                return false

            case .pending:
                TelemetryService.track(.purchaseAttempted, parameters: ["productId": product.id, "result": "pending"])
                return false

            @unknown default:
                return false
            }
        } catch {
            TelemetryService.track(.purchaseAttempted, parameters: ["productId": product.id, "result": "error"])
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Restore

    /// Restore previous purchases
    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await updateSubscriptionStatus()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Subscription Status

    /// Check current entitlements and update subscription state
    func updateSubscriptionStatus() async {
        #if DEBUG
        // Cada rama DEV early-return DEBE syncear a App Group: el flag `isProUser`
        // queda consistente cross-process (intents, widgets). Sin esto, SiriNatural
        // en Yala Dev nunca pasa el gate Pro aunque "Simular Pro" esté ON.
        if devForceFreeTier {
            isProUser = false
            syncToAppGroup()
            return
        }
        if devForceProTier {
            isProUser = true
            syncToAppGroup()
            return
        }
        // Dev build: default to Free — Configuration.storekit provides sandbox
        // entitlements that would otherwise always grant Pro
        if Bundle.main.bundleIdentifier?.hasSuffix(".dev") == true {
            isProUser = false
            syncToAppGroup()
            return
        }
        #endif

        let previouslyInTrial = isInTrial

        var foundActive: StoreKit.Transaction?

        for await result in StoreKit.Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                if transaction.productType == .autoRenewable {
                    foundActive = transaction
                }
            } catch {
                #if DEBUG
                print("StoreKitManager: Transaction verification failed: \(error)")
                #endif
            }
        }

        activeSubscription = foundActive
        let nowProUser = foundActive != nil

        // Detect trial via offer type
        if let transaction = foundActive {
            isInTrial = transaction.offer?.type == .introductory
            trialEndDate = isInTrial ? transaction.expirationDate : nil
            subscriptionExpirationDate = transaction.expirationDate
        } else {
            isInTrial = false
            trialEndDate = nil
            subscriptionExpirationDate = nil
        }

        // Force chat FAB visible when transitioning to Pro
        let wasAlreadyPro = isProUser

        // Update Pro status
        isProUser = nowProUser

        if nowProUser && !wasAlreadyPro {
            UserDefaults.standard.set(true, forKey: "chatFABVisible")
        }

        if wasAlreadyPro && !nowProUser {
            TelemetryService.track(.subscriptionEnded, parameters: ["era_trial": String(previouslyInTrial)])
        }

        // Track for downgrade detection
        if isProUser {
            wasProUser = true
        }

        // Sync to App Group for widgets
        syncToAppGroup()
    }

    /// Sync subscription state to App Group for widget access
    func syncToAppGroup() {
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            #if DEBUG
            print("StoreKitManager: Failed to access App Group")
            #endif
            return
        }
        defaults.set(isProUser, forKey: "isProUser")
        defaults.synchronize()
    }

    // MARK: - Trial Eligibility

    /// Check if the user is eligible for any introductory offer (free trial)
    func isEligibleForIntroOffer() async -> Bool {
        #if DEBUG
        if devForceFreeTier {
            return true
        }
        if devForceProTier {
            return false
        }
        #endif
        // Ensure products are loaded
        if products.isEmpty {
            await loadProducts()
        }
        // Check eligibility on any product in the subscription group
        guard let product = products.first,
              let subscription = product.subscription else { return false }
        return await subscription.isEligibleForIntroOffer
    }

    // MARK: - Helpers

    /// Convenience: get the monthly product
    var monthlyProduct: Product? {
        products.first { $0.id == Self.proMonthlyID }
    }

    /// Convenience: get the yearly product
    var yearlyProduct: Product? {
        products.first { $0.id == Self.proYearlyID }
    }

    /// Calculate monthly equivalent for yearly plan
    func monthlyEquivalent(for product: Product) -> String? {
        guard product.id == Self.proYearlyID else { return nil }
        let monthlyPrice = product.price / 12
        return monthlyPrice.formatted(.currency(code: product.priceFormatStyle.currencyCode))
    }

    /// Calculate savings percentage for yearly vs monthly
    var yearlySavingsPercent: Int? {
        guard let monthly = monthlyProduct, let yearly = yearlyProduct else { return nil }
        let yearlyMonthly = yearly.price / 12
        let savings = (1 - (yearlyMonthly / monthly.price)) * 100
        return NSDecimalNumber(decimal: savings).intValue
    }

    // MARK: - Private Helpers

    private nonisolated func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in StoreKit.Transaction.updates {
                guard let self else { return }
                do {
                    let transaction = try self.checkVerified(result)
                    await transaction.finish()
                    await self.updateSubscriptionStatus()
                } catch {
                    #if DEBUG
                    print("StoreKitManager: Transaction update verification failed: \(error)")
                    #endif
                }
            }
        }
    }

    // MARK: - Dev Reset

    #if DEBUG
    /// Resets all subscription state for development testing.
    /// Only works with the `.dev` bundle — production bundle is rejected.
    /// After calling this, the app behaves as a new free user until restart.
    func resetForDevelopment() {
        guard Bundle.main.bundleIdentifier?.hasSuffix(".dev") == true else {
            print("StoreKitManager: resetForDevelopment rejected — not dev bundle")
            return
        }

        // Stop transaction listener to prevent re-activation
        transactionListener?.cancel()
        transactionListener = nil

        // Clear all subscription state
        isProUser = false
        isInTrial = false
        activeSubscription = nil
        trialEndDate = nil
        subscriptionExpirationDate = nil
        wasProUser = false
        didJustSubscribe = false
        devForceFreeTier = true
        devForceProTier = false
        UserDefaults.standard.set(true, forKey: Self.devForceFreeTierKey)
        UserDefaults.standard.removeObject(forKey: Self.devForceProTierKey)

        // Sync cleared state to app group
        syncToAppGroup()

        print("StoreKitManager: Dev reset complete — forced free tier (persisted)")
    }

    /// Toggles forced Pro tier for development testing.
    /// Mutually exclusive with devForceFreeTier.
    func toggleDevProTier() {
        guard Bundle.main.bundleIdentifier?.hasSuffix(".dev") == true else { return }

        devForceProTier.toggle()
        if devForceProTier {
            devForceFreeTier = false
            UserDefaults.standard.removeObject(forKey: Self.devForceFreeTierKey)
            isProUser = true
            wasProUser = true
            UserDefaults.standard.set(true, forKey: "chatFABVisible")
        } else {
            devForceFreeTier = true
            UserDefaults.standard.set(true, forKey: Self.devForceFreeTierKey)
            isProUser = false
        }
        UserDefaults.standard.set(devForceProTier, forKey: Self.devForceProTierKey)
        syncToAppGroup()
        print("StoreKitManager: Dev Pro tier \(devForceProTier ? "ON" : "OFF") (persisted)")
    }
    #endif
}

// MARK: - Errors

enum StoreError: LocalizedError {
    case failedVerification

    var errorDescription: String? {
        switch self {
        case .failedVerification:
            return "Transaction verification failed."
        }
    }
}
