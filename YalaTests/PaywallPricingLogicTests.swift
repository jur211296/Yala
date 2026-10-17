//
//  PaywallPricingLogicTests.swift
//  YalaTests
//
//  Auditoría UX 2.2 · lote 17. Lo que el paywall y la oferta de prueba dicen de los precios:
//  - B3: «Ahorra N %» no salía nunca (`NSDecimalNumber.intValue` = 0 con mantisa larga).
//  - B4: la prueba gratis se prometía a quien ya la usó.
//  - B2: cancelar el inicio de sesión de Apple al restaurar salía como «Error de compra».
//  - B6: «Prueba terminada» destacaba «Registro por voz» a todo el mundo.
//  Dos mitades: la decisión (tablas) y el cableado (source-scan), porque la tabla puede estar bien mientras la vista
//  sigue leyendo otra cosa.
//

import Foundation
import StoreKit
import Testing

@testable import Yala

@MainActor
@Suite("PaywallPricingLogic · precios, prueba y restaurar")
struct PaywallPricingLogicTests {

    typealias L = PaywallPricingLogic

    // MARK: B3 · ahorro del anual

    @Test("Los precios de Yala (4,99 y 29,99) dan «Ahorra 49 %», no 0")
    func savings_yalaPrices_is49() throws {
        let monthly = try #require(Decimal(string: "4.99"))
        let yearly = try #require(Decimal(string: "29.99"))
        #expect(L.yearlySavingsPercent(monthly: monthly, yearly: yearly) == 49)
    }

    @Test("Control: el cálculo de antes, con esos mismos precios, daba 0")
    func savings_oldComputation_wasZero() throws {
        let monthly = try #require(Decimal(string: "4.99"))
        let yearly = try #require(Decimal(string: "29.99"))
        let savings = (1 - ((yearly / 12) / monthly)) * 100
        #expect(NSDecimalNumber(decimal: savings).intValue == 0)
    }

    @Test("Trunca: 49,9 % se dice 49 %, nunca más de lo que se ahorra")
    func savings_truncates() {
        #expect(L.yearlySavingsPercent(monthly: 10, yearly: 60.12) == 49)
        #expect(L.yearlySavingsPercent(monthly: 10, yearly: 60) == 50)
    }

    @Test("Sin ahorro, o sin precios, no hay etiqueta")
    func savings_noneWhenNoSaving() {
        #expect(L.yearlySavingsPercent(monthly: 5, yearly: 60) == nil)
        #expect(L.yearlySavingsPercent(monthly: 5, yearly: 70) == nil)
        #expect(L.yearlySavingsPercent(monthly: 0, yearly: 30) == nil)
        #expect(L.yearlySavingsPercent(monthly: 5, yearly: 0) == nil)
    }

    // MARK: B4 · prueba prometida

    @Test("Un mes de prueba con derecho a ella: se prometen 30 días")
    func trial_eligibleMonth_is30() {
        #expect(L.promisedTrialDays(hasFreeTrialOffer: true, periodUnit: .month, periodValue: 1, isEligible: true) == 30)
        #expect(L.promisedTrialDays(hasFreeTrialOffer: true, periodUnit: .week, periodValue: 1, isEligible: true) == 7)
        #expect(L.promisedTrialDays(hasFreeTrialOffer: true, periodUnit: .day, periodValue: 3, isEligible: true) == 3)
    }

    @Test("Quien ya usó la prueba no ve «Gratis 30 días»")
    func trial_notEligible_isNil() {
        #expect(L.promisedTrialDays(hasFreeTrialOffer: true, periodUnit: .month, periodValue: 1, isEligible: false) == nil)
    }

    @Test("Sin oferta de prueba en el producto, no se promete nada")
    func trial_noOffer_isNil() {
        #expect(L.promisedTrialDays(hasFreeTrialOffer: false, periodUnit: .month, periodValue: 1, isEligible: true) == nil)
        #expect(L.promisedTrialDays(hasFreeTrialOffer: true, periodUnit: nil, periodValue: 1, isEligible: true) == nil)
    }

    // MARK: B2 · restaurar

    @Test("Cancelar el inicio de sesión de Apple no avisa de nada")
    func restore_cancel_noAlert() {
        #expect(L.restoreFailureAlert(isUserCancellation: true, message: "Solicitud cancelada") == nil)
    }

    @Test("Otro fallo al restaurar avisa con su título, no con «Error de compra»")
    func restore_otherFailure_hasRestoreTitle() throws {
        let alert = try #require(L.restoreFailureAlert(isUserCancellation: false, message: "Sin conexión"))
        #expect(alert.title == L10n.Subscription.restoreErrorTitle)
        #expect(alert.title != L10n.Subscription.errorTitle)
        #expect(alert.message == "Sin conexión")
    }

    @Test("La cancelación se reconoce en StoreKit 2 y en StoreKit 1; otros errores no")
    func cancellation_isRecognized() {
        #expect(L.isUserCancellation(StoreKitError.userCancelled))
        #expect(L.isUserCancellation(SKError(.paymentCancelled)))
        #expect(!L.isUserCancellation(StoreError.failedVerification))
        #expect(!L.isUserCancellation(StoreKitError.networkError(URLError(.notConnectedToInternet))))
    }

    // MARK: B6 · «Prueba terminada»

    @Test("«Prueba terminada» no destaca ninguna función; los demás contextos sí")
    func trialExpired_hidesFeatureRow() {
        #expect(!UpgradeContext.trialExpired.showsFeatureHighlight)
        #expect(UpgradeContext.proFeature.showsFeatureHighlight)
        #expect(UpgradeContext.limitReached.showsFeatureHighlight)
    }

    // MARK: B8 · error de verificación

    @Test("El error de verificación ya no sale en inglés literal")
    func verificationError_isLocalized() {
        #expect(StoreError.failedVerification.errorDescription != "Transaction verification failed.")
    }
}

// MARK: - Cableado (source-scan)

@Suite("PaywallPricingLogic · cableado de producción (source-scan)")
struct PaywallPricingWiringTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    private static func source(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
    }

    /// Sin comentarios: documentar el invariante no puede ponerlo en verde.
    private static func code(_ path: String) throws -> String {
        try source(path).split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> Substring in
                if let r = line.range(of: "//") { return line[..<r.lowerBound] }
                return line
            }
            .joined(separator: "\n")
    }

    static let paywalls = [
        "Yala/App/Views/Settings/SubscriptionView.swift",
        "Yala/App/Views/Subscription/ProTrialOfferSheet.swift",
    ]

    @Test("Las dos pantallas de venta prometen la prueba solo con derecho a ella", arguments: paywalls)
    func paywalls_gateTrialOnEligibility(_ path: String) throws {
        let s = try Self.code(path)
        #expect(s.contains("PaywallPricingLogic.promisedTrialDays("))
        #expect(s.contains("isEligible: store.isIntroOfferEligible"))
        #expect(!s.contains("intro.period"), "el cálculo de días vuelve a vivir en la vista, sin la elegibilidad")
    }

    @Test("El precio mensual va con su unidad, no con `perMonth(\"\")`", arguments: paywalls)
    func paywalls_monthlyUnit(_ path: String) throws {
        let s = try Self.code(path)
        #expect(!s.contains("perMonth(\"\")"))
        #expect(s.contains("L10n.Subscription.perMonthUnit"))
    }

    @Test("La etiqueta de ahorro es sólida, sin degradado", arguments: paywalls)
    func paywalls_saveBadgeSolid(_ path: String) throws {
        let s = try Self.code(path)
        #expect(!s.contains("DS.Gradients.subscription"))
        #expect(s.contains("subscription_save_badge"))
    }

    @Test("StoreKitManager mide la elegibilidad al cargar, calcula el ahorro con la lógica y no avisa al cancelar")
    func storeKitManager_wiring() throws {
        let s = try Self.code("Yala/App/Services/StoreKitManager.swift")
        #expect(s.contains("isIntroOfferEligible = await subscription.isEligibleForIntroOffer"))
        #expect(s.contains("PaywallPricingLogic.yearlySavingsPercent("))
        #expect(s.contains("PaywallPricingLogic.restoreFailureAlert("))
        #expect(s.contains("isUserCancellation: PaywallPricingLogic.isUserCancellation(error)"))
        #expect(s.contains("monthlyPrice.formatted(product.priceFormatStyle)"))
    }

    @Test("El paywall avisa si no cargaron los precios, con reintento")
    func subscriptionView_pricesUnavailable() throws {
        let s = try Self.code("Yala/App/Views/Settings/SubscriptionView.swift")
        #expect(s.contains("productLoadFailed = store.products.isEmpty"))
        #expect(s.contains("subscription_prices_unavailable"))
        #expect(s.contains("subscription_prices_retry"))
    }
}
