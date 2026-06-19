//
//  MonetizationDedupLogicTests.swift
//  YalaTests
//

import Testing
@testable import Yala

@Suite("MonetizationDedupLogic")
struct MonetizationDedupLogicTests {

    @Test func trialOffer_blockedByTrialExpiredQueued() {
        let queue: [RouterIntent] = [.presentTrialExpired]
        #expect(!MonetizationDedupLogic.canEnqueue(.presentTrialOffer, given: queue))
    }

    @Test func trialOffer_allowedWhenQueueEmpty() {
        #expect(MonetizationDedupLogic.canEnqueue(.presentTrialOffer, given: []))
    }

    @Test func milestone_blockedByTrialExpired() {
        let queue: [RouterIntent] = [.presentTrialExpired]
        #expect(!MonetizationDedupLogic.canEnqueue(.presentMilestoneUpgrade(50), given: queue))
    }

    @Test func milestone_allowedWithTrialOfferQueued() {
        // Milestone vs offer is OK (offer is softer than expired).
        let queue: [RouterIntent] = [.presentTrialOffer]
        #expect(MonetizationDedupLogic.canEnqueue(.presentMilestoneUpgrade(50), given: queue))
    }

    @Test func nonMonetization_alwaysAllowed() {
        let queue: [RouterIntent] = [.presentTrialExpired]
        #expect(MonetizationDedupLogic.canEnqueue(.navigate(.statistics), given: queue))
    }

    @Test func intentsToSupersede_emptyByDesign() {
        // Supersession lives in IntentSupersessionLogic; this hook is reserved
        // for monetization-specific drops that don't fit the general module.
        #expect(MonetizationDedupLogic.intentsToSupersede(by: .presentTrialExpired, in: [.presentTrialOffer]).isEmpty)
    }
}
