//
//  GroupPullRescueGateTests.swift
//  YalaTests / CloudSync
//
//  C-4 (PIEZA 2): tabla de decisión del RESCATE de pull. Pura: sin store, sin singletons, sin reloj.
//
//  Lo que estos tests protegen no es «que el gate diga sí» — es que diga NO en cada una de las siete
//  situaciones en las que adoptar un record sería peor que perderlo. El default de la feature es
//  descartar; abrir el rescate exige que las siete condiciones se cumplan A LA VEZ.
//

import Foundation
import Testing

@testable import Yala

@Suite("GroupPullRescueGate · C-4 PIEZA 2")
struct GroupPullRescueGateTests {

    /// Señal con el rescate ABIERTO: flag on, sesión sana, batch sano, canal backend asentado para el
    /// grupo, tipo rescatable y fila ausente. Cada test apaga UNA cosa.
    private func open(
        flagOn: Bool = true,
        replayingFullCorpus: Bool = false,
        prefetchFailed: Bool = false,
        backendPullCompletedThisSession: Bool = true,
        groupHasBackendCursor: Bool = true,
        isRescuableType: Bool = true,
        existsLocally: Bool = false
    ) -> GroupPullRescueGate.Signal {
        GroupPullRescueGate.Signal(
            flagOn: flagOn,
            replayingFullCorpus: replayingFullCorpus,
            prefetchFailed: prefetchFailed,
            backendPullCompletedThisSession: backendPullCompletedThisSession,
            groupHasBackendCursor: groupHasBackendCursor,
            isRescuableType: isRescuableType,
            existsLocally: existsLocally)
    }

    // MARK: - El único camino que rescata

    @Test func rescuesOnlyWhenEverySignalIsGreen() {
        #expect(GroupPullRescueGate.decide(open()) == .rescue)
        #expect(GroupPullRescueGate.skipReason(open()) == "rescued")
    }

    // MARK: - Las siete puertas, una a una

    /// Invariante 4: con el canal apagado el comportamiento es el de siempre. Es el primer corte, antes
    /// de cualquier otra consideración.
    @Test func flagOffDiscards() {
        #expect(GroupPullRescueGate.decide(open(flagOn: false)) == .discard)
        #expect(GroupPullRescueGate.skipReason(open(flagOn: false)) == "flagOff")
    }

    /// Resurrección en masa: sin token, CloudKit re-entrega el corpus entero y toda fila que el backend
    /// borró tras migrar volvería como «nunca vista».
    @Test func fullCorpusReplayDiscards() {
        #expect(GroupPullRescueGate.decide(open(replayingFullCorpus: true)) == .discard)
        #expect(GroupPullRescueGate.skipReason(open(replayingFullCorpus: true)) == "replay")
    }

    /// Un store que no se ha podido leer no es base para adoptar nada.
    @Test func failedPrefetchDiscards() {
        #expect(GroupPullRescueGate.decide(open(prefetchFailed: true)) == .discard)
        #expect(GroupPullRescueGate.skipReason(open(prefetchFailed: true)) == "prefetchFailed")
    }

    /// Sin un pull backend COMPLETO, «ausente localmente» no dice nada sobre el servidor: el device de
    /// un miembro enciende `isBackendGroup` DENTRO del pull, antes de recibir las filas.
    @Test func withoutACompletedBackendPullDiscards() {
        #expect(GroupPullRescueGate.decide(open(backendPullCompletedThisSession: false)) == .discard)
        #expect(GroupPullRescueGate.skipReason(open(backendPullCompletedThisSession: false)) == "noBackendPull")
    }

    /// Un pull completo de OTROS grupos no dice nada de ÉSTE. El cursor por grupo es lo que ata la
    /// señal al grupo concreto.
    @Test func withoutTheGroupCursorDiscards() {
        #expect(GroupPullRescueGate.decide(open(groupHasBackendCursor: false)) == .discard)
        #expect(GroupPullRescueGate.skipReason(open(groupHasBackendCursor: false)) == "noCursor")
    }

    /// Invariante 3: `GroupMeta` y `SplitMember` no se adoptan jamás.
    @Test func nonRescuableTypeDiscards() {
        #expect(GroupPullRescueGate.decide(open(isRescuableType: false)) == .discard)
        #expect(GroupPullRescueGate.skipReason(open(isRescuableType: false)) == "notRescuable")
    }

    /// El caso que el guard G6-3 (C2) siempre cubrió, y que el rescate NO debe tocar: el eco stale.
    @Test func staleEchoDiscards() {
        #expect(GroupPullRescueGate.decide(open(existsLocally: true)) == .discard)
        #expect(GroupPullRescueGate.skipReason(open(existsLocally: true)) == "staleEcho")
    }

    // MARK: - Precedencia del motivo

    /// `skipReason` espeja el orden de `decide`: primero lo que apaga el rescate entero, luego el grupo,
    /// luego el record. Con TODO en rojo el motivo es el más externo — si no, el breadcrumb culparía al
    /// eco stale de un descarte que en realidad causó el flag apagado.
    @Test func reasonPrecedenceIsOutermostFirst() {
        let allRed = open(
            flagOn: false,
            replayingFullCorpus: true,
            prefetchFailed: true,
            backendPullCompletedThisSession: false,
            groupHasBackendCursor: false,
            isRescuableType: false,
            existsLocally: true)
        #expect(GroupPullRescueGate.skipReason(allRed) == "flagOff")

        // Quitando la más externa aflora la siguiente, y así sucesivamente.
        #expect(GroupPullRescueGate.skipReason(open(
            replayingFullCorpus: true, prefetchFailed: true,
            backendPullCompletedThisSession: false)) == "replay")
        #expect(GroupPullRescueGate.skipReason(open(
            prefetchFailed: true, backendPullCompletedThisSession: false)) == "prefetchFailed")
        #expect(GroupPullRescueGate.skipReason(open(
            backendPullCompletedThisSession: false, groupHasBackendCursor: false)) == "noBackendPull")
        #expect(GroupPullRescueGate.skipReason(open(
            groupHasBackendCursor: false, isRescuableType: false)) == "noCursor")
        #expect(GroupPullRescueGate.skipReason(open(
            isRescuableType: false, existsLocally: true)) == "notRescuable")
    }

    /// Cada motivo que `skipReason` puede devolver como DESCARTE tiene que corresponder a un `.discard`
    /// real: un slug que saliera con el gate abierto sería una mentira en Console.app.
    @Test func everySkipReasonImpliesADiscard() {
        let cases: [GroupPullRescueGate.Signal] = [
            open(flagOn: false),
            open(replayingFullCorpus: true),
            open(prefetchFailed: true),
            open(backendPullCompletedThisSession: false),
            open(groupHasBackendCursor: false),
            open(isRescuableType: false),
            open(existsLocally: true),
        ]
        for signal in cases {
            #expect(GroupPullRescueGate.decide(signal) == .discard)
            #expect(GroupPullRescueGate.skipReason(signal) != "rescued")
        }
    }
}
