//
//  PrivateSignOutExportGateLogicTests.swift
//  YalaTests
//
//  Paso 9 del rediseño de sesiones: la decisión PURA de la espera del export de iCloud antes de borrar lo
//  local en un cierre privado. Tabla completa del canal de copia, del filtro de pendientes, del veredicto y
//  del bucle con reloj inyectado — sin CloudKit, sin `Date()` y sin esperar.
//

import Foundation
import Testing

@testable import Yala

@Suite("Cierre privado · ¿hay copia en iCloud a la que esperar?")
struct PrivateSignOutCopyChannelTests {

    typealias Gate = PrivateSignOutExportGateLogic

    @Test("sin espejo montado no hay copia, diga lo que diga el espejo")
    func noMirror_isNoCopy() {
        for notAuthenticated in [false, true] {
            #expect(Gate.copyChannel(mountAttachesMirror: false,
                                     mirrorReportedNotAuthenticated: notAuthenticated) == .none)
        }
    }

    @Test("si CloudKit dijo que no hay cuenta, no hay copia")
    func notAuthenticated_isNoCopy() {
        #expect(Gate.copyChannel(mountAttachesMirror: true, mirrorReportedNotAuthenticated: true) == .none)
    }

    /// Sin prueba en contra hay copia, y se espera. El token (mide iCloud DRIVE) y el ancla (no existe hasta el
    /// primer export de esta versión) ya no entran: con ellos, la hoja le decía «no hay copia en ninguna parte»
    /// a quien la tenía, y el segundo gesto se saltaba la espera (review adversarial del paso 9).
    @Test("con espejo y sin prueba en contra hay copia: se espera al export")
    func mirrorWithoutProofAgainst_isICloud() {
        #expect(Gate.copyChannel(mountAttachesMirror: true, mirrorReportedNotAuthenticated: false) == .iCloud)
    }
}

@Suite("Cierre privado · un ancla del futuro no sirve")
struct PrivateSignOutAnchorClockTests {

    typealias Gate = PrivateSignOutExportGateLogic
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("un ancla del pasado o del presente sirve tal cual")
    func pastOrPresentAnchor_isUsable() {
        #expect(Gate.usableAnchor(now.addingTimeInterval(-3600), now: now) == now.addingTimeInterval(-3600))
        #expect(Gate.usableAnchor(now, now: now) == now)
    }

    /// El reloj retrocedió con la app cerrada: con esa ancla, todo cambio nuevo quedaría «antes» y contaría
    /// como subido. Se lee como si no hubiera ancla, que cuenta todo lo local.
    @Test("un ancla en el futuro se descarta")
    func futureAnchor_isDiscarded() {
        #expect(Gate.usableAnchor(now.addingTimeInterval(Gate.anchorFutureTolerance + 1), now: now) == nil)
        #expect(Gate.usableAnchor(now.addingTimeInterval(86_400), now: now) == nil)
    }

    @Test("el margen absorbe el desfase normal entre relojes, y sin ancla no hay ancla")
    func toleranceBoundary_andNil() {
        #expect(Gate.usableAnchor(now.addingTimeInterval(Gate.anchorFutureTolerance), now: now) != nil)
        #expect(Gate.usableAnchor(nil, now: now) == nil)
    }
}

@Suite("Cierre privado · ¿qué cuenta como pendiente de subir?")
struct PrivateSignOutPendingWriteTests {

    typealias Gate = PrivateSignOutExportGateLogic
    private let anchor = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("lo que escribió el espejo bajó de iCloud: nunca está pendiente")
    func mirrorAuthored_isNeverPending() {
        for author in ["NSCloudKitMirroringDelegate.import", "NSCloudKitMirroringDelegate.export",
                       "NSCloudKitMirroringDelegate.setup"] {
            #expect(!Gate.isPendingLocalWrite(timestamp: anchor.addingTimeInterval(60), author: author,
                                              confirmedExportStart: anchor))
            #expect(!Gate.isPendingLocalWrite(timestamp: anchor, author: author, confirmedExportStart: nil))
        }
    }

    @Test("un cambio local posterior al inicio del export está pendiente")
    func localAfterAnchor_isPending() {
        for author in [nil, "CloudSyncOutbox", "yala"] as [String?] {
            #expect(Gate.isPendingLocalWrite(timestamp: anchor.addingTimeInterval(1), author: author,
                                             confirmedExportStart: anchor))
        }
    }

    @Test("un cambio local anterior al inicio del export ya viajó en él")
    func localBeforeAnchor_isNotPending() {
        #expect(!Gate.isPendingLocalWrite(timestamp: anchor.addingTimeInterval(-1), author: nil,
                                          confirmedExportStart: anchor))
    }

    /// El borde cuenta como pendiente: confirmado en el mismo instante en que arrancó el export, pudo
    /// quedarse fuera. `>` en vez de `>=` lo daría por subido.
    @Test("en el instante exacto del inicio, cuenta como pendiente")
    func localAtAnchor_isPending() {
        #expect(Gate.isPendingLocalWrite(timestamp: anchor, author: nil, confirmedExportStart: anchor))
    }

    @Test("sin ancla, todo lo local cuenta (puede sobre-contar, jamás sub-contar)")
    func noAnchor_everyLocalWriteIsPending() {
        #expect(Gate.isPendingLocalWrite(timestamp: .distantPast, author: nil, confirmedExportStart: nil))
    }
}

@Suite("Cierre privado · ¿se puede borrar ya?")
struct PrivateSignOutExportVerdictTests {

    typealias Gate = PrivateSignOutExportGateLogic

    @Test("cero pendientes autoriza a borrar, a cualquier altura de la espera")
    func zeroPending_proceeds() {
        #expect(Gate.verdict(pendingCount: 0, elapsedSeconds: 0) == .proceed)
        #expect(Gate.verdict(pendingCount: 0, elapsedSeconds: 999) == .proceed)
    }

    @Test("con pendientes y presupuesto, se espera")
    func pendingWithinBudget_waits() {
        #expect(Gate.verdict(pendingCount: 3, elapsedSeconds: 0) == .wait)
        #expect(Gate.verdict(pendingCount: 3, elapsedSeconds: Gate.budgetSeconds - 1) == .wait)
    }

    @Test("agotado el presupuesto, se bloquea contando lo pendiente")
    func pendingAtBudget_stalls() {
        #expect(Gate.verdict(pendingCount: 3, elapsedSeconds: Gate.budgetSeconds) == .stalled(pendingCount: 3))
    }

    /// Un conteo que no se pudo hacer JAMÁS es un cero: dejar pasar el `nil` borraría sin haber demostrado
    /// nada.
    @Test("un conteo imposible nunca autoriza: espera y luego se bloquea sin número")
    func unknownCount_neverProceeds() {
        #expect(Gate.verdict(pendingCount: nil, elapsedSeconds: 0) == .wait)
        #expect(Gate.verdict(pendingCount: nil, elapsedSeconds: Gate.budgetSeconds) == .stalled(pendingCount: nil))
    }
}

@Suite("Cierre privado · el bucle de la espera (reloj inyectado)")
@MainActor
struct PrivateSignOutExportLoopTests {

    typealias Gate = PrivateSignOutExportGateLogic

    @Test("sin pendientes sale al instante, sin dormir ni avisar")
    func alreadyExported_proceedsWithoutSleeping() async {
        var slept = 0
        var waited = 0
        let verdict = await Gate.awaitConfirmedExport(
            pendingCount: { 0 }, onWaiting: { waited += 1 }, sleep: { _ in slept += 1; return true })
        #expect(verdict == .proceed)
        #expect(slept == 0)
        #expect(waited == 0)
    }

    @Test("sale en cuanto el export confirma lo último")
    func exportConfirmsMidway_proceeds() async {
        var counts: [Int?] = [2, 2, 1, 0]
        var slept = 0
        let verdict = await Gate.awaitConfirmedExport(
            pendingCount: { counts.isEmpty ? 0 : counts.removeFirst() },
            sleep: { _ in slept += 1; return true })
        #expect(verdict == .proceed)
        #expect(slept == 3)
    }

    @Test("agota el presupuesto exacto y se bloquea con el último conteo")
    func neverConfirms_stallsAfterBudget() async {
        var slept = 0.0
        var waitingSignals = 0
        let verdict = await Gate.awaitConfirmedExport(
            budgetSeconds: 5, pollIntervalSeconds: 1,
            pendingCount: { 4 },
            onWaiting: { waitingSignals += 1 },
            sleep: { seconds in slept += seconds; return true })
        #expect(verdict == .stalled(pendingCount: 4))
        #expect(slept == 5, "tiene que dormir el presupuesto entero, ni un intervalo menos")
        #expect(waitingSignals == 5, "el caption de espera se enciende en cada vuelta")
    }

    @Test("una cancelación no borra: se bloquea sin número")
    func cancellation_stallsUnknown() async {
        let verdict = await Gate.awaitConfirmedExport(pendingCount: { 1 }, sleep: { _ in false })
        #expect(verdict == .stalled(pendingCount: nil))
    }
}
