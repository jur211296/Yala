//
//  ProUpsellServiceOneShotTests.swift
//  YalaTests
//
//  Semántica one-shot de los upsells: consultar NO quema; solo mark* quema.
//  Invariante que sostiene los fixes "burn en presentación real" — si el sheet
//  nunca aparece, el productor puede re-emitir porque el flag sigue virgen.
//
//  .serialized: los guards de should* leen FeatureGateService.shared /
//  StoreKitManager.shared (read-only). Defaults SIEMPRE aislados por test.
//

import Foundation
import Testing
@testable import Yala

@Suite("ProUpsellService one-shots", .serialized)
@MainActor
struct ProUpsellServiceOneShotTests {

    @Test func trialExpired_notBurned_untilMarked() throws {
        let defaults = makeIsolatedDefaults()
        defaults.set(true, forKey: "pro.trial.wasInTrial")
        let sut = ProUpsellService(defaults: defaults)

        // Precondición del guard (host de tests sin entitlements Pro).
        try #require(!FeatureGateService.shared.isProUser)

        // Consultar N veces no quema el one-shot.
        #expect(sut.shouldShowTrialExpiredSheet())
        #expect(sut.shouldShowTrialExpiredSheet())

        sut.markTrialExpiredSheetShown()
        #expect(!sut.shouldShowTrialExpiredSheet())
    }

    @Test func markTrialExpiredSheetShown_idempotent() {
        let defaults = makeIsolatedDefaults()
        let sut = ProUpsellService(defaults: defaults)
        sut.markTrialExpiredSheetShown()
        sut.markTrialExpiredSheetShown()  // doble onAppear del sheet
        #expect(defaults.bool(forKey: "pro.trial.expiredSheetShown"))
    }

    @Test func milestone_notBurned_untilMarked() throws {
        let defaults = makeIsolatedDefaults()
        let sut = ProUpsellService(defaults: defaults)

        try #require(!FeatureGateService.shared.isProUser)

        #expect(sut.shouldShowMilestone(transactionCount: 10))
        #expect(sut.shouldShowMilestone(transactionCount: 10))  // consulta no quema
        #expect(sut.nextMilestone(for: 10) == 10)

        sut.markMilestoneShown(10)
        #expect(!sut.shouldShowMilestone(transactionCount: 10))
        #expect(sut.nextMilestone == 50)
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
