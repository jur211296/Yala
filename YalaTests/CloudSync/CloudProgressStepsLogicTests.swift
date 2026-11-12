//
//  CloudProgressStepsLogicTests.swift
//  YalaTests / CloudSync
//
//  Los pasos con su cifra de «Activar la nube» y «Volver a iCloud» (opción B, ticket
//  `cloud-progress-shows-real-steps-and-counts`; cards igt9, ppxk y 27z3). Lógica pura: qué paso está hecho, cuál en marcha
//  y cuál pendiente para cada fase, dónde entra la espera a iCloud, qué cifra lleva cada paso y cada cuánto re-empuja la
//  pantalla. Los nombres de fase del canario de la línea de tiempo, también: viajan al dashboard.
//

import Foundation
import Testing

@testable import Yala

@Suite("Pasos con su cifra de la nube (opción B)")
struct CloudProgressStepsLogicTests {

    typealias L = CloudProgressStepsLogic

    private func shape(_ steps: [L.Step]) -> [String] {
        steps.map { "\($0.kind):\($0.state)" }
    }

    // MARK: - Ida

    @Test("cada fase de la ida enciende su paso, con lo anterior hecho y lo siguiente pendiente")
    func forward_eachPhaseLightsItsStep() {
        let cases: [(MigrationPhase, [String])] = [
            (.consent, ["connect:active", "prepare:pending", "upload:pending", "confirm:pending"]),
            (.authenticating, ["connect:active", "prepare:pending", "upload:pending", "confirm:pending"]),
            (.claimingMigration, ["connect:active", "prepare:pending", "upload:pending", "confirm:pending"]),
            (.assigningIdentity, ["connect:done", "prepare:active", "upload:pending", "confirm:pending"]),
            (.uploadingSnapshot, ["connect:done", "prepare:done", "upload:active", "confirm:pending"]),
            (.verifying, ["connect:done", "prepare:done", "upload:active", "confirm:pending"]),
            (.cutover(.pending), ["connect:done", "prepare:done", "upload:done", "confirm:active"]),
            (.cutover(.markerWritten), ["connect:done", "prepare:done", "upload:done", "confirm:active"]),
            (.done, ["connect:done", "prepare:done", "upload:done", "confirm:done"]),
        ]
        for (phase, expected) in cases {
            let steps = L.forwardSteps(phase: phase, adoptEffectPending: false, waitingForICloud: false, upload: nil)
            #expect(shape(steps) == expected, "\(phase)")
        }
    }

    @Test("el efecto del adopt que se reintenta es el paso de preparar; sin él, notStarted es conectar")
    func forward_adoptEffect_isThePrepareStep() {
        let adopt = L.forwardSteps(phase: .notStarted, adoptEffectPending: true, waitingForICloud: false, upload: nil)
        #expect(shape(adopt) == ["connect:done", "prepare:active", "upload:pending", "confirm:pending"])
        let fresh = L.forwardSteps(phase: .notStarted, adoptEffectPending: false, waitingForICloud: false, upload: nil)
        #expect(shape(fresh).first == "connect:active")
    }

    @Test("subiendo, el paso lleva la cifra real y la barra la sigue")
    func forward_upload_carriesTheRealCount() {
        let steps = L.forwardSteps(phase: .uploadingSnapshot, adoptEffectPending: false, waitingForICloud: false,
                                   upload: .init(done: 650, total: 1_537))
        let upload = steps.first { $0.kind == .upload }
        #expect(upload?.count == .uploaded(done: 650, total: 1_537, fraction: 650.0 / 1_537.0))
        // Solo el paso en marcha lleva cifra.
        #expect(steps.filter { $0.count != nil }.count == 1)
    }

    @Test("la cifra no se sale de su total ni baja de cero; sin total no hay cifra")
    func forward_upload_countIsClamped() {
        #expect(L.uploadCount(phase: .uploadingSnapshot, upload: .init(done: 9, total: 5))
                == .uploaded(done: 5, total: 5, fraction: 1))
        #expect(L.uploadCount(phase: .uploadingSnapshot, upload: .init(done: -3, total: 5))
                == .uploaded(done: 0, total: 5, fraction: 0))
        #expect(L.uploadCount(phase: .uploadingSnapshot, upload: .init(done: 0, total: 0)) == nil)
        #expect(L.uploadCount(phase: .uploadingSnapshot, upload: nil) == nil)
    }

    @Test("en la verificación todo subió: la barra va llena")
    func forward_verifying_isFull() {
        #expect(L.uploadCount(phase: .verifying, upload: .init(done: 3, total: 12))
                == .uploaded(done: 12, total: 12, fraction: 1))
        #expect(L.uploadCount(phase: .verifying, upload: nil) == nil)
    }

    @Test("esperando a iCloud antes de preparar: conectar hecho y la espera en su sitio (lienzo B2)")
    func forward_waitingBeforePreparing_isTheB2Layout() {
        for phase in [MigrationPhase.authenticating, .claimingMigration, .assigningIdentity] {
            let steps = L.forwardSteps(phase: phase, adoptEffectPending: false, waitingForICloud: true, upload: nil)
            #expect(shape(steps) == ["connect:done", "waitICloud:active", "upload:pending", "confirm:pending"], "\(phase)")
        }
    }

    @Test("esperando a iCloud más adelante: la espera va delante del paso que espera, que queda pendiente")
    func forward_waitingLater_goesBeforeTheWaitingStep() {
        let steps = L.forwardSteps(phase: .uploadingSnapshot, adoptEffectPending: false, waitingForICloud: true,
                                   upload: .init(done: 200, total: 900))
        #expect(shape(steps) == ["connect:done", "prepare:done", "waitICloud:active", "upload:pending", "confirm:pending"])
    }

    @Test("terminada la ida, la espera no añade nada")
    func forward_done_ignoresTheWait() {
        let steps = L.forwardSteps(phase: .done, adoptEffectPending: false, waitingForICloud: true, upload: nil)
        #expect(steps.allSatisfy { $0.state == .done })
    }

    // MARK: - Vuelta

    private func reverse(
        _ phase: MigrationPhase, waiting: Bool = false, wiping: Int? = nil, starting: Bool = false,
        pending: Int? = nil, first: Int? = nil
    ) -> [L.Step] {
        L.reverseSteps(phase: phase, waitingForICloud: waiting, wipingDeleted: wiping, startingReverse: starting,
                       pending: pending, firstPending: first)
    }

    @Test("las fases previas al montaje son traer de la nube; el reconcile, iCloud revisando")
    func reverse_phasesBeforeTheUpload() {
        for phase in [MigrationPhase.reverseConfirm(.done), .reverseClaimLeader, .reverseDrainAll, .reverseVerify,
                      .reverseFreezeBackend, .reverseMountMirror] {
            #expect(shape(reverse(phase)) == ["bring:active", "review:pending", "uploadToICloud:pending"], "\(phase)")
        }
        #expect(shape(reverse(.reverseReconcile(.awaitingQuiescence)))
                == ["bring:done", "review:active", "uploadToICloud:pending"])
    }

    @Test("mientras la cifra no baja de la primera, iCloud está revisando; en cuanto baja, está subiendo (lienzo B3)")
    func reverse_upload_reviewUntilTheCountDrops() {
        let review = reverse(.reverseUpload, pending: 448, first: 448)
        #expect(shape(review) == ["bring:done", "review:active", "uploadToICloud:pending"])
        #expect(review[2].count == .pendingToICloud(448), "la cifra se ve ya en el paso pendiente")
        let uploading = reverse(.reverseUpload, pending: 212, first: 448)
        #expect(shape(uploading) == ["bring:done", "review:done", "uploadToICloud:active"])
        #expect(uploading[2].count == .pendingToICloud(212))
        // Sin muestra todavía: revisando, sin cifra inventada.
        let unknown = reverse(.reverseUpload)
        #expect(shape(unknown) == ["bring:done", "review:active", "uploadToICloud:pending"])
        #expect(unknown[2].count == nil)
    }

    @Test("con todo subido el último paso está en marcha hasta que la vuelta cierra")
    func reverse_upload_drained() {
        #expect(shape(reverse(.reverseUpload, pending: 0, first: 0))
                == ["bring:done", "review:done", "uploadToICloud:active"])
        #expect(reverse(.icloudActive).allSatisfy { $0.state == .done })
    }

    @Test("«Borrar y volver a iCloud» empieza por el borrado, con su cifra")
    func reverse_wipe_isTheFirstStep() {
        let steps = reverse(.done, wiping: 1_197)
        #expect(shape(steps) == ["wipePrior:active", "bring:pending", "review:pending", "uploadToICloud:pending"])
        #expect(steps[0].count == .wiped(1_197))
    }

    @Test("recién confirmada la vuelta, con el journal aún en «nube activa», ya hay pasos")
    func reverse_starting_beforeTheJournalMoves() {
        #expect(shape(reverse(.done, starting: true)) == ["bring:active", "review:pending", "uploadToICloud:pending"])
        #expect(shape(reverse(.notStarted, starting: true)).first == "bring:active")
        // Sin la marca, una fase de fuera de la vuelta no tiene paso en marcha.
        #expect(reverse(.done).allSatisfy { $0.state == .done })
    }

    @Test("esperando a iCloud en la vuelta: va delante del paso, salvo cuando el paso ES iCloud revisando")
    func reverse_waitingForICloud() {
        #expect(shape(reverse(.done, waiting: true, starting: true))
                == ["waitICloud:active", "bring:pending", "review:pending", "uploadToICloud:pending"])
        #expect(shape(reverse(.reverseReconcile(.awaitingQuiescence), waiting: true))
                == ["bring:done", "review:active", "uploadToICloud:pending"])
        let uploading = reverse(.reverseUpload, waiting: true, pending: 100, first: 448)
        #expect(shape(uploading) == ["bring:done", "review:done", "waitICloud:active", "uploadToICloud:pending"])
        #expect(uploading[3].count == .pendingToICloud(100), "la cifra se conserva en el paso que espera")
    }

    @Test("la primera muestra se recuerda en la subida, sube si aparece más y se olvida fuera")
    func reverse_firstPending() {
        #expect(L.firstPending(previous: nil, phase: .reverseUpload, pending: 448) == 448)
        #expect(L.firstPending(previous: 448, phase: .reverseUpload, pending: 300) == 448)
        #expect(L.firstPending(previous: 448, phase: .reverseUpload, pending: 500) == 500)
        #expect(L.firstPending(previous: 448, phase: .reverseUpload, pending: nil) == 448)
        #expect(L.firstPending(previous: 448, phase: .icloudActive, pending: 0) == nil)
        #expect(L.firstPending(previous: 448, phase: .reverseReconcile(.awaitingQuiescence), pending: 448) == nil)
    }

    // MARK: - Re-empuje de la pantalla

    @Test("5 s donde solo falta observar algo local de iCloud; 30 s en el resto")
    func screenRekick_cadence() {
        for phase in [MigrationPhase.cutover(.markerWritten), .cutover(.mirrorOff), .reverseMountMirror, .reverseUpload,
                      .reverseReconcile(.awaitingQuiescence)] {
            #expect(L.screenRekickSeconds(phase: phase) == 5, "\(phase)")
        }
        for phase in [MigrationPhase.notStarted, .claimingMigration, .assigningIdentity, .uploadingSnapshot, .verifying,
                      .cutover(.pending), .cutover(.serverConfirmed), .cutover(.localModeSet), .reverseClaimLeader,
                      .reverseDrainAll, .reverseReconcile(.deletingZombies), .done, .failedRollback] {
            #expect(L.screenRekickSeconds(phase: phase) == 30, "\(phase)")
        }
    }

    // MARK: - Línea de tiempo (canario `cloudMigrationStep`)

    @Test("los nombres de fase del canario son estables: renombrar uno parte la serie")
    func timeline_labels() {
        let cases: [(MigrationPhase, String)] = [
            (.consent, "consent"), (.authenticating, "auth"), (.claimingMigration, "claim"),
            (.assigningIdentity, "identity"), (.uploadingSnapshot, "upload"), (.verifying, "verify"),
            (.cutover(.markerWritten), "cutover.markerWritten"), (.done, "done"), (.reverseClaimLeader, "rClaim"),
            (.reverseReconcile(.awaitingQuiescence), "rReconcile.awaitingQuiescence"), (.reverseUpload, "rUpload"),
            (.icloudActive, "icloudActive"),
        ]
        for (phase, label) in cases {
            #expect(CloudMigrationTimelineLogic.label(phase) == label)
        }
    }

    @Test("la duración del paso que se deja: redondeada, y sin hora de inicio o con el reloj hacia atrás no se inventa")
    func timeline_previousStepSeconds() {
        let start = Date(timeIntervalSince1970: 1_000)
        #expect(CloudMigrationTimelineLogic.previousStepSeconds(since: start, now: start.addingTimeInterval(12.4)) == 12)
        #expect(CloudMigrationTimelineLogic.previousStepSeconds(since: nil, now: start) == nil)
        #expect(CloudMigrationTimelineLogic.previousStepSeconds(since: start, now: start.addingTimeInterval(-5)) == nil)
    }
}
