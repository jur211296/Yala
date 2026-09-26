//
//  GroupsAssociationRowUITests.swift
//  YalaUITests
//
//  Paso 10 del rediseño de sesiones (ADR 2026-09-09 «Sesiones — dos ejes» §4): la cuenta que una sesión
//  privada usa para Grupos **se ve, se deshace y se rehace** en Ajustes → «¿Dónde viven tus datos?».
//
//  Lo que esta suite prueba y ninguna tabla unitaria puede: que la sección **se monta de verdad dentro de
//  esa pantalla**. La tabla de estados (`GroupsAssociationLogicTests`) dice qué debería pintar cada celda,
//  pero con la sección colgada de una rama del `switch` que nadie recorre, o con la fila de Ajustes
//  gateada fuera, esa tabla sigue verde y el gesto no existe para nadie.
//
//  Celdas alcanzables en el simulador con los seams que ya existen, las mismas que `SessionExitsPerCell`:
//   - **sin cuenta**: el arranque por defecto (sesión privada, sin sesión en la nube).
//   - **asociada**: `-uitest-fake-cloud-session`, que finge el predicado GLOBAL de sesión.
//   - **solo grupos (F)**: el mismo seam + `-uitest-group-invite` — ahí la sección NO aplica.
//  Las otras dos —nube completa, y asociada SIN sesión viva (el segundo móvil)— no tienen seam: la
//  primera necesita `storageMode == .cloud` y la segunda una asociación sembrada en el iCloud-KV. Las
//  cubre la tabla unitaria, y el recorrido real, el device-QA.
//
//  **Uno de los casos SÍ confirma el desasociar, y el «no se puede» de esta cabecera estaba mal.** Decía
//  que confirmarlo dejaría al coordinador «intentando subir un outbox contra un backend que no existe»;
//  medido el 2026-09-11, no sube nada: `pushAllPendingGroupsForSignOut` corta en su pre-check
//  (`liveGroupsPendingCount == 0 → .drained`) **sin una sola petición**, y con estos seeds el outbox está
//  vacío. `CloudAuthService.signOut()` sale además por su primer `guard` sin cliente. El resto del camino
//  es local. Los dos casos que solo leen la hoja se quedan como estaban: ahí lo que se prueba es el copy
//  de las dos salidas, y confirmar no aporta.
//

import XCTest

final class GroupsAssociationRowUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Baja por Ajustes hasta que el elemento sea alcanzable. Determinista: tope de intentos, sin sleeps.
    private func scrollTo(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        let element = app.buttons[identifier]
        var tries = 0
        while !element.isHittable && tries < 14 {
            app.swipeUp()
            tries += 1
        }
        return element
    }

    /// Abre Ajustes → «¿Dónde viven tus datos?» y espera a que la pantalla monte.
    ///
    /// La fila está gateada por `StorageRowGateLogic.isVisible`, así que **que exista ya es parte de lo
    /// que se prueba**: si algún día el gate la cerrara para una sesión privada, el gesto de desasociar se
    /// quedaría sin ninguna superficie y esta suite lo diría aquí.
    private func openStorageScreen(_ app: XCUIApplication) {
        let row = scrollTo(app, "storage_settings_row")
        XCTAssertTrue(row.waitForExistence(timeout: 5), """
            No aparece la fila «¿Dónde viven tus datos?» en Ajustes. Es la ÚNICA superficie desde la que se
            puede soltar la cuenta de grupos: sin ella, quien la tenga asociada no puede desasociarla.
            """)
        row.tap()
        // Por `descendants(matching: .any)` y no por `otherElements`: el tipo con el que SwiftUI publica
        // una card depende de lo que lleve dentro, y un `XCUIElementQuery` acotado al tipo equivocado da
        // un rojo mudo que parece «la pantalla no montó». Medido aquí mismo.
        XCTAssertTrue(
            app.descendants(matching: .any)["storage_status_card"].waitForExistence(timeout: 5),
            "La pantalla de almacenamiento no montó.")
    }

    /// El TÍTULO de la sección, que es donde vive el identifier: puesto en el contenedor pisaría el de
    /// los botones y estos dejarían de existir con su id propio en el árbol de accesibilidad.
    private func section(_ app: XCUIApplication) -> XCUIElement {
        app.staticTexts["storage_groups_section"]
    }

    // MARK: - Sesión privada SIN cuenta de grupos

    func test_privateWithoutAccount_offersAssociate_andNoDetach() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "minimal")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap no completó.")
        app.openProfile()
        openStorageScreen(app)

        XCTAssertTrue(section(app).waitForExistence(timeout: 5),
                      "La sección «Grupos» no se monta en la pantalla de almacenamiento.")
        XCTAssertTrue(scrollTo(app, "storage_groups_associate_button").waitForExistence(timeout: 5),
                      "Sin cuenta asociada, la sección tiene que ofrecer asociar una.")
        XCTAssertFalse(app.buttons["storage_groups_detach_button"].exists, """
            Se ofrece «Desasociar» sin ninguna cuenta asociada.
            """)
    }

    // MARK: - Sesión privada CON cuenta de grupos (el «equipo»)

    func test_privateWithGroupsSession_offersDetach_withBothOutcomes() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "minimal", cloudSession: true)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap no completó.")
        app.openProfile()
        openStorageScreen(app)

        XCTAssertTrue(section(app).waitForExistence(timeout: 5), "La sección «Grupos» no se monta.")
        // Decisión de Jürgen (2026-09-09): mientras haya una asociada, la fila SOLO ofrece desasociar. No
        // existe un «Cambiar cuenta» que haga las dos cosas de un gesto.
        XCTAssertFalse(app.buttons["storage_groups_associate_button"].exists, """
            Con una cuenta ya asociada se sigue ofreciendo asociar otra: para cambiar de cuenta hay que
            desasociar primero.
            """)

        let detach = scrollTo(app, "storage_groups_detach_button")
        XCTAssertTrue(detach.waitForExistence(timeout: 5), "Falta «Desasociar».")
        detach.tap()

        // **Las DOS salidas, en la misma hoja.** Es la decisión de Jürgen que deroga el «se quedan
        // siempre» del ticket: conservar los gastos que pagó, o quitarlo todo. Se afirma que existen las
        // dos: una hoja con una sola salida sería la decisión anterior del ticket, en silencio.
        // `.firstMatch` porque el `confirmationDialog` de SwiftUI publica sus botones DOS veces en el
        // árbol de accesibilidad (medido): una consulta sin acotar falla con «Multiple matching elements»
        // en cuanto se le pide una propiedad, no al buscarlos.
        let keep = app.buttons.matching(identifier: "storage_groups_detach_keep").firstMatch
        let remove = app.buttons.matching(identifier: "storage_groups_detach_remove").firstMatch
        XCTAssertTrue(keep.waitForExistence(timeout: 5), "La confirmación no ofrece conservar.")
        XCTAssertTrue(remove.exists, "La confirmación no ofrece quitar.")
        XCTAssertNotEqual(keep.label, remove.label, """
            Las dos salidas comparten texto: quien las lea no puede distinguir qué elige.
            """)

        // **El botón de cancelar no se toca, y no es un descuido.** Medido en el árbol de accesibilidad:
        // SwiftUI NO propaga el `accessibilityIdentifier` al botón `role: .cancel` de un
        // `confirmationDialog` —los otros dos sí salen con el suyo—, así que la única forma de tocarlo
        // sería por su texto localizado, que es justo lo que este repo prohíbe. El diálogo se queda
        // abierto al terminar el caso, que es inocuo: nada se confirma y la app muere con el test.
    }


    // MARK: - El borrado local falla: la app lo dice y no finge que soltó la cuenta

    /// **Los botones de un `.alert` se tocan por POSICIÓN, no por identifier.** SwiftUI no propaga el
    /// `accessibilityIdentifier` a los botones del closure de un `.alert` —llegan al árbol con el id
    /// vacío, medido el 2026-09-04 en `docs/aprendizajes-tecnicos.md`— así que un `exists` por id sale
    /// `false` SIEMPRE. Es el molde de `WelcomeFreshStartAlertUITests`, que llega al alert hermano así.
    ///
    /// El aviso tiene dos botones y `.cancel` va el último ⇒ `boundBy: 0` es «Reintentar» y `1` es
    /// «Más tarde».
    private func alertButton(_ app: XCUIApplication, _ index: Int) -> XCUIElement {
        app.alerts.buttons.element(boundBy: index)
    }

    /// Ticket `detach-failure-looks-like-success`. Hasta el 2026-09-11 este camino era MUDO: el borrado
    /// lanzaba, la app seguía a `clear()` y la pantalla decía que ya no había cuenta asociada **con los
    /// grupos enteros en el teléfono**.
    ///
    /// Es el único test que confirma el gesto, y es el que da sentido al seam: `-uitest-fail-wipe` hace
    /// lanzar a `DataWipeService.deleteLocalGroupsRows` **antes de tocar nada**, así que lo que se
    /// reproduce es exactamente el estado del ticket —todo sigue ahí— y no un borrado a medias.
    ///
    /// **Se confirma por «conservar» y no por «quitar»** a propósito: la salida que no destruye nada. Si
    /// el seam dejara de morder algún día, este caso tocaría un botón que borra transacciones reales.
    func test_detachWithFailingWipe_showsFailureAlert() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "minimal", cloudSession: true, extraArguments: ["-uitest-fail-wipe"])
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap no completó.")
        app.openProfile()
        openStorageScreen(app)

        let detach = scrollTo(app, "storage_groups_detach_button")
        XCTAssertTrue(detach.waitForExistence(timeout: 5), "Falta «Desasociar».")
        detach.tap()

        // `.firstMatch`: el `confirmationDialog` de SwiftUI publica sus botones DOS veces en el árbol.
        let keep = app.buttons.matching(identifier: "storage_groups_detach_keep").firstMatch
        XCTAssertTrue(keep.waitForExistence(timeout: 5), "La confirmación no ofrece conservar.")
        keep.tap()

        // El aviso PROPIO de este fallo. Espera generosa: entre el tap y el aviso corren el gate de
        // quiescencia del store personal y el teardown del canal.
        let retry = alertButton(app, 0)
        XCTAssertTrue(retry.waitForExistence(timeout: 45), """
            El borrado local falló y la app no dijo nada. Es el defecto entero del ticket: la pantalla se \
            queda afirmando que soltó la cuenta mientras los grupos siguen en el teléfono.
            """)
        XCTAssertEqual(app.alerts.buttons.count, 2, """
            El aviso no tiene los dos botones que se esperan (reintentar / más tarde): la navegación por \
            posición de este test estaría tocando otra cosa.
            """)

        // «Más tarde» — la salida sin reintentar ahora.
        alertButton(app, 1).tap()

        // La pantalla sigue en pie tras cerrar el aviso, con la sección montada. No se afirma que
        // «Desasociar» siga: con `-uitest-fake-cloud-session` la celda es `.associated` mire lo que mire
        // la asociación, así que ese botón estaría igual con el bug puesto — sería una aserción que no
        // puede fallar.
        XCTAssertTrue(section(app).waitForExistence(timeout: 5),
                      "Tras cerrar el aviso no queda nada debajo: la sección se desmontó.")

        // **Lo que NO se puede comprobar aquí, y su motivo está medido (2026-09-11).** El botón
        // «Terminar de soltar la cuenta» cuelga de `GroupsDetachPendingPurge`, que va SELLADA con el
        // `sub` de la cuenta — y el seam de sesión fingida **no siembra ninguna asociación ni propaga el
        // `sub`** (`CloudAuthService.currentUserID` sigue `nil`, y su docblock dice por qué: fingirlo
        // volvería alcanzables los resolvedores de identidad del canal con una identidad que no existe).
        // Sin `sub` la marca no se arma, por diseño: una marca sin sello no sabría a qué cuenta pertenece
        // lo pendiente. Ese estado necesita un seam que siembre la asociación —el mismo que le falta a la
        // celda «asociada sin sesión viva» de la cabecera— y tiene ticket:
        // `uitest-seam-for-a-seeded-groups-association`. Lo cubren mientras tanto los 14 casos de
        // `YalaTests/CloudSync/GroupsDetachPurgeFailureTests` y el device-QA.
    }

    /// **Control del seam, y sin él el caso de arriba no discrimina.** Si el aviso saliera SIEMPRE —por
    /// un binding pegado, o porque el veredicto se leyera mal— aquel test seguiría verde sin probar nada.
    /// Es la regla de `.claude/rules/testing.md` L99: el seam cubre el flujo, no la decisión, así que la
    /// decisión se mide en un lanzamiento SIN el seam.
    func test_detachWithoutFailingWipe_showsNoFailureAlert() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "minimal", cloudSession: true)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap no completó.")
        app.openProfile()
        openStorageScreen(app)

        let detach = scrollTo(app, "storage_groups_detach_button")
        XCTAssertTrue(detach.waitForExistence(timeout: 5), "Falta «Desasociar».")
        detach.tap()

        let keep = app.buttons.matching(identifier: "storage_groups_detach_keep").firstMatch
        XCTAssertTrue(keep.waitForExistence(timeout: 5), "La confirmación no ofrece conservar.")
        keep.tap()

        // Control POSITIVO de que el gesto terminó: sin él, la ausencia del aviso se cumpliría también
        // con el desasociar colgado en su spinner, que es otra cosa.
        let working = app.descendants(matching: .any)["storage_groups_working"]
        XCTAssertTrue(
            working.waitForNonExistence(timeout: 60),
            "El desasociar se quedó en «Desasociando…»: la ausencia del aviso no probaría nada.")

        // Aquí SÍ se mira el botón de terminar por identifier: vive en la sección, no en un alert, así
        // que su id sí llega al árbol — y su ausencia es la afirmación honesta de «no quedó nada a medias».
        XCTAssertFalse(app.buttons["storage_groups_detach_finish_button"].exists, """
            Con el borrado en VERDE la sección ofrece terminar un desasociar a medias: la marca durable \
            se arma en un camino que no es el del fallo, y el caso del seam mide un botón que sale siempre.
            """)
        XCTAssertEqual(app.alerts.count, 0, "Salió un alert con el borrado en verde.")
    }

    /// Ticket `detach-does-not-verify-the-cloud-session-actually-closed`. Si la sesión en la nube sobrevive a su cierre, el
    /// gesto tiene que PARARSE antes de soltar nada y decirlo. Hasta el 2026-09-26 seguía: borraba los grupos y la
    /// asociación, y en el siguiente primer plano el loop arrancaba con esa sesión y volvía a bajarlo todo, re-puenteado al
    /// lado de lo que la persona eligió conservar.
    ///
    /// `-uitest-sign-out-keeps-session` solo cambia lo que `CloudAuthService.signOut()` DEVUELVE. El control es
    /// `test_detachWithoutFailingWipe_showsNoFailureAlert`: el mismo gesto sin el seam termina sin ningún aviso.
    /// Se confirma por «conservar» por lo mismo que en el caso del borrado fallido.
    func test_detachWhenTheSessionSurvivesSignOut_stopsAndSaysSo() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "minimal", cloudSession: true, signOutKeepsSession: true)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap no completó.")
        app.openProfile()
        openStorageScreen(app)

        let detach = scrollTo(app, "storage_groups_detach_button")
        XCTAssertTrue(detach.waitForExistence(timeout: 5), "Falta «Desasociar».")
        detach.tap()

        let keep = app.buttons.matching(identifier: "storage_groups_detach_keep").firstMatch
        XCTAssertTrue(keep.waitForExistence(timeout: 5), "La confirmación no ofrece conservar.")
        keep.tap()

        // El aviso del bloqueo, con UN botón: el del borrado fallido lleva dos y no es este caso.
        let ok = alertButton(app, 0)
        XCTAssertTrue(ok.waitForExistence(timeout: 45), """
            La sesión sobrevivió a su cierre y el desasociar no dijo nada: o siguió hasta el final —el defecto del \
            ticket— o se paró en silencio.
            """)
        XCTAssertEqual(app.alerts.buttons.count, 1, """
            El aviso no es el del bloqueo (un botón). Con dos es el del borrado fallido: el gesto cruzó el punto de no \
            retorno con la sesión viva.
            """)
        let message = app.alerts.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "cerrar la sesión de tu cuenta de grupos")).firstMatch
        XCTAssertTrue(message.exists, """
            El aviso no dice que la sesión no se cerró: el motivo `.sessionNotClosed` no llegó a la pantalla, o llegó con \
            el texto de otro bloqueo.
            """)

        ok.tap()
        XCTAssertTrue(section(app).waitForExistence(timeout: 5),
                      "Tras cerrar el aviso no queda nada debajo: la sección se desmontó.")
        // No se afirma la ausencia de «Terminar de soltar la cuenta»: con la sesión fingida la marca no se arma nunca (no
        // hay `sub`), así que sería una aserción que no puede fallar. Ver el caso del borrado fallido.
    }

    // MARK: - Solo grupos (F): la sección no aplica

    /// Sin sesión privada no hay nada a lo que ligar una cuenta, así que la sección no existe. Es una
    /// aserción NEGATIVA, y por eso va acompañada del control positivo de que la pantalla sí montó: sin
    /// él se cumpliría igual con la fila de Ajustes cerrada, que es otra cosa.
    func test_groupsOnly_sectionDoesNotApply() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "solo-grupos", groupInvite: true, cloudSession: true)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        app.openProfile()
        openStorageScreen(app)

        XCTAssertFalse(section(app).exists, """
            La sección «Grupos» se pinta en una sesión solo-grupos, donde no hay sesión privada a la que
            asociar nada: ahí la cuenta de la nube ES la sesión, y soltarla es «Cerrar sesión».
            """)
    }
}
