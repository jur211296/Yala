//
//  ProSubscriptionActivationLogicTests.swift
//  YalaTests
//
//  Pinnea el borde compra/restore → Pro (bug TF 2.1 b11: éxito en sandbox y la
//  app seguía Free). Tres cosas que estos tests impiden, en orden de daño:
//   1. Celebrar un `.success` que no dejó `isProUser` en true.
//   2. Tirar la Transaction verificada y fiarse solo de `currentEntitlements`
//      vacío — in-session y al reabrir.
//   3. Restaurar en silencio cuando no hay derecho.
//
//  Dos mitades: la DECISIÓN (tablas) y el CABLEADO (source-scan). Ninguna cubre
//  a la otra: la tabla puede estar perfecta mientras `purchase` sigue poniendo
//  `didJustSubscribe = true` a ciegas.
//

import Foundation
import Testing

@testable import Yala

@Suite("ProSubscriptionActivationLogic · compra y restore no celebran Free")
struct ProSubscriptionActivationLogicTests {

    typealias L = ProSubscriptionActivationLogic
    typealias Facts = L.TransactionFacts
    typealias Cached = L.LastVerifiedLocal

    static let now = Date(timeIntervalSince1970: 1_800_000_000)
    static let later = now.addingTimeInterval(30 * 24 * 3600)
    static let earlier = now.addingTimeInterval(-60)

    static func yearly(
        revoked: Date? = nil,
        expires: Date? = later,
        autoRenewable: Bool = true
    ) -> Facts {
        Facts(
            productID: "com.yala.pro.yearly",
            productTypeIsAutoRenewable: autoRenewable,
            revocationDate: revoked,
            expirationDate: expires
        )
    }

    static func monthly(
        revoked: Date? = nil,
        expires: Date? = later
    ) -> Facts {
        Facts(
            productID: "com.yala.pro.monthly",
            productTypeIsAutoRenewable: true,
            revocationDate: revoked,
            expirationDate: expires
        )
    }

    // MARK: - Compra .success → Pro aunque currentEntitlements esté vacío

    /// EL caso del ticket: Apple devolvió `.success`, la Transaction es Pro vigente,
    /// y `currentEntitlements` todavía no la lista. Antes esto dejaba Free y celebraba.
    @Test func compraVerificada_sinEntitlements_esProLocal() {
        let purchase = Self.yearly()
        let last = L.updatedLastVerified(entitlements: [purchase], previous: nil, now: Self.now)
        #expect(L.localActive(entitlements: [], lastVerified: last, now: Self.now))
        #expect(L.shouldCelebratePurchase(isProUser: true))
    }

    @Test func compraVerificada_conEntitlementsVaciosEnLaMismaPasada_esPro() {
        #expect(L.isActiveLocalEntitlement(Self.yearly(), now: Self.now))
        #expect(L.localActive(entitlements: [Self.yearly()], lastVerified: nil, now: Self.now))
    }

    /// Producto ajeno, revocada, caducada o no auto-renovable: no es Pro, no se celebra.
    @Test func compraQueNoEsDerechoVigente_noEsPro() {
        let ajenos: [Facts] = [
            Facts(productID: "com.otro.pro", productTypeIsAutoRenewable: true,
                  revocationDate: nil, expirationDate: Self.later),
            Self.yearly(revoked: Self.now),
            Self.yearly(expires: Self.now),
            Self.yearly(expires: Self.earlier),
            Self.yearly(autoRenewable: false),
        ]
        for facts in ajenos {
            #expect(L.isActiveLocalEntitlement(facts, now: Self.now) == false,
                    "no debía ser Pro: \(facts.productID) revoked=\(facts.revocationDate != nil)")
            #expect(L.localActive(entitlements: [facts], lastVerified: nil, now: Self.now) == false)
        }
        #expect(L.shouldCelebratePurchase(isProUser: false) == false)
    }

    /// Justo en el instante de expiración ya NO hay derecho (`>`, no `>=`).
    @Test func expiracionEnElInstante_noEsPro() {
        #expect(L.isActiveLocalEntitlement(Self.monthly(expires: Self.now), now: Self.now) == false)
    }

    @Test func sinExpirationDate_sigueVigenteSiLoDemasCasa() {
        #expect(L.isActiveLocalEntitlement(Self.yearly(expires: nil), now: Self.now))
    }

    // MARK: - Celebración gated

    @Test func noCelebrarSiSigueFree() {
        #expect(L.shouldCelebratePurchase(isProUser: false) == false)
    }

    @Test func celebrarSoloSiYaEsPro() {
        #expect(L.shouldCelebratePurchase(isProUser: true))
    }

    // MARK: - Restore empty vs found

    @Test func restoreSinDerecho_pideFeedback() {
        #expect(L.restoreOutcome(isProUser: false) == .noEntitlement)
    }

    @Test func restoreConDerecho_esPro() {
        #expect(L.restoreOutcome(isProUser: true) == .restoredPro)
        #expect(L.localActive(entitlements: [Self.monthly()], lastVerified: nil, now: Self.now))
    }

    // MARK: - lastVerified: reopen + lag de currentEntitlements

    /// Reopen con `currentEntitlements` vacío: si la compra verificada sigue vigente, Pro.
    @Test func entitlementsVacios_conservanLastVerifiedVigente() {
        let previous = Cached(productID: "com.yala.pro.yearly", expirationDate: Self.later)
        let next = L.updatedLastVerified(entitlements: [], previous: previous, now: Self.now)
        #expect(next == previous)
        #expect(L.localActive(entitlements: [], lastVerified: next, now: Self.now))
    }

    @Test func lastVerifiedCaducado_noDaPro_ySeBorra() {
        let previous = Cached(productID: "com.yala.pro.yearly", expirationDate: Self.earlier)
        let next = L.updatedLastVerified(entitlements: [], previous: previous, now: Self.now)
        #expect(next == nil)
        #expect(L.localActive(entitlements: [], lastVerified: previous, now: Self.now) == false)
    }

    @Test func entitlementCaducado_borraLastVerified() {
        let previous = Cached(productID: "com.yala.pro.yearly", expirationDate: Self.later)
        let next = L.updatedLastVerified(
            entitlements: [Self.yearly(expires: Self.earlier)],
            previous: previous,
            now: Self.now
        )
        #expect(next == nil)
        #expect(L.localActive(entitlements: [Self.yearly(expires: Self.earlier)],
                              lastVerified: previous, now: Self.now) == false)
    }

    /// Una revocación conocida gana: no conservamos un Pro que Apple quitó.
    @Test func entitlementRevocado_borraLastVerified() {
        let previous = Cached(productID: "com.yala.pro.yearly", expirationDate: Self.later)
        let next = L.updatedLastVerified(
            entitlements: [Self.yearly(revoked: Self.now)],
            previous: previous,
            now: Self.now
        )
        #expect(next == nil)
        #expect(L.localActive(entitlements: [Self.yearly(revoked: Self.now)],
                              lastVerified: previous, now: Self.now) == false)
    }

    @Test func entitlementActivo_reemplazaLastVerified() {
        let previous = Cached(productID: "com.yala.pro.monthly", expirationDate: Self.later)
        let next = L.updatedLastVerified(entitlements: [Self.yearly()], previous: previous, now: Self.now)
        #expect(next == Cached(productID: "com.yala.pro.yearly", expirationDate: Self.later))
    }
}

// MARK: - Cableado (source-scan)

@Suite("ProSubscriptionActivationLogic · cableado de producción (source-scan)")
struct ProSubscriptionActivationWiringTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private static func source(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
    }

    private static func body(of marker: String, in source: String) throws -> String {
        let start = try #require(source.range(of: marker), "marcador no encontrado: \(marker)")
        let chars = Array(source[start.upperBound...])
        var depth = 1
        var i = 0
        while i < chars.count {
            if chars[i] == "{" { depth += 1 }
            if chars[i] == "}" { depth -= 1; if depth == 0 { break } }
            i += 1
        }
        return String(chars[0..<min(i, chars.count)])
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// Sin esto, la tabla queda verde y `purchase` vuelve a celebrar a ciegas.
    @Test func purchaseAplicaLaTransaccionVerificadaYNoCelebraACiegas() throws {
        let src = try Self.source("Yala/App/Services/StoreKitManager.swift")
        let purchase = try Self.body(of: "func purchase(_ product: Product) async -> Bool {", in: src)
        #expect(purchase.contains("updateSubscriptionStatus(verifiedPurchase: transaction)"), """
            La compra tiene que aplicar la Transaction verificada. Si solo llama \
            `updateSubscriptionStatus()` a secas, currentEntitlements vacío vuelve a dejar Free.
            """)
        #expect(purchase.contains("shouldCelebratePurchase(isProUser: isProUser)"), """
            didJustSubscribe no puede ser `true` incondicional: solo si el usuario ya es Pro.
            """)
        #expect(!purchase.contains("didJustSubscribe = true"), """
            Un `didJustSubscribe = true` suelto reintroduce el sheet de éxito con la app en Free.
            """)
    }

    @Test func restoreHablaSiNoHayDerecho() throws {
        let src = try Self.source("Yala/App/Services/StoreKitManager.swift")
        let restore = try Self.body(of: "func restorePurchases() async {", in: src)
        #expect(restore.contains("restoreOutcome(isProUser: isProUser)"), """
            El restore tiene que pasar por el seam: si no, un Free se queda sin feedback.
            """)
        #expect(restore.contains("L10n.Subscription.restoreEmpty"), """
            Sin copy de «no hay suscripción» el restore vuelve a tragarse el resultado vacío.
            """)
    }

    @Test func successSheetEstaGateadaPorIsProUser() throws {
        let subscription = try Self.source("Yala/App/Views/Settings/SubscriptionView.swift")
        let trial = try Self.source("Yala/App/Views/Subscription/ProTrialOfferSheet.swift")
        for (name, src) in [("SubscriptionView", subscription), ("ProTrialOfferSheet", trial)] {
            #expect(
                src.contains("didSubscribe && store.isProUser")
                    || src.contains("store.isProUser && didSubscribe"),
                """
                \(name) tiene que exigir isProUser además de didJustSubscribe. Si no, un flag \
                suelto vuelve a montar SubscriptionSuccessView con la app en Free.
                """
            )
        }
    }
}
