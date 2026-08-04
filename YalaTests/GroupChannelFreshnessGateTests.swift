//
//  GroupChannelFreshnessGateTests.swift
//  YalaTests
//
//  Tabla de la decisión pura de `GroupChannelFreshnessGate`: ¿puedo afirmar que un gasto de grupo NO
//  EXISTE, o es que su canal todavía no lo ha traído?
//
//  Los tests de escenario (sobre el store, con el barrido real) viven en
//  `GroupRemoteDeletionUnbridgeTests.swift`; aquí solo se fija la máquina de decisión, incluido el
//  **motivo** de cada negativa — es lo que viaja al canario `bridgedTxOrphanSweepDeferred`, y sin él un
//  gate clavado sería indistinguible de «no había huérfanas».
//

import Foundation
import Testing

@testable import Yala

@Suite("Frescura del canal de Grupos · decisión pura")
struct GroupChannelFreshnessGateTests {

    private func evidence(
        settled: Bool = true,
        backendChannel: Bool = true,
        pullCompleted: Bool = false,
        cursorListsZone: Bool = false,
        cloudKitBothEngines: Bool = false,
        cloudKitZoneFailed: Bool = false
    ) -> GroupChannelFreshnessGate.ZoneEvidence {
        GroupChannelFreshnessGate.ZoneEvidence(
            zoneHasSettledGroup: settled,
            belongsToBackendChannel: backendChannel,
            backendPullCompleted: pullCompleted,
            backendCursorListsZone: cursorListsZone,
            cloudKitBothEnginesCompletedFetchCycle: cloudKitBothEngines,
            cloudKitZoneFetchFailedThisSession: cloudKitZoneFailed)
    }

    // MARK: - El guard anterior, que sigue siendo el primer escalón

    /// El caso que `zoneIsSettled` SÍ cubría y que NO se puede perder: device recién instalado cuyo import
    /// personal se asienta ANTES del pull de Grupos, con todo el corpus puenteado pareciendo huérfano.
    @Test func unsettledZone_isNeverFresh_evenWithBothChannelsDelivering() {
        let e = evidence(
            settled: false, pullCompleted: true, cursorListsZone: true, cloudKitBothEngines: true)
        #expect(GroupChannelFreshnessGate.evaluate(e) == .noSettledGroup)
        #expect(GroupChannelFreshnessGate.isFresh(e) == false)
    }

    // MARK: - Canal backend

    /// El escenario del bug: zona asentada desde hace semanas y canal parado (kill-switch, sesión
    /// caducada, snapshot de remote-config ausente). El marcador de primer import no dice nada de esto.
    @Test func backendZone_withoutCompletedPull_isNotFresh() {
        let e = evidence(pullCompleted: false, cursorListsZone: true)
        #expect(GroupChannelFreshnessGate.evaluate(e) == .backendChannelIdle)
    }

    /// El pull agotó su entrega pero el servidor no enumera esta zona para este usuario ⇒ este canal no
    /// habla de ella, así que su silencio no prueba nada.
    @Test func backendZone_notListedInCursor_isNotFresh() {
        let e = evidence(pullCompleted: true, cursorListsZone: false)
        #expect(GroupChannelFreshnessGate.evaluate(e) == .backendZoneOutOfScope)
    }

    @Test func backendZone_withCompletedPullAndCursor_isFresh() {
        let e = evidence(pullCompleted: true, cursorListsZone: true)
        #expect(GroupChannelFreshnessGate.evaluate(e) == .fresh)
    }

    /// Los engines de CloudKit son irrelevantes para una zona del canal backend: sus gastos bajan por el
    /// pull (el guard G6-3 descarta los records CloudKit de esa zona).
    @Test func backendZone_ignoresCloudKitSignals() {
        let idle = evidence(pullCompleted: true, cursorListsZone: true,
                            cloudKitBothEngines: false, cloudKitZoneFailed: true)
        #expect(GroupChannelFreshnessGate.evaluate(idle) == .fresh)
    }

    // MARK: - Canal CloudKit

    /// Un grupo CloudKit NUNCA tiene entrada en el cursor del pull, así que exigirla lo dejaría bloqueado
    /// para siempre: su evidencia es la del otro canal.
    @Test func cloudKitZone_ignoresBackendSignals() {
        let e = evidence(backendChannel: false, pullCompleted: true, cursorListsZone: true,
                         cloudKitBothEngines: false)
        #expect(GroupChannelFreshnessGate.evaluate(e) == .cloudKitChannelIdle)
    }

    @Test func cloudKitZone_withBothEngines_isFresh() {
        let e = evidence(backendChannel: false, cloudKitBothEngines: true)
        #expect(GroupChannelFreshnessGate.evaluate(e) == .fresh)
    }

    /// El testigo NEGATIVO manda sobre el ciclo de los engines: el ciclo cerró, pero el de ESTA zona llegó
    /// con error y su contenido no bajó.
    @Test func cloudKitZone_withFailedZoneFetch_isNotFresh() {
        let e = evidence(backendChannel: false, cloudKitBothEngines: true, cloudKitZoneFailed: true)
        #expect(GroupChannelFreshnessGate.evaluate(e) == .cloudKitZoneFetchFailed)
    }

    // MARK: - Falla CERRADO

    /// La evidencia toda en `false` —lo que ve un device en su primer arranque, o con el canal apagado—
    /// nunca concede. Es la propiedad que separa «perder una limpieza» de «destruir una transacción».
    @Test func allEvidenceAbsent_isNeverFresh() {
        for backendChannel in [true, false] {
            let e = evidence(settled: true, backendChannel: backendChannel)
            #expect(GroupChannelFreshnessGate.isFresh(e) == false,
                    "con backendChannel=\(backendChannel) el gate concedió sin evidencia")
        }
    }

    /// Barrido exhaustivo de las 32 combinaciones con la zona asentada: `.fresh` sale EXACTAMENTE en los
    /// dos caminos declarados y en ningún otro. Un `guard` invertido o un `||` donde va un `&&` cae aquí.
    @Test func onlyTheTwoDeclaredPathsAreFresh() {
        for backendChannel in [true, false] {
            for pull in [true, false] {
                for cursor in [true, false] {
                    for engines in [true, false] {
                        for failed in [true, false] {
                            let e = evidence(
                                backendChannel: backendChannel, pullCompleted: pull,
                                cursorListsZone: cursor, cloudKitBothEngines: engines,
                                cloudKitZoneFailed: failed)
                            let expected = backendChannel ? (pull && cursor) : (engines && !failed)
                            #expect(GroupChannelFreshnessGate.isFresh(e) == expected,
                                    """
                                    backend=\(backendChannel) pull=\(pull) cursor=\(cursor) \
                                    engines=\(engines) failed=\(failed) → \
                                    \(GroupChannelFreshnessGate.evaluate(e))
                                    """)
                        }
                    }
                }
            }
        }
    }
}
