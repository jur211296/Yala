//
//  AppleIDCloseNoticeUITests.swift
//  YalaUITests
//
//  La hoja «Cambiaste de cuenta de iCloud», por la vía real: la cola, la hoja y el coordinador de cierre.
//
//  **Qué cubre que ningún escáner alcanza** (ticket `apple-id-close-blocked-has-no-visible-outcome`):
//   1. Que la hoja se presenta DE VERDAD entrando por la cola, y que la red de presentación la deja en paz
//      mientras está en pantalla.
//   2. Que «Ahora no» suelta la CONDICIÓN VIVA y no solo la hoja: lo que esperaba en la cola presenta después.
//   3. Que si el cierre se bloquea la persona VE el motivo, y que al salir el coordinador queda en `.idle`:
//      Ajustes abre sin re-enseñar el aviso de bloqueo, y su «Cerrar sesión» abre la hoja de alcance.
//
//  **Lo que NO discrimina, medido con mutantes el 2026-09-15**: que la matriz retenga la cola MIENTRAS la hoja
//  está arriba. Con la condición viva fuera de la matriz, en este runtime la oferta de prueba espera igual y
//  presenta al cerrarse la hoja. Esa mitad la fijan `ContentViewReadinessLogicTests` y
//  `AppleIDCloseNoticeWiringTests`.
//
//  **Cómo se bloquea sin fingir nada.** `-uitest-groups-outbox-pending` deja cambios de grupos sin subir y
//  sin sesión: el estado REAL con el que el cierre privado se bloquea (`.sessionExpired`) antes de tocar
//  nada. Un seam que forzara `.blocked` en el coordinador dejaría ciego al test (`.claude/rules/testing.md`).
//
//  **Lo que NO cubre, a propósito.** Un cierre que termina bien: arma un boot-wipe REAL cuya key sobrevive a
//  `-uitest-reset`, y el arranque manual siguiente del simulador borraría el store. Tampoco la detección del
//  cambio de cuenta: el simulador no tiene cuentas de iCloud reales. Los dos son del device-QA
//  (`tickets/qa/device-qa-apple-id-change-closes-private-session.md`). Y lo que dura un parpadeo en la celda
//  C —la fase de progreso, un «Reintentar» que vuelve al mismo bloqueo en el mismo turno— lo fija
//  `AppleIDCloseNoticeWiringTests`, porque desde aquí no se distingue.
//

import XCTest

final class AppleIDCloseNoticeUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Los textos de la hoja llevan el identificador de su fase: va en la cabecera y no en el contenedor,
    /// para no pisar el de los botones.
    private func stage(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// Baja por Ajustes hasta que el botón sea alcanzable. Tope de intentos, sin sleeps (molde
    /// `SessionExitsPerCellUITests`).
    private func scrollTo(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        let element = app.buttons[identifier]
        var tries = 0
        while !element.isHittable && tries < 14 {
            app.swipeUp()
            tries += 1
        }
        return element
    }

    /// **Se lanza con la oferta de prueba en cola, y es el instrumento del test.** La oferta espera detrás del
    /// aviso, que es `.critical`, así que el orden de drenaje es determinista. Lo que discrimina es la espera
    /// del final: que la oferta presente al contestar la hoja prueba que el aviso soltó su condición viva y que
    /// la matriz se recalculó al soltarla.
    func test_notice_presentsThroughTheQueue_andLaterReleasesTheRouter() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "minimal", trialOffer: true, appleIDChanged: true)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap no completó.")

        let asking = stage(app, "apple_id_close_asking")
        XCTAssertTrue(asking.waitForExistence(timeout: 30), """
            La hoja del cambio de Apple ID no se presentó. El hook encola el intent tras el seed; si se drenó, \
            mira al dueño de la presentación (`AppleIDCloseNoticeModifier`).
            """)
        XCTAssertTrue(app.buttons["apple_id_close_confirm"].exists, "Falta «Cerrar sesión y quitarlos».")
        XCTAssertTrue(app.buttons["apple_id_close_later"].exists, "Falta «Ahora no».")

        // La red de presentación deja en paz una hoja que está en pantalla. Su cap de ciclo son unos 9 s, y
        // 12 s cubren la ventana. Si el `onAppear` del contenido dejara de disparar, la hoja se soltaría aquí.
        let desaparece = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: asking)
        XCTAssertEqual(XCTWaiter().wait(for: [desaparece], timeout: 12), .timedOut, """
            La red de presentación soltó una hoja que SÍ estaba en pantalla: el `onAppear` del contenido dejó de \
            probar la presentación en este runtime.
            """)

        app.buttons["apple_id_close_later"].tap()
        XCTAssertTrue(asking.waitForNonExistence(timeout: 10), "La hoja no se cerró con «Ahora no».")
        // **Y el router vuelve a drenar**: la oferta llevaba toda la sesión en la cola. Sin soltar la condición
        // viva, o sin recalcular la matriz al soltarla, esto no aparece nunca. 45 s porque espera al desmontaje.
        XCTAssertTrue(app.buttons["trial_offer_dismiss"].waitForExistence(timeout: 45), """
            Lo retenido no presentó al contestar la hoja: la condición viva (`appleIDCloseNotice`) se quedó \
            puesta, o la matriz no se recalculó al soltarla, y el router sigue retenido.
            """)
    }

    func test_blockedClose_showsTheReason_canRetry_andLeavesTheCoordinatorFree() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "minimal", appleIDChanged: true, groupsOutboxPending: true)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap no completó.")

        XCTAssertTrue(stage(app, "apple_id_close_asking").waitForExistence(timeout: 30), """
            La hoja no se presentó. Con el seam del outbox, la app solo la encola si la fila sembrada existe: si \
            falta, mira `DevSeedGroups.seedPendingOutboxRow` antes que la hoja.
            """)
        app.buttons["apple_id_close_confirm"].tap()

        // **El motivo, a la vista.** Antes de este ticket el alert se cerraba y no se veía nada. El
        // identificador sale del mismo motivo que el texto, así que esto es también el copy de la sesión caducada.
        let blocked = stage(app, "apple_id_close_blocked_session-expired")
        XCTAssertTrue(blocked.waitForExistence(timeout: 15), """
            El cierre bloqueado no enseñó su motivo. Si lo que aparece es la pantalla de reiniciar, el cierre \
            TERMINÓ: la fila de outbox no bloqueó y el simulador tiene un boot-wipe armado — `simctl erase` \
            antes de volver a abrir Yala Dev a mano.
            """)
        XCTAssertTrue(app.buttons["apple_id_close_retry"].exists, "El bloqueo no ofrece «Reintentar».")
        XCTAssertTrue(app.buttons["apple_id_close_later"].exists, "El bloqueo no ofrece «Ahora no».")

        // «Reintentar» vuelve a pedir el cierre y, con la fila todavía ahí, vuelve al mismo motivo. Que el botón
        // haga algo no se ve desde aquí —la celda C se bloquea en el mismo turno—: lo fija el escáner.
        app.buttons["apple_id_close_retry"].tap()
        XCTAssertTrue(blocked.waitForExistence(timeout: 15), "Tras «Reintentar» la hoja no volvió al motivo.")

        app.buttons["apple_id_close_later"].tap()
        // La hoja congela lo que enseñaba mientras se retira, así que esperar a que desaparezcan el motivo y el
        // botón es esperar al desmontaje de verdad, y no a un cambio de contenido.
        XCTAssertTrue(blocked.waitForNonExistence(timeout: 10), "La hoja no se cerró con «Ahora no».")
        XCTAssertTrue(app.buttons["apple_id_close_later"].waitForNonExistence(timeout: 10),
                      "«Ahora no» sigue en pantalla: la hoja no terminó de irse.")

        // **El coordinador no quedó tapiado, y se mira ANTES de tocar nada en Ajustes.** Con la fase bloqueada,
        // Ajustes re-enseña al abrirse el aviso «No pudimos cerrar tu sesión» (`ProfileView.onAppear`). Al primer
        // tap, el manejador de interrupciones de XCTest cierra ese aviso con su «OK» —que reconoce el bloqueo— y
        // la hoja de alcance se abre igual. Medido el 2026-09-15: con «Ahora no» sin reconocer el bloqueo, este
        // test salía VERDE hasta añadir la aserción de abajo.
        app.openProfile()
        XCTAssertFalse(app.alerts.firstMatch.waitForExistence(timeout: 4), """
            Ajustes abrió enseñando un aviso: el coordinador sigue en `.blocked` tras salir de la hoja del cambio \
            de Apple ID. Es el tapiado del ticket.
            """)
        scrollTo(app, "profile_security_signout").tap()
        let scopeSheet = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "destructive_scope_sheet_"))
            .firstMatch
        XCTAssertTrue(scopeSheet.waitForExistence(timeout: 10), """
            «Cerrar sesión» no abrió su hoja de alcance: el coordinador no está libre tras salir de la hoja del \
            cambio de Apple ID.
            """)
        app.buttons["destructive_scope_cancel"].tap()
    }
}
