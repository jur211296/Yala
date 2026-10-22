//
//  IntentSupersessionLogicTests.swift
//  YalaTests
//

import Testing
@testable import Yala

@Suite("IntentSupersessionLogic")
struct IntentSupersessionLogicTests {

    @Test func navigateInbox_dropsPendingInboxAlert() {
        let alert: RouterIntent = .showInboxAlert(.init(scheduledPayments: 0, subscriptions: 0, automations: 1))
        let (drops, accept) = IntentSupersessionLogic.decisions(
            queued: [alert], incoming: .navigate(.inbox))
        #expect(drops.contains(alert.id))
        #expect(accept == true)
    }

    @Test func presentInboxSheet_dropsPendingInboxAlert() {
        let alert: RouterIntent = .showInboxAlert(.init(scheduledPayments: 1, subscriptions: 0, automations: 0))
        let (drops, accept) = IntentSupersessionLogic.decisions(
            queued: [alert], incoming: .presentInboxSheet)
        #expect(drops.contains(alert.id))
        #expect(accept == true)
    }

    @Test func presentTrialExpired_dropsPendingTrialOffer() {
        let offer: RouterIntent = .presentTrialOffer
        let (drops, accept) = IntentSupersessionLogic.decisions(
            queued: [offer], incoming: .presentTrialExpired)
        #expect(drops.contains(offer.id))
        #expect(accept == true)
    }

    @Test func remoteWipe_dropsNonCritical() {
        // Queue with mixed priority intents.
        let normal: RouterIntent = .presentInboxSheet // priority .normal
        let high: RouterIntent = .showInboxAlert(.init(scheduledPayments: 1, subscriptions: 0, automations: 0)) // .high
        let critical: RouterIntent = .iCloudMismatch // .critical
        let queue = [normal, high, critical]

        let (drops, accept) = IntentSupersessionLogic.decisions(
            queued: queue, incoming: .remoteWipe(skipOnboarding: false))
        #expect(drops.contains(normal.id))
        #expect(drops.contains(high.id))
        #expect(!drops.contains(critical.id), "remoteWipe should not drop critical intents")
        #expect(accept == true)
    }

    @Test func unrelatedIntent_noDrops() {
        let queue: [RouterIntent] = [.presentTrialOffer, .presentInboxSheet]
        let (drops, accept) = IntentSupersessionLogic.decisions(
            queued: queue, incoming: .navigate(.statistics))
        #expect(drops.isEmpty)
        #expect(accept == true)
    }

    @Test func emptyQueue_noDrops() {
        let (drops, accept) = IntentSupersessionLogic.decisions(
            queued: [], incoming: .navigate(.inbox))
        #expect(drops.isEmpty)
        #expect(accept == true)
    }

    @Test func multipleQueuedAlerts_allDropped() {
        // Real dedup-by-id would collapse these, but cascade logic is independent.
        let a1: RouterIntent = .showInboxAlert(.init(scheduledPayments: 1, subscriptions: 0, automations: 0))
        let a2: RouterIntent = .showInboxAlert(.init(scheduledPayments: 0, subscriptions: 2, automations: 0))
        let (drops, _) = IntentSupersessionLogic.decisions(
            queued: [a1, a2], incoming: .navigate(.inbox))
        #expect(drops.count == 2 || drops.count == 1) // depending on dedup by id, both acceptable
    }

    @Test func navigateToOtherTab_doesNotDropAlerts() {
        let alert: RouterIntent = .showInboxAlert(.init(scheduledPayments: 1, subscriptions: 0, automations: 0))
        let (drops, _) = IntentSupersessionLogic.decisions(
            queued: [alert], incoming: .navigate(.statistics))
        #expect(drops.isEmpty)
    }

    @Test func customRules_canBeProvided() {
        // Verify the rules argument is honored — pass empty rules → no drops.
        let alert: RouterIntent = .showInboxAlert(.init(scheduledPayments: 0, subscriptions: 0, automations: 1))
        let (drops, accept) = IntentSupersessionLogic.decisions(
            queued: [alert], incoming: .navigate(.inbox), rules: [])
        #expect(drops.isEmpty)
        #expect(accept == true)
    }

    // MARK: - Cambio de Apple ID vs. aviso del espejo tardío (2026-09-14)

    @Test func appleIDChanged_supersedes_iCloudMismatch() {
        // Los dos salen del MISMO disparador (`NSUbiquityIdentityDidChange`) y el viejo se encola
        // primero, porque es síncrono. Sin la regla se drenan los dos: dos `.alert` encadenados del
        // anchor de `ContentView`. Y el consejo del viejo —«reabre para sincronizar»— es falso con la
        // cuenta cambiada: sincronizaría el corpus del Apple ID anterior contra el nuevo.
        let (drops, accept) = IntentSupersessionLogic.decisions(
            queued: [.iCloudMismatch], incoming: .appleIDChangedClosePrivate)
        #expect(drops == ["iCloudMismatch"])
        #expect(accept == true)
    }

    @Test func appleIDChanged_noTiraOtrosCriticos() {
        // El control en la dirección contraria: la regla nombra UN intent, no «todo lo que haya».
        // Un `.remoteWipe` en cola es otro borrado con su propia confirmación y no se le pisa.
        let (drops, _) = IntentSupersessionLogic.decisions(
            queued: [.remoteWipe(skipOnboarding: false), .showInviteError("x")],
            incoming: .appleIDChangedClosePrivate)
        #expect(drops.isEmpty)
    }

    @Test func iCloudMismatch_noTiraAlDelAppleID() {
        // La simetría NO está en las reglas a propósito: `decisions` solo mira la cola, así que el caso
        // «el mismatch llega DESPUÉS» no se puede expresar aquí. Lo cierra un guard en
        // `AppBootstrapper.checkForICloudMismatch`. Este caso fija que aquí no se resuelve, para que
        // nadie retire aquel guard creyendo que esta regla lo cubre.
        let (drops, accept) = IntentSupersessionLogic.decisions(
            queued: [.appleIDChangedClosePrivate], incoming: .iCloudMismatch)
        #expect(drops.isEmpty)
        #expect(accept == true)
    }
}
