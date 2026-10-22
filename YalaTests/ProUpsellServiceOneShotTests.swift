//
//  ProUpsellServiceOneShotTests.swift
//  YalaTests
//
//  Semántica one-shot de los upsells: consultar NO quema; solo mark* quema.
//  Invariante que sostiene los fixes "burn en presentación real" — si el sheet
//  nunca aparece, el productor puede re-emitir porque el flag sigue virgen.
//
//  Estado Pro y defaults SIEMPRE inyectados: ninguna aserción de este fichero depende
//  de un singleton de proceso. Hasta el 2026-08-05 los defaults sí se aislaban pero el
//  Pro se leía de `FeatureGateService.shared`, y esa asimetría ponía la suite en rojo
//  cuando los XCUITest habían corrido antes en el mismo simulador (dejaban
//  `dev.forceProTier` persistido; ver `StoreKitManager.applyUITestProTier`).
//
//  .serialized: `shouldShowPeriodicBanner` todavía alcanza `StoreKitManager.shared`
//  (vía `isVoluntaryChurn`), así que el marcador se queda para quien lo cubra mañana.
//

import Foundation
import Testing
@testable import Yala

@Suite("ProUpsellService one-shots", .serialized)
@MainActor
struct ProUpsellServiceOneShotTests {

    @Test func trialExpired_notBurned_untilMarked() {
        let defaults = makeIsolatedDefaults()
        defaults.set(true, forKey: "pro.trial.wasInTrial")
        let sut = ProUpsellService(defaults: defaults, isProUser: { false })

        // Consultar N veces no quema el one-shot.
        #expect(sut.shouldShowTrialExpiredSheet())
        #expect(sut.shouldShowTrialExpiredSheet())

        sut.markTrialExpiredSheetShown()
        #expect(!sut.shouldShowTrialExpiredSheet())
    }

    /// La otra mitad del guard, que antes era una PRECONDICIÓN asumida y ahora se afirma:
    /// siendo Pro no hay upsell, por muy virgen que esté el one-shot.
    @Test func trialExpired_silenciadoParaPro() {
        let defaults = makeIsolatedDefaults()
        defaults.set(true, forKey: "pro.trial.wasInTrial")
        let sut = ProUpsellService(defaults: defaults, isProUser: { true })

        #expect(!sut.shouldShowTrialExpiredSheet())
    }

    @Test func markTrialExpiredSheetShown_idempotent() {
        let defaults = makeIsolatedDefaults()
        let sut = ProUpsellService(defaults: defaults)
        sut.markTrialExpiredSheetShown()
        sut.markTrialExpiredSheetShown()  // doble onAppear del sheet
        #expect(defaults.bool(forKey: "pro.trial.expiredSheetShown"))
    }

    @Test func milestone_notBurned_untilMarked() {
        let defaults = makeIsolatedDefaults()
        let sut = ProUpsellService(defaults: defaults, isProUser: { false })

        #expect(sut.shouldShowMilestone(transactionCount: 10))
        #expect(sut.shouldShowMilestone(transactionCount: 10))  // consulta no quema
        #expect(sut.nextMilestone(for: 10) == 10)

        sut.markMilestoneShown(10)
        #expect(!sut.shouldShowMilestone(transactionCount: 10))
        #expect(sut.nextMilestone == 50)
    }

    /// Misma simetría que arriba: el hito no se ofrece a un usuario Pro.
    @Test func milestone_silenciadoParaPro() {
        let defaults = makeIsolatedDefaults()
        let sut = ProUpsellService(defaults: defaults, isProUser: { true })

        #expect(!sut.shouldShowMilestone(transactionCount: 10))
        #expect(sut.nextMilestone(for: 10) == 10)  // el cálculo del hito no depende del tier
    }

    @Test func markMilestoneShown_idempotent() {
        let defaults = makeIsolatedDefaults()
        let sut = ProUpsellService(defaults: defaults)
        sut.markMilestoneShown(10)
        sut.markMilestoneShown(10)  // doble onAppear del sheet
        #expect(defaults.integer(forKey: "pro.milestone.lastShown") == 10)
        #expect(sut.nextMilestone == 50)
    }
}
