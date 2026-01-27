//
//  StoreKitManager.swift
//  Yala
//
//  Manages in-app subscriptions using StoreKit 2.
//

import StoreKit
import SwiftUI

/// Manages StoreKit 2 subscription products, purchases, and entitlements.
@Observable
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

    // MARK: - Private

    private var transactionListener: Task<Void, Never>?

    // MARK: - Init

    private init() {
        transactionListener = listenForTransactions()
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Load Products

    /// Fetches available subscription products from App Store Connect
    func loadProducts() async {
        do {
            let productIDs: Set<String> = [
                Self.proMonthlyID,
                Self.proYearlyID,
            ]
            let storeProducts = try await Product.products(for: productIDs)
            // Sort: yearly first (better value), then monthly
            products = storeProducts.sorted { p1, _ in
                p1.id == Self.proYearlyID
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Purchase

    /// Purchase a subscription product
    @MainActor
    func purchase(_ product: Product) async -> Bool {
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await updateSubscriptionStatus()
                return true

            case .userCancelled:
                return false

            case .pending:
                return false

            @unknown default:
                return false
            }
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Restore

    /// Restore previous purchases
    @MainActor
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
    @MainActor
    func updateSubscriptionStatus() async {
        var foundActive: StoreKit.Transaction?

        for await result in StoreKit.Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result) {
                if transaction.productType == .autoRenewable {
                    foundActive = transaction
                }
            }
        }

        activeSubscription = foundActive
        isProUser = foundActive != nil
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
                if let transaction = try? self.checkVerified(result) {
                    await transaction.finish()
                    await self.updateSubscriptionStatus()
                }
            }
        }
    }
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
