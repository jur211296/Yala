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

    /// Error / status message to display
    var errorMessage: String?

    /// Title for the user-facing alert. `nil` → `L10n.Subscription.errorTitle`.
    var alertTitle: String?

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
    private let lastVerifiedProductIDKey = "yala.lastVerifiedProProductID"
    private let lastVerifiedExpirationKey = "yala.lastVerifiedProExpiresAt"

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

    /// App Group identifier for sharing state with intents (QuickExpenseIntent Pro gate).
    /// Debe ser el canónico entitled — un suite no-entitled crea un plist LOCAL al sandbox
    /// que ningún lector ve (bug SiriNatural pro_required, roto desde b1e724a0).
    private let appGroupID = SharedContainerService.appGroupIdentifier

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

    /// Estado Pro de `-uitest-pro`: EFÍMERO a propósito — vive solo en este proceso y NO se
    /// persiste. `nil` = la app no corre bajo uitest y manda el camino normal (dev flags /
    /// entitlements). Ver `applyUITestProTier(_:)` para el porqué de que no sea `devForceProTier`.
    private(set) var uiTestForcedProTier: Bool?
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
            let result = try await product.purchase(
                options: Self.purchaseOptions(cloudUserID: CloudAuthService.shared.currentUserID))

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                #if DEBUG
                devForceFreeTier = false
                devForceProTier = false
                UserDefaults.standard.removeObject(forKey: Self.devForceFreeTierKey)
                UserDefaults.standard.removeObject(forKey: Self.devForceProTierKey)
                #endif
                // Aplicar la Transaction verificada ANTES de finish y ANTES de fiarse de
                // currentEntitlements: en sandbox ese iterator puede llegar vacío y el usuario
                // se quedaba Free con el sheet de éxito ya puesto (TF 2.1 b11).
                await updateSubscriptionStatus(verifiedPurchase: transaction)
                await transaction.finish()
                didJustSubscribe = ProSubscriptionActivationLogic.shouldCelebratePurchase(isProUser: isProUser)
                if !didJustSubscribe {
                    alertTitle = L10n.Subscription.errorTitle
                    errorMessage = L10n.Subscription.purchaseNotActivated
                }
                // C-8: la compra acaba de nacer con su `appAccountToken`; vincularla a la cuenta
                // cuanto antes (y no en el próximo foreground) pone el derecho en la cuenta desde el
                // primer segundo. En BACKGROUND a propósito: esperarlo aquí retendría `isPurchasing`
                // y retrasaría la celebración detrás de la red del gateway — con red mala, la compra
                // parecería colgada justo después de que Apple la confirmó.
                Task { @MainActor in await AccountEntitlementService.shared.sync(force: true) }
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

    // MARK: - Purchase options (C-8)

    /// Opciones de compra. Emite `appAccountToken` = el `sub` de la cuenta de Yala cuando hay sesión
    /// de nube viva, para que el derecho pueda VIAJAR con la cuenta y no solo con el Apple ID: Apple
    /// firma ese UUID dentro de la transacción, así que el gateway puede atribuir la suscripción a su
    /// dueño sin confiar en el cliente (`gateway/src/sync/entitlement.ts`).
    ///
    /// Sin sesión de nube NO se emite ningún token: inventar un UUID local crearía una identidad de
    /// compra que no corresponde a ninguna cuenta y que después habría que reconciliar. Esas compras
    /// se vinculan más tarde por JWT, en el primer `sync()` con sesión.
    ///
    /// Estático para poder testear la decisión sin tocar el estado del manager. `cloudUserID` se pasa
    /// explícito (un default que leyera el singleton `@MainActor` se evaluaría en contexto
    /// `nonisolated` — error en Swift 6).
    static func purchaseOptions(cloudUserID: String?) -> Set<Product.PurchaseOption> {
        guard let cloudUserID, let uuid = UUID(uuidString: cloudUserID) else { return [] }
        return [.appAccountToken(uuid)]
    }

    // MARK: - Restore

    /// Restore previous purchases
    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await updateSubscriptionStatus()
            switch ProSubscriptionActivationLogic.restoreOutcome(isProUser: isProUser) {
            case .restoredPro:
                didJustSubscribe = ProSubscriptionActivationLogic.shouldCelebratePurchase(isProUser: isProUser)
            case .noEntitlement:
                alertTitle = L10n.Subscription.restoreEmptyTitle
                errorMessage = L10n.Subscription.restoreEmpty
            }
        } catch {
            alertTitle = L10n.Subscription.errorTitle
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Subscription Status

    /// Check current entitlements and update subscription state.
    /// `verifiedPurchase` is the Transaction StoreKit just confirmed (compra o
    /// `Transaction.updates`). Cuenta como derecho local aunque `currentEntitlements`
    /// todavía no la liste.
    func updateSubscriptionStatus(verifiedPurchase: StoreKit.Transaction? = nil) async {
        #if DEBUG
        // El override de uitest gana ANTES que los dev flags: es lo que hace que
        // `-uitest-pro` no necesite persistir nada. Sin esta rama, el `refreshSubscriptionStatus`
        // del paso 3 del bootstrap caería al early-return `.dev` de abajo y pondría
        // `isProUser = false`, deshaciendo el arg a mitad del arranque.
        if let uiTestForcedProTier {
            isProUser = uiTestForcedProTier
            syncToAppGroup()
            return
        }
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
        // entitlements that would otherwise always grant Pro.
        // C-8: si la QA de device encendió la resolución por cuenta, el derecho de la CUENTA sí
        // cuenta aquí — sin esta rama, `debugAccountEntitlementEnabledKey` sería inalcanzable
        // (Yala Dev es la ÚNICA build donde esa key se lee, y este early-return la cortocircuitaba).
        if Bundle.main.bundleIdentifier?.hasSuffix(".dev") == true {
            if CloudSyncFlags.accountEntitlementEnabled {
                isProUser = ProEntitlementLogic.isPro(
                    localActive: false,
                    snapshot: AccountEntitlementService.shared.cachedSnapshot,
                    sessionUserID: CloudAuthService.shared.currentUserID,
                    resolutionEnabled: true)
                syncToAppGroup()
                return
            }
            isProUser = false
            syncToAppGroup()
            return
        }
        #endif

        var entitlementFacts: [ProSubscriptionActivationLogic.TransactionFacts] = []
        var foundActive: StoreKit.Transaction?

        if let verifiedPurchase {
            let purchaseFacts = facts(from: verifiedPurchase)
            entitlementFacts.append(purchaseFacts)
            if ProSubscriptionActivationLogic.isActiveLocalEntitlement(purchaseFacts) {
                foundActive = verifiedPurchase
            }
        }

        for await result in StoreKit.Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                let txnFacts = facts(from: transaction)
                entitlementFacts.append(txnFacts)
                if ProSubscriptionActivationLogic.isActiveLocalEntitlement(txnFacts) {
                    foundActive = transaction
                }
            } catch {
                #if DEBUG
                print("StoreKitManager: Transaction verification failed: \(error)")
                #endif
            }
        }

        let nextVerified = ProSubscriptionActivationLogic.updatedLastVerified(
            entitlements: entitlementFacts,
            previous: loadLastVerified()
        )
        persistLastVerified(nextVerified)

        let localActive = ProSubscriptionActivationLogic.localActive(
            entitlements: entitlementFacts,
            lastVerified: nextVerified
        )

        activeSubscription = foundActive
        // C-8: el derecho puede venir del Apple ID de este device (`localActive`) O de la cuenta de
        // Yala. La combinación vive en `ProEntitlementLogic` — DARK mientras
        // `accountEntitlementEnabled` sea false, donde esto es idénticamente `localActive`.
        let nowProUser = ProEntitlementLogic.isPro(
            localActive: localActive,
            snapshot: AccountEntitlementService.shared.cachedSnapshot,
            sessionUserID: CloudAuthService.shared.currentUserID,
            resolutionEnabled: CloudSyncFlags.accountEntitlementEnabled)

        // Trial y fecha de expiración siguen siendo del entitlement LOCAL: son datos de la
        // suscripción de este Apple ID. Un Pro heredado de la cuenta no está "en trial" aquí.
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
        if SessionState.shared.isProUser != isProUser {
            SessionState.shared.isProUser = isProUser
        }

        if nowProUser && !wasAlreadyPro {
            SessionDefaults.current.set(true, forKey: "chatFABVisible")
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
        defaults.set(isProUser, forKey: AppPreferences.Keys.isProUser)
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

    private func facts(from transaction: StoreKit.Transaction) -> ProSubscriptionActivationLogic.TransactionFacts {
        ProSubscriptionActivationLogic.TransactionFacts(
            productID: transaction.productID,
            productTypeIsAutoRenewable: transaction.productType == .autoRenewable,
            revocationDate: transaction.revocationDate,
            expirationDate: transaction.expirationDate
        )
    }

    private func loadLastVerified() -> ProSubscriptionActivationLogic.LastVerifiedLocal? {
        guard let productID = UserDefaults.standard.string(forKey: lastVerifiedProductIDKey) else {
            return nil
        }
        let expiration: Date?
        if let raw = UserDefaults.standard.object(forKey: lastVerifiedExpirationKey) as? TimeInterval {
            expiration = Date(timeIntervalSince1970: raw)
        } else {
            expiration = nil
        }
        return ProSubscriptionActivationLogic.LastVerifiedLocal(
            productID: productID,
            expirationDate: expiration
        )
    }

    private func persistLastVerified(_ last: ProSubscriptionActivationLogic.LastVerifiedLocal?) {
        if let last {
            UserDefaults.standard.set(last.productID, forKey: lastVerifiedProductIDKey)
            if let expiration = last.expirationDate {
                UserDefaults.standard.set(expiration.timeIntervalSince1970, forKey: lastVerifiedExpirationKey)
            } else {
                UserDefaults.standard.removeObject(forKey: lastVerifiedExpirationKey)
            }
        } else {
            UserDefaults.standard.removeObject(forKey: lastVerifiedProductIDKey)
            UserDefaults.standard.removeObject(forKey: lastVerifiedExpirationKey)
        }
    }

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
                    await self.updateSubscriptionStatus(verifiedPurchase: transaction)
                    await transaction.finish()
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
        persistLastVerified(nil)
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
            SessionDefaults.current.set(true, forKey: "chatFABVisible")
        } else {
            devForceFreeTier = true
            UserDefaults.standard.set(true, forKey: Self.devForceFreeTierKey)
            isProUser = false
        }
        UserDefaults.standard.set(devForceProTier, forKey: Self.devForceProTierKey)
        syncToAppGroup()
        print("StoreKitManager: Dev Pro tier \(devForceProTier ? "ON" : "OFF") (persisted)")
    }

    /// Aplica el estado Pro de `-uitest-pro` **sin persistir absolutamente nada**, y borra el
    /// rastro que el camino anterior dejaba. Lo llama SOLO `AppBootstrapper.applyUITestHooksEarly`.
    ///
    /// Antes esto era `toggleDevProTier()`, y ese atajo —reusar el toggle de "Simular Pro" del
    /// Perfil— es lo que convertía un seam de QA en estado GLOBAL: el toggle persiste
    /// `dev.forceProTier` en `UserDefaults.standard`, el `init` de arriba lo relee, y el host de
    /// unit tests comparte bundle (`…yala.dev`) con el de los XCUITest ⇒ **correr los XCUITest y
    /// después los unitarios dejaba `FeatureGateService.shared.isProUser == true` y ponía en rojo
    /// a `ProUpsellServiceOneShotTests`, sin que nadie hubiera tocado nada de Pro.** El wipe de
    /// SwiftData no limpia `UserDefaults`, y el bloque de `-uitest-reset` limpia al ARRANQUE de la
    /// siguiente corrida uitest — lo cual no protege a un target que corre DESPUÉS.
    ///
    /// De ahí las dos mitades:
    /// 1. **efímero** — `uiTestForcedProTier` vive en el proceso y muere con él;
    /// 2. **purga** — se borran las cuatro keys que el toggle escribía. No es limpieza de cinturón:
    ///    cura los simuladores YA contaminados (nada más las borraría) y garantiza que tras
    ///    cualquier launch uitest el disco quede como si `-uitest-pro` no existiera. `wasProUser`
    ///    importa más de lo que parece: sucia hace `justDowngraded == true` en el siguiente launch
    ///    SIN el arg, y `checkForDowngrade` llega a `resetPremiumIconIfNeeded` (que cambia el icono
    ///    del sistema) y a `resetProThemeIfNeeded`. `chatFABVisible` se borra en vez de escribirse a
    ///    `true` porque `true` YA es su default en `AppPreferences` — mismo efecto, cero rastro.
    ///
    /// Sin guard de bundle `.dev`, al revés que el toggle: este método no es la preferencia de dev,
    /// es el seam de test, y solo se alcanza bajo `-uitest` dentro de `#if DEBUG`.
    func applyUITestProTier(_ forced: Bool) {
        uiTestForcedProTier = forced
        isProUser = forced

        devForceProTier = false
        devForceFreeTier = false
        UserDefaults.standard.removeObject(forKey: Self.devForceProTierKey)
        UserDefaults.standard.removeObject(forKey: Self.devForceFreeTierKey)
        UserDefaults.standard.removeObject(forKey: wasProUserKey)
        SessionDefaults.current.removeObject(forKey: "chatFABVisible")

        // El gate Pro de QuickExpenseIntent lee el App Group, no `isProUser` — sin esto los
        // intents verían el estado del launch anterior (paridad con el toggle que sustituye).
        syncToAppGroup()
        print("StoreKitManager: uitest Pro tier \(forced ? "ON" : "OFF") (efímero, sin persistir)")
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
