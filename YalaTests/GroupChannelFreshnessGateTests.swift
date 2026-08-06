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
//  **Fase 3, commit 1 — la tabla cambió de forma y de signo.** Desaparecieron los dos campos del brazo
//  CloudKit (`cloudKitBothEnginesCompletedFetchCycle`, `cloudKitZoneFetchFailedThisSession`) y sus dos
//  veredictos, porque `SplitSyncManager` era su única fuente. Y la rama de la zona SIN canal INVIRTIÓ su
//  respuesta: pasó de negar a CONCEDER. El porqué está en la cabecera del gate; lo que estas celdas fijan
//  es que la inversión no se comió el primer escalón, que es lo único que sigue cubriendo al device
//  recién reinstalado.
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
        cursorListsZone: Bool = false
    ) -> GroupChannelFreshnessGate.ZoneEvidence {
        GroupChannelFreshnessGate.ZoneEvidence(
            zoneHasSettledGroup: settled,
            belongsToBackendChannel: backendChannel,
            backendPullCompleted: pullCompleted,
            backendCursorListsZone: cursorListsZone)
    }

    // MARK: - El guard anterior, que sigue siendo el primer escalón

    /// El caso que `zoneIsSettled` SÍ cubría y que NO se puede perder: device recién instalado cuyo import
    /// personal se asienta ANTES del pull de Grupos, con todo el corpus puenteado pareciendo huérfano.
    @Test func unsettledZone_isNeverFresh_evenWithTheChannelDelivering() {
        let e = evidence(settled: false, pullCompleted: true, cursorListsZone: true)
        #expect(GroupChannelFreshnessGate.evaluate(e) == .noSettledGroup)
        #expect(GroupChannelFreshnessGate.isFresh(e) == false)
    }

    /// **La celda que carga el peso de la Fase 3, y la que hay que leer junto a la de abajo.** Desde que la
    /// zona sin canal CONCEDE, el primer escalón es lo ÚNICO que separa «este device ya conoce el grupo» de
    /// «este device se acaba de reinstalar y su store de Grupos está vacío». Una zona legacy no tiene quien
    /// la repueble —el pull backend no la enumera— así que sin este guard el editor habilitaría Borrar y
    /// Duplicar sobre TODO el corpus puenteado de un device recién instalado, y ese borrado se exporta por
    /// el espejo personal.
    ///
    /// Mutación: mover el `guard e.belongsToBackendChannel else { return .fresh }` por ENCIMA del
    /// `guard e.zoneHasSettledGroup` deja este test en rojo y todos los demás en verde.
    @Test func unsettledZone_withoutChannel_isNotFresh_theOrderOfTheTwoGuardsIsLoadBearing() {
        let e = evidence(settled: false, backendChannel: false)
        #expect(GroupChannelFreshnessGate.evaluate(e) == .noSettledGroup,
                """
                El escalón de la fila asentada dejó de ir primero: un device recién reinstalado concede \
                sobre zonas legacy y el editor abre Borrar/Duplicar sobre gastos que sí existen.
                """)
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

    // MARK: - Zona SIN canal (legacy) — la inversión de la Fase 3

    /// **La decisión de este commit.** Una zona que no pertenece al canal backend ya no la sirve nadie: el
    /// transporte que le entregaba sus gastos se borró y ningún escritor local puede voltearla al backend
    /// (`isBackendGroup` solo lo encienden el pull y el alta server-side, y ninguno alcanza una zona que el
    /// servidor no enumera). ⇒ lo que no está no es que «no haya llegado»: es que NO EXISTE, y el veredicto
    /// correcto es el que permite al usuario borrarlo.
    ///
    /// Negarlo —dejar las dos ramas en `false`, que era la dirección A2·(i)— deja dinero fantasma ATRAPADO:
    /// `bridgedPointerResolves = found || !isFresh` sale `true` con el fetch vacío ⇒ solo-lectura y
    /// Borrar/Duplicar desactivados, PARA SIEMPRE y sin auto-sanación, que es el bug de
    /// `qa_groups-tx-fantasma-al-borrar-gasto-de-grupo` reintroducido por la puerta de atrás.
    ///
    /// Mutación: devolver cualquier `Verdict` no-`.fresh` en esa rama deja este test en rojo.
    @Test func zoneWithoutChannel_isFresh_soTheUserCanDeleteWhatCanNeverArrive() {
        let e = evidence(backendChannel: false)
        #expect(GroupChannelFreshnessGate.evaluate(e) == .fresh)
        #expect(GroupChannelFreshnessGate.isFresh(e))
    }

    /// Las señales del canal backend son irrelevantes para una zona que no es suya, en las cuatro
    /// combinaciones: sin canal no hay nada que esperar, así que ninguna las puede volver no-fresca.
    @Test func zoneWithoutChannel_ignoresBackendSignals() {
        for pull in [true, false] {
            for cursor in [true, false] {
                let e = evidence(backendChannel: false, pullCompleted: pull, cursorListsZone: cursor)
                #expect(GroupChannelFreshnessGate.evaluate(e) == .fresh,
                        "pull=\(pull) cursor=\(cursor) cambió el veredicto de una zona sin canal")
            }
        }
    }

    // MARK: - Falla CERRADO donde todavía tiene que fallar cerrado

    /// La evidencia toda en `false` con la zona del canal BACKEND —lo que ve un device con el canal
    /// apagado— sigue sin conceder. Es la propiedad que separa «perder una limpieza» de «destruir una
    /// transacción», y es la que la inversión de arriba NO toca: solo se concede donde no hay canal al que
    /// esperar, nunca donde lo hay y está callado.
    @Test func backendZone_withNoEvidence_isNeverFresh() {
        #expect(GroupChannelFreshnessGate.isFresh(evidence(backendChannel: true)) == false)
    }

    /// Barrido exhaustivo de las 16 combinaciones: `.fresh` sale EXACTAMENTE en los dos caminos declarados
    /// —zona asentada del backend con pull agotado y cursor, o zona asentada sin canal— y en ningún otro.
    /// Un `guard` invertido, un `||` donde va un `&&`, o los dos primeros guards intercambiados, caen aquí.
    @Test func onlyTheTwoDeclaredPathsAreFresh() {
        for settled in [true, false] {
            for backendChannel in [true, false] {
                for pull in [true, false] {
                    for cursor in [true, false] {
                        let e = evidence(settled: settled, backendChannel: backendChannel,
                                         pullCompleted: pull, cursorListsZone: cursor)
                        let expected = settled && (backendChannel ? (pull && cursor) : true)
                        #expect(GroupChannelFreshnessGate.isFresh(e) == expected,
                                """
                                settled=\(settled) backend=\(backendChannel) pull=\(pull) \
                                cursor=\(cursor) → \(GroupChannelFreshnessGate.evaluate(e))
                                """)
                    }
                }
            }
        }
    }
}
