//
//  CloudSyncDebugReverseClockLogicTests.swift
//  YalaTests
//
//  Ticket `debug-panel-shows-a-counter-the-reverse-no-longer-moves`: el panel DEV no afirma «red 0» de una vuelta parada
//  antes del montaje y enseña en qué fase y desde cuándo.
//

import Foundation
import Testing
@testable import Yala

@Suite("Panel de la nube · techo de la vuelta antes del montaje")
struct CloudSyncDebugReverseClockLogicTests {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func contadores_enLasCuatroFasesDeLaVuelta_noAfirmanRed() {
        for phase: MigrationPhase in [.reverseClaimLeader, .reverseDrainAll, .reverseVerify, .reverseFreezeBackend] {
            let label = CloudSyncDebugReverseClockLogic.countersLabel(
                phase: phase, mismatchRetries: 1, networkRetries: 0, leaderDeviceID: "d1", serverSeqCut: 7)
            #expect(!label.contains("red 0"), "\(phase): \(label)")
            #expect(label.contains("Techo vuelta"), "\(phase)")
            #expect(label.hasPrefix("mismatch 1 · "))
            #expect(label.hasSuffix("leader d1 · seqCut 7"))
        }
    }

    /// Control: la ida sigue gastando el contador en `verifying`, y ahí se pinta como siempre.
    @Test func contadores_fueraDeLaVuelta_pintanLaRed() {
        let label = CloudSyncDebugReverseClockLogic.countersLabel(
            phase: .verifying, mismatchRetries: 0, networkRetries: 2, leaderDeviceID: nil, serverSeqCut: 0)
        #expect(label == "mismatch 0 · red 2 · leader — · seqCut 0")
    }

    @Test func reloj_paradaPorRed_diceFaseDesdeCuandoYCuanto() {
        let clock = CloudSyncDebugReverseClockLogic.Clock(
            phase: .reverseDrainAll, sealedPhaseRaw: "drain", progressAt: now.addingTimeInterval(-600))
        let label = CloudSyncDebugReverseClockLogic.clockLabel(clock, now: now)
        #expect(label.hasPrefix("drain · parada 600s (desde "), "\(label)")
        #expect(label.contains("causa — (red o sin motivo: pausa)"))
        #expect(!label.contains("definitivo"))
    }

    @Test func reloj_conCausaYDefinitivo_sumaElTramoAbierto() {
        let clock = CloudSyncDebugReverseClockLogic.Clock(
            phase: .reverseVerify, sealedPhaseRaw: "verify", progressAt: now.addingTimeInterval(-1_000),
            causeRaw: "accountUnavailable", causeAt: now.addingTimeInterval(-100), causeAccruedSeconds: 50,
            definitiveAt: nil, definitiveAccruedSeconds: 300)
        let label = CloudSyncDebugReverseClockLogic.clockLabel(clock, now: now)
        #expect(label.contains("verify · parada 1000s"))
        #expect(label.contains("causa accountUnavailable 150s"), "\(label)")
        #expect(!label.contains("causa accountUnavailable 150s (en pausa)"))
        #expect(label.contains("definitivo 300s (en pausa)"))
    }

    /// Mismo cálculo que el runner: con el sello de OTRA fase, cambiar de fase es el avance y no hay «parada N».
    @Test func reloj_selloDeOtraFase_noCuentaParada() {
        let clock = CloudSyncDebugReverseClockLogic.Clock(
            phase: .reverseVerify, sealedPhaseRaw: "drain", progressAt: now.addingTimeInterval(-9_000))
        let label = CloudSyncDebugReverseClockLogic.clockLabel(clock, now: now)
        #expect(label.hasPrefix("sello de drain (fase actual: verify)"), "\(label)")
        #expect(!label.contains("parada"))
    }

    @Test func reloj_selloEnElFuturo_seDiceAsi() {
        let clock = CloudSyncDebugReverseClockLogic.Clock(
            phase: .reverseClaimLeader, sealedPhaseRaw: "claim", progressAt: now.addingTimeInterval(3_600))
        let label = CloudSyncDebugReverseClockLogic.clockLabel(clock, now: now)
        #expect(label.hasPrefix("claim · sello en el futuro"), "\(label)")
    }

    @Test func reloj_sinSello() {
        #expect(CloudSyncDebugReverseClockLogic.clockLabel(.init(phase: .reverseFreezeBackend), now: now)
                == "freeze · sin sello (aún no se observó parada)")
        #expect(CloudSyncDebugReverseClockLogic.clockLabel(.init(phase: .uploadingSnapshot), now: now) == "—")
    }
}
