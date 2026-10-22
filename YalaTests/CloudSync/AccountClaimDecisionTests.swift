//
//  AccountClaimDecisionTests.swift
//  YalaTests
//
//  Pure-logic truth table for `AccountClaimDecision` (Modo Nube §f.1). No SwiftData, no network —
//  covers every (claim state × UI branch × beacon flags) combination, with focus on the variant-B
//  provider-mismatch edge that must fire in EXACTLY one combo.
//

import Foundation
import Testing

@testable import Yala

@Suite("Account Claim Decision")
struct AccountClaimDecisionTests {

    typealias State = AccountClaimDecision.ClaimState
    typealias Branch = AccountClaimDecision.UIBranch
    typealias Action = AccountClaimDecision.AuthAction

    // MARK: - state == .created (the branch/flag-sensitive state)

    /// Full table for `created`: 3 branches × 4 (beacon, match) combos = 12 rows.
    /// Only `returningUser + beacon=true + match=false` diverges to `.showProviderMismatch`.
    @Test(arguments: [
        // bornCloud → always seed (flags irrelevant; the user explicitly chose "I'm new").
        (Branch.bornCloud, false, false, Action.seedBornCloud),
        (Branch.bornCloud, false, true, Action.seedBornCloud),
        (Branch.bornCloud, true, false, Action.seedBornCloud),
        (Branch.bornCloud, true, true, Action.seedBornCloud),
        // migration → always lead the migration (flags irrelevant; never seed onto own populated store).
        (Branch.migration, false, false, Action.proceedMigration),
        (Branch.migration, false, true, Action.proceedMigration),
        (Branch.migration, true, false, Action.proceedMigration),
        (Branch.migration, true, true, Action.proceedMigration),
        // returningUser → seed UNLESS the beacon says cloud-activated AND the provider does not match.
        (Branch.returningUser, false, false, Action.seedBornCloud),
        (Branch.returningUser, false, true, Action.seedBornCloud),
        (Branch.returningUser, true, true, Action.seedBornCloud),
        (Branch.returningUser, true, false, Action.showProviderMismatch), // ← the ONLY mismatch row
    ])
    func created_table(branch: Branch, beacon: Bool, match: Bool, expected: Action) {
        let action = AccountClaimDecision.decide(
            state: .created,
            branch: branch,
            beaconSaysCloudActivated: beacon,
            providerMatchesBeacon: match
        )
        #expect(action == expected)
    }

    // MARK: - state == .existingStable → routeReturningUser (branch & flags irrelevant)

    @Test(arguments: AccountClaimDecisionTests.allBranches, AccountClaimDecisionTests.allBoolPairs)
    func existingStable_alwaysRoutesReturningUser(branch: Branch, flags: (Bool, Bool)) {
        let action = AccountClaimDecision.decide(
            state: .existingStable,
            branch: branch,
            beaconSaysCloudActivated: flags.0,
            providerMatchesBeacon: flags.1
        )
        #expect(action == .routeReturningUser)
    }

    // MARK: - state == .claimingInProgress → waitForLeader (branch & flags irrelevant)

    @Test(arguments: AccountClaimDecisionTests.allBranches, AccountClaimDecisionTests.allBoolPairs)
    func claimingInProgress_alwaysWaitsForLeader(branch: Branch, flags: (Bool, Bool)) {
        let action = AccountClaimDecision.decide(
            state: .claimingInProgress,
            branch: branch,
            beaconSaysCloudActivated: flags.0,
            providerMatchesBeacon: flags.1
        )
        #expect(action == .waitForLeader)
    }

    // MARK: - Targeted edges for variant B

    @Test func providerMismatch_firesOnlyForReturningUser_notBornCloud() {
        // Same beacon+mismatch flags, bornCloud branch → still seeds (mismatch is returningUser-only).
        let born = AccountClaimDecision.decide(
            state: .created, branch: .bornCloud,
            beaconSaysCloudActivated: true, providerMatchesBeacon: false
        )
        #expect(born == .seedBornCloud)
    }

    @Test func providerMismatch_firesOnlyForReturningUser_notMigration() {
        let migration = AccountClaimDecision.decide(
            state: .created, branch: .migration,
            beaconSaysCloudActivated: true, providerMatchesBeacon: false
        )
        #expect(migration == .proceedMigration)
    }

    @Test func providerMismatch_needsBothBeaconAndMismatch() {
        // beacon=false → no mismatch even if provider doesn't match (nothing says this ID used cloud).
        #expect(
            AccountClaimDecision.decide(
                state: .created, branch: .returningUser,
                beaconSaysCloudActivated: false, providerMatchesBeacon: false
            ) == .seedBornCloud
        )
        // provider matches → no mismatch even with the beacon on.
        #expect(
            AccountClaimDecision.decide(
                state: .created, branch: .returningUser,
                beaconSaysCloudActivated: true, providerMatchesBeacon: true
            ) == .seedBornCloud
        )
    }

    // MARK: - Shared argument products

    static let allBranches: [Branch] = [.bornCloud, .migration, .returningUser]
    static let allBoolPairs: [(Bool, Bool)] = [(false, false), (false, true), (true, false), (true, true)]
}
