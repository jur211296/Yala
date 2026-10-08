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
//   4. El DESARME de la red: si la hoja no llega a montarse, la red agota su cap, suelta la condición viva y lo
//      retenido presenta (ticket `presentation-net-desarm-has-no-automated-net`). Ese caso entra por un seam
//      propio, `-uitest-apple-id-close-never-mounts`; los demás corren sin él.
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

    /// La frase de los grupos (`icloud.appleIDChanged.groupsLine`, en es). Va dentro del mensaje de la pregunta, así que
    /// se busca por su texto y no por identificador: el de la cabecera pisa el de sus hijos.
    private func groupsLine(_ app: XCUIApplication) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "También se quitan los grupos que hay en este teléfono"))
            .firstMatch
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
        // Sin grupos en el teléfono el cierre no se lleva ninguno, y la pregunta no puede decir que sí.
        XCTAssertFalse(groupsLine(app).exists, "La pregunta afirma que se van los grupos de un teléfono que no tiene.")

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

    /// **El DESARME: si la hoja no llega a montarse, la red agota su cap y suelta la condición viva** (ticket
    /// `presentation-net-desarm-has-no-automated-net`). Sin esto, una hoja que UIKit descarta deja la matriz de
    /// readiness retenida por `appleIDCloseNotice` el resto de la sesión: ni bandeja, ni ofertas, ni invitaciones.
    ///
    /// `-uitest-apple-id-close-never-mounts` enciende la condición viva y deja la hoja sin montar en el armado y en
    /// cada reintento; la red, la tabla de `AppleIDCloseNoticeLogic` y el desarme son los de producción. Este caso
    /// NO sustituye al de la presentación normal de arriba, que corre sin el seam (regla `L103` de `testing.md`).
    ///
    /// Se afirman las dos consecuencias, y las dos con su control:
    ///  · **mientras la red reintenta, lo retenido espera** — la oferta no está a los 4 s. Si la matriz colgara del
    ///    `showSheet` en vez de la condición viva, con la hoja sin montar la oferta saldría al instante;
    ///  · **al agotarse, la condición viva se suelta** — la oferta presenta sin que nadie conteste nada. Medido el
    ///    2026-10-07: la red suelta a los ~9,4 s del drenaje; sin el desarme, la oferta no sale nunca.
    func test_sheetThatNeverMounts_netExhausts_andReleasesTheRouter() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "minimal", trialOffer: true, appleIDChanged: true, appleIDCloseNeverMounts: true)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap no completó.")

        let asking = stage(app, "apple_id_close_asking")
        let offer = app.buttons["trial_offer_dismiss"]
        let offerAppears = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true"), object: offer)
        XCTAssertEqual(XCTWaiter().wait(for: [offerAppears], timeout: 4), .timedOut, """
            La oferta de prueba presentó mientras la red de la hoja seguía reintentando: la matriz no está retenida \
            por la condición viva (`appleIDCloseNotice`), o el seam dejó de encenderla.
            """)
        XCTAssertFalse(asking.exists, """
            La hoja se montó con `-uitest-apple-id-close-never-mounts`: el seam no alcanza a quien la enciende y este \
            caso no está midiendo el desarme.
            """)

        // 45 s como en el caso de arriba: el cap son ~9 s, y lo demás es el desmontaje y el drenaje siguiente.
        XCTAssertTrue(offer.waitForExistence(timeout: 45), """
            Lo retenido no presentó tras agotarse la red: el desarme no soltó la condición viva y el router se \
            quedó retenido por una hoja que nunca se vio — el brick que esta red existe para impedir.
            """)
        XCTAssertFalse(asking.exists, "La hoja apareció a la vez que la oferta: el aviso se soltó y siguió montándose.")

        // Y la app sigue viva: nada quedó pegado por encima, y el aviso soltado no vuelve.
        offer.tap()
        XCTAssertTrue(app.buttons["panel_inbox_button"].waitForExistence(timeout: 10),
                      "El Panel no quedó accesible tras el desarme y la oferta.")
        XCTAssertFalse(asking.exists, "El aviso soltado por la red volvió a presentarse.")
    }

    /// **Sin sesión y con cambios de grupos, el aviso ofrece perderlos y «Ahora no» no pierde nada** (ticket
    /// `groups-outbox-rows-without-a-live-session-have-no-exit`, 2026-09-28). Hasta ese día este bloqueo era «Tu sesión
    /// caducó» con «Reintentar», y quien no podía volver a entrar no tenía salida. **El botón destructivo no se toca aquí**:
    /// terminaría el cierre y armaría un boot-wipe REAL en el simulador (ver la cabecera). Que aceptar deje seguir el cierre
    /// lo fija `GroupsNoSessionLossExitTests`, sin armar nada.
    func test_blockedClose_offersTheLoss_notNowKeepsEverything_andLeavesTheCoordinatorFree() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "minimal", appleIDChanged: true, groupsOutboxPending: true)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap no completó.")

        XCTAssertTrue(stage(app, "apple_id_close_asking").waitForExistence(timeout: 30), """
            La hoja no se presentó. Con el seam del outbox, la app solo la encola si la fila sembrada existe: si \
            falta, mira `DevSeedGroups.seedPendingOutboxRow` antes que la hoja.
            """)
        app.buttons["apple_id_close_confirm"].tap()

        // **La pérdida, a la vista, con su cifra.** El identificador es el de la etapa que la ofrece; el texto sale del
        // motivo (la sesión que no está) y cuenta la fila sembrada.
        let blocked = stage(app, "apple_id_close_losing_group_changes")
        XCTAssertTrue(blocked.waitForExistence(timeout: 15), """
            El cierre bloqueado no ofreció perder los cambios de grupos. Si lo que aparece es la pantalla de reiniciar, \
            el cierre TERMINÓ: la fila de outbox no bloqueó y el simulador tiene un boot-wipe armado — `simctl erase` \
            antes de volver a abrir Yala Dev a mano.
            """)
        let cifra = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "sin subir: 1")).firstMatch
        XCTAssertTrue(cifra.exists, "El aviso no cuenta los cambios que se perderían.")
        XCTAssertTrue(app.buttons["apple_id_close_discard_groups"].exists, "El aviso no ofrece «Cerrar sesión y perderlos».")
        XCTAssertTrue(app.buttons["apple_id_close_later"].exists, "El aviso no ofrece «Ahora no».")

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

    /// **Con grupos del canal nuevo en el teléfono, la pregunta dice que el cierre también se los lleva** (ticket
    /// `apple-id-close-notice-does-not-say-what-else-the-close-does`). `seed: grupos` deja grupos del backend sin sesión
    /// en la nube: la celda C cuyo cierre borra el store de grupos (`CloudSignOutFlowLogic.wipeForgetsGroups`). La D no
    /// se alcanza desde aquí —pide una sesión de grupos viva— y la fija la tabla de `AppleIDCloseNoticeGroupsLineTests`.
    /// **No se confirma**: terminaría el cierre y armaría un boot-wipe REAL (ver la cabecera).
    func test_question_saysTheGroupsLeaveThePhone_whenTheCloseTakesThem() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "grupos", appleIDChanged: true)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap no completó.")

        let asking = stage(app, "apple_id_close_asking")
        XCTAssertTrue(asking.waitForExistence(timeout: 30), "La hoja del cambio de Apple ID no se presentó.")
        XCTAssertTrue(groupsLine(app).exists, """
            La pregunta no avisa de que el cierre se lleva los grupos de este teléfono, y con estos grupos sí se los lleva.
            """)

        app.buttons["apple_id_close_later"].tap()
        XCTAssertTrue(asking.waitForNonExistence(timeout: 10), "La hoja no se cerró con «Ahora no».")
    }
}
