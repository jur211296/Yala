//
//  CloudWelcomeSignInFlowTests.swift
//  YalaTests
//

import Foundation
import Testing

@testable import Yala

@Suite("Welcome sign-in nube — ruteo de /account/exists")
struct CloudWelcomeSignInFlowExistsRouteTests {

    @Test
    func existsTrue_accountFound() {
        #expect(CloudWelcomeSignInFlow.route(.exists(true)) == .accountFound)
    }

    @Test
    func existsFalse_accountMissing() {
        #expect(CloudWelcomeSignInFlow.route(.exists(false)) == .accountMissing)
    }

    @Test
    func sessionExpired_failsRetryable() {
        #expect(CloudWelcomeSignInFlow.route(
            .sessionExpired(detail: "401")
        ) == .failed(retryable: true))
    }

    @Test
    func transient_failsRetryable() {
        #expect(CloudWelcomeSignInFlow.route(
            .transient(detail: "network")
        ) == .failed(retryable: true))
    }
}

@Suite("Welcome sign-in nube — fase de pantalla por uiState")
struct CloudWelcomeSignInFlowPhaseTests {

    @Test
    func idle_isAdoptingAtZero() {
        // Fases consent/authenticating no-durables → el deriver reporta .idle.
        #expect(CloudWelcomeSignInFlow.phase(for: .idle) == .adopting(fraction: 0))
    }

    @Test
    func migrating_mapsFraction() {
        let step = MigrationUIStep(fraction: 0.45, phase: .claimingMigration)
        #expect(CloudWelcomeSignInFlow.phase(for: .migrating(step)) == .adopting(fraction: 0.45))
    }

    @Test
    func needsRelaunchToCloud_isRelaunch() {
        #expect(CloudWelcomeSignInFlow.phase(for: .needsRelaunch(.toCloud)) == .relaunch)
    }

    @Test
    func cloudActive_isRelaunch_defensive() {
        #expect(CloudWelcomeSignInFlow.phase(for: .cloudActive) == .relaunch)
    }

    @Test
    func waitingForLeader_isWaitingLeader() {
        #expect(CloudWelcomeSignInFlow.phase(for: .waitingForLeader) == .waitingLeader)
    }

    @Test
    func failed_isRetryableError() {
        #expect(CloudWelcomeSignInFlow.phase(for: .failed(.migration)) == .error(retryable: true))
    }

    @Test
    func reverseStates_degradeToNonRetryableError() {
        let step = MigrationUIStep(fraction: 0.5, phase: .reverseDrainAll)
        #expect(CloudWelcomeSignInFlow.phase(for: .reverting(step)) == .error(retryable: false))
        #expect(CloudWelcomeSignInFlow.phase(for: .needsRelaunch(.toICloud)) == .error(retryable: false))
    }
}
