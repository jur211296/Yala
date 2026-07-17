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

// MARK: - H-2026-07-17-5 · detector de adopt aparcado

@Suite("Welcome adopt — auto-resume del drive aparcado (H-2026-07-17-5)")
struct WelcomeAdoptAutoResumeTests {

    private typealias SUT = WelcomeAdoptAutoResume

    /// Aplica N ticks idénticos y devuelve (estado final, fires acumulados).
    private func run(
        ticks: Int,
        isAdopting: Bool = true,
        isWorking: Bool = false,
        machineAdvanced: Bool = false,
        from state: SUT.State = .init()
    ) -> (state: SUT.State, fires: Int) {
        var current = state
        var fires = 0
        for _ in 0..<ticks {
            let (next, fire) = SUT.tick(
                isAdopting: isAdopting, isWorking: isWorking,
                machineAdvanced: machineAdvanced, state: current)
            current = next
            if fire { fires += 1 }
        }
        return (current, fires)
    }

    @Test
    func healthyDrive_neverFires_andHoldsIdleTicksAtZero() {
        // isWorking=true (drive en curso) N ticks → jamás fire; attempts se CONSERVA.
        let seeded = SUT.State(idleTicks: 2, attempts: 1, showManualRetry: false)
        let result = run(ticks: 10, isWorking: true, from: seeded)
        #expect(result.fires == 0)
        #expect(result.state.idleTicks == 0)
        #expect(result.state.attempts == 1)
    }

    @Test
    func nonAdoptingPhase_resetsIdleTicks_neverFires() {
        let seeded = SUT.State(idleTicks: 3, attempts: 0, showManualRetry: false)
        let result = run(ticks: 5, isAdopting: false, from: seeded)
        #expect(result.fires == 0)
        #expect(result.state.idleTicks == 0)
    }

    @Test
    func parked_firesAtThreshold_notBefore() {
        // Ticks 1…3: acumula sin fire. Tick 4 (== idleTicksBeforeResume): fire, attempts=1.
        let before = run(ticks: SUT.idleTicksBeforeResume - 1)
        #expect(before.fires == 0)
        #expect(before.state.idleTicks == SUT.idleTicksBeforeResume - 1)

        let (after, fired) = SUT.tick(
            isAdopting: true, isWorking: false, machineAdvanced: false, state: before.state)
        #expect(fired)
        #expect(after.attempts == 1)
        #expect(after.idleTicks == 0)
        #expect(!after.showManualRetry)
    }

    @Test
    func parkedForever_exhaustsAutos_thenSurfacesManualRetry_andNeverFiresAgain() {
        // 3 autos (maxAutoAttempts) → el 4º umbral muestra el botón SIN fire; después, nunca más.
        let ticksToExhaust = SUT.idleTicksBeforeResume * SUT.maxAutoAttempts
        let exhausted = run(ticks: ticksToExhaust)
        #expect(exhausted.fires == SUT.maxAutoAttempts)
        #expect(exhausted.state.attempts == SUT.maxAutoAttempts)
        #expect(!exhausted.state.showManualRetry)

        let surfaced = run(ticks: SUT.idleTicksBeforeResume, from: exhausted.state)
        #expect(surfaced.fires == 0)
        #expect(surfaced.state.showManualRetry)

        // Aparcada perpetua con el botón visible → jamás vuelve a fire.
        let perpetual = run(ticks: SUT.idleTicksBeforeResume * 5, from: surfaced.state)
        #expect(perpetual.fires == 0)
        #expect(perpetual.state.showManualRetry)
    }

    @Test
    func machineAdvanced_resetsAttempts_andHidesManualRetry() {
        let seeded = SUT.State(idleTicks: 2, attempts: SUT.maxAutoAttempts, showManualRetry: true)
        let (next, fired) = SUT.tick(
            isAdopting: true, isWorking: false, machineAdvanced: true, state: seeded)
        #expect(!fired)
        #expect(next.attempts == 0)
        #expect(!next.showManualRetry)
        // Con intentos frescos, un park posterior vuelve a auto-resumir.
        let reparked = run(ticks: SUT.idleTicksBeforeResume, from: next)
        #expect(reparked.fires == 1)
        #expect(reparked.state.attempts == 1)
    }

    @Test
    func advancedWhileWorking_resetsAttempts_butNoIdleAccumulation() {
        // Avance observado con el drive aún en curso: intentos frescos, racha ociosa en 0.
        let seeded = SUT.State(idleTicks: 3, attempts: 2, showManualRetry: false)
        let (next, fired) = SUT.tick(
            isAdopting: true, isWorking: true, machineAdvanced: true, state: seeded)
        #expect(!fired)
        #expect(next.attempts == 0)
        #expect(next.idleTicks == 0)
    }

    @Test
    func intermittentWorking_preservesAttempts_restartsIdleStreak() {
        // Park (fire 1) → un tick working (resume en vuelo, NO avance) → park de nuevo:
        // attempts se conserva y la racha ociosa arranca de cero.
        let first = run(ticks: SUT.idleTicksBeforeResume)
        #expect(first.fires == 1)
        let working = run(ticks: 1, isWorking: true, from: first.state)
        #expect(working.state.attempts == 1)
        #expect(working.state.idleTicks == 0)
        let second = run(ticks: SUT.idleTicksBeforeResume, from: working.state)
        #expect(second.fires == 1)
        #expect(second.state.attempts == 2)
    }
}
