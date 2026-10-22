//
//  ForwardOriginPendingEffectsTests.swift
//  YalaTests / CloudSync
//
//  La tabla de `ForwardOriginPendingEffects` (ticket `migration-activation-drops-pending-effects-it-never-restores`):
//  qué hace cada paso de la ida con los pendientes que «Activar la nube» reemplaza. El recorrido del runner vive en
//  `MigrationRunnerTests`.
//

import Foundation
import Testing

@testable import Yala

@Suite("Ida: pendientes del origen · lógica pura")
struct ForwardOriginPendingEffectsTests {

    typealias Step = ForwardOriginPendingEffects.Step

    private let window: [MigrationPhase] = [.dryRun, .consent, .authenticating, .claimingMigration]
    private let outside: [MigrationPhase] = [
        .notStarted, .icloudActive, .done, .failedRollback, .waitingForLeader, .assigningIdentity,
        .uploadingSnapshot, .verifying, .cutover(.pending), .reverseConfirm(.done), .reverseClaimLeader,
    ]

    /// La ventana son las cuatro fases de la ida antes de que el servidor conteste el claim, y ninguna más.
    @Test func isBeforeClaim_isExactlyTheFourPhases() {
        for phase in window { #expect(ForwardOriginPendingEffects.isBeforeClaim(phase), "\(phase)") }
        for phase in outside { #expect(!ForwardOriginPendingEffects.isBeforeClaim(phase), "\(phase)") }
    }

    /// Guarda solo el toque que ENTRA desde fuera. Desde dentro (`dryRun → consent`) no pisa lo guardado, y entrar sin
    /// toque (`waitingForLeader → claimingMigration`, el seguidor que vuelve a reclamar) no guarda los pendientes de otra
    /// fase como si fueran del origen.
    @Test func save_onlyTheTapThatEntersFromOutside() {
        for origin: MigrationPhase in [.notStarted, .icloudActive] {
            for dryRun in [false, true] {
                let next: MigrationPhase = dryRun ? .dryRun : .consent
                #expect(ForwardOriginPendingEffects.step(
                    from: origin, to: next, event: .userActivated(dryRun: dryRun)) == .save, "\(origin) dryRun=\(dryRun)")
            }
        }
        #expect(ForwardOriginPendingEffects.step(
            from: .dryRun, to: .consent, event: .userActivated(dryRun: false)) == .keep)
        #expect(ForwardOriginPendingEffects.step(
            from: .dryRun, to: .dryRun, event: .userActivated(dryRun: true)) == .keep)
        #expect(ForwardOriginPendingEffects.step(
            from: .waitingForLeader, to: .claimingMigration, event: .leaderVanished) == .keep)
    }

    /// Repone toda VUELTA al inicio sin un claim contestado: las tres del ticket, «Cancelar» al 22 % y la normalización
    /// del `resume` (sin evento) desde las tres fases no durables.
    @Test func restore_everyReturnToNotStartedBeforeTheClaimIsAnswered() {
        let exits: [(MigrationPhase, MigrationEvent?)] = [
            (.consent, .consentDeclined),
            (.authenticating, .signInFailed),
            (.claimingMigration, .claimRefusedExistingAccount),
            (.claimingMigration, .forwardStepCancelled),
            (.dryRun, nil), (.consent, nil), (.authenticating, nil),
        ]
        for (from, event) in exits {
            #expect(ForwardOriginPendingEffects.step(from: from, to: .notStarted, event: event) == .restore,
                    "\(from) · \(String(describing: event))")
        }
    }

    /// Descarta toda otra salida de la ventana: el claim contestado —la migración empezó, se sigue a un líder o se
    /// adopta— y `failedRollback`, donde lo guardado podría ser un adopt que no puede ejecutarse en un terminal de fallo.
    @Test func discard_everyOtherExitFromTheWindow() {
        let exits: [(MigrationPhase, MigrationPhase, MigrationEvent)] = [
            (.claimingMigration, .assigningIdentity, .claimResult(.created, sameDeviceReclaim: false)),
            (.claimingMigration, .waitingForLeader, .claimResult(.claimingInProgress, sameDeviceReclaim: false)),
            (.claimingMigration, .notStarted, .claimResult(.existingStable, sameDeviceReclaim: false)),
            (.claimingMigration, .failedRollback,
             .forwardStepStalled(stalledSeconds: 900, causeStalledSeconds: 900, cause: .definitive)),
            (.consent, .failedRollback, .fatalError),
            (.authenticating, .failedRollback, .fatalError),
            (.claimingMigration, .failedRollback, .fatalError),
        ]
        for (from, to, event) in exits {
            #expect(ForwardOriginPendingEffects.step(from: from, to: to, event: event) == .discard, "\(from) → \(to)")
        }
    }

    /// Dentro de la ventana nada se toca, y el self-hold del claim es el caso que importa: un brazo que descartara ahí
    /// perdía lo guardado con un corte de red, la trampa que mordió a la vuelta en `reverseClaimLeader`.
    @Test func keep_insideTheWindow_andOutsideIt() {
        #expect(ForwardOriginPendingEffects.step(
            from: .consent, to: .authenticating, event: .consentAccepted) == .keep)
        #expect(ForwardOriginPendingEffects.step(
            from: .authenticating, to: .claimingMigration, event: .signInSucceeded) == .keep)
        #expect(ForwardOriginPendingEffects.step(
            from: .claimingMigration, to: .claimingMigration,
            event: .forwardStepStalled(stalledSeconds: 10, causeStalledSeconds: 0, cause: .unknown)) == .keep)
        // Fuera de la ventana: la vuelta a iCloud y cualquier paso de la ida ya empezada.
        #expect(ForwardOriginPendingEffects.step(
            from: .notStarted, to: .reverseConfirm(.notStarted), event: .reverseActivated) == .keep)
        #expect(ForwardOriginPendingEffects.step(
            from: .reverseConfirm(.notStarted), to: .notStarted, event: .reverseDeclined) == .keep)
        #expect(ForwardOriginPendingEffects.step(
            from: .assigningIdentity, to: .notStarted, event: .forwardStepCancelled) == .keep)
        #expect(ForwardOriginPendingEffects.step(
            from: .waitingForLeader, to: .notStarted, event: .leaderCompleted) == .keep)
    }

    /// El toque guarda todo menos el efecto del adopt: la activación nueva lo sustituye, y reponerlo tras «Cancelar»
    /// ejecutaría el adopt que se acaba de cancelar.
    @Test func effectsToSave_dropsOnlyTheAdoptEffect() {
        #expect(ForwardOriginPendingEffects.effectsToSave(
            [.adoptBackendAccount, .completeReverseServer]) == [.completeReverseServer])
        let closure: [MigrationEffect] = [.deleteCloudKitMarker, .clearCloudBeacon, .persistICloudMode, .completeReverseServer]
        #expect(ForwardOriginPendingEffects.effectsToSave(closure) == closure, "el cuarteto de cierre de la vuelta, entero")
        #expect(ForwardOriginPendingEffects.effectsToSave([.rearmMirrorOff, .reverseRollback])
            == [.rearmMirrorOff, .reverseRollback], "la salida a medias de la vuelta, entera")
    }
}
