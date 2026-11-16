//
//  TopPrimaryActionUITests.swift
//  YalaUITests
//
//  El patrón del Panel en las demás páginas principales (card kzhe, Jürgen 2026-10-24): la acción principal es un
//  botón arriba, bajo la cabecera, y el «+» flotante solo sale cuando el scroll se lleva ese botón. Lo decide
//  `revealsFloatingActionWhenScrolledAway` (`Views/Shared/TopPrimaryAction.swift`).
//
//  Cada caso afirma las dos mitades: arriba, botón alcanzable y SIN flotante; tras bajar, flotante alcanzable. La
//  primera cae si el flotante vuelve a ser fijo; la segunda, si el botón de arriba se queda sin quien encienda el
//  flotante. Seed `realista` y Pro: hace falta contenido para desplazar y que el límite de presupuestos no salte.
//

import XCTest

final class TopPrimaryActionUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Baja hasta que `top` deja de verse y devuelve si `floating` llegó a ser alcanzable.
    private func scrollUntilFloatingShows(_ app: XCUIApplication, top: XCUIElement, floating: XCUIElement) -> Bool {
        var swipes = 0
        while !floating.isHittable && swipes < 10 {
            app.swipeUp()
            swipes += 1
        }
        return floating.waitForHittable(timeout: 5)
    }

    func test_budgets_newButtonOnTop_floatingOnlyAfterScrolling() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "realista", deeplink: "budgets")
        XCTAssertTrue(app.waitForUITestReady(timeout: 90), "uitest_ready ausente — bootstrap/seed no completó.")

        let top = app.buttons["budgets_create_button"]
        XCTAssertTrue(top.waitForExistence(timeout: 15), "Falta «Nuevo presupuesto» arriba (budgets_create_button).")
        XCTAssertTrue(top.waitForHittable(timeout: 5), "«Nuevo presupuesto» no es alcanzable arriba.")
        let floating = app.buttons["budgets_create_fab"]
        XCTAssertFalse(floating.exists, "Con «Nuevo presupuesto» a la vista, el «+» flotante sobra: volvió a ser fijo.")

        // Jürgen, 2026-10-28 (card ca00): el selector de tipo (Semanal / Mensual / Anual / Único) es la píldora de
        // calendario de las demás pantallas, en la MISMA fila que «Nuevo presupuesto» y a su derecha; arranca en Mensual.
        // Debajo, el navegador del período.
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "presupuestos-nuevo-arriba"
        shot.lifetime = .keepAlways
        add(shot)
        let picker = app.buttons["budgets_period_type_picker"]
        let period = app.descendants(matching: .any)["period_navigation_label"].firstMatch
        XCTAssertTrue(picker.exists && period.exists, "Control: el selector de tipo y el período se ven.")
        XCTAssertFalse(app.segmentedControls["budgets_period_type_picker"].exists,
                       "Volvió el segmento de cuatro opciones a lo ancho.")
        XCTAssertEqual(picker.frame.midY, top.frame.midY, accuracy: 2,
                       "El selector de tipo no está a la altura de «Nuevo presupuesto».")
        XCTAssertGreaterThan(picker.frame.minX, top.frame.maxX, "El selector de tipo va a la derecha de «Nuevo presupuesto».")
        XCTAssertLessThan(picker.frame.maxY, period.frame.minY, "El selector de tipo va encima del navegador del período.")
        XCTAssertEqual(picker.value as? String, "Mensual", "El selector de tipo no arranca en Mensual.")

        XCTAssertTrue(
            scrollUntilFloatingShows(app, top: top, floating: floating),
            "Al bajar, el «+» flotante de Presupuestos no apareció.")
    }

    /// Card 2m2r (2026-11-02): lo que la página oye con otra pestaña delante se ignora, y el flotante se queda como
    /// estaba al salir. Con la lista bajada, al volver tiene que seguir ahí. (Que no asome al volver con el botón de
    /// arriba a la vista dura 2-3 fotogramas y se midió en vídeo: un XCUITest no lo ve.)
    func test_budgets_returningWithTheListScrolled_keepsTheFloating() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "realista", deeplink: "budgets")
        XCTAssertTrue(app.waitForUITestReady(timeout: 90), "uitest_ready ausente — bootstrap/seed no completó.")

        let top = app.buttons["budgets_create_button"]
        XCTAssertTrue(top.waitForExistence(timeout: 15), "Falta «Nuevo presupuesto» arriba (budgets_create_button).")
        let floating = app.buttons["budgets_create_fab"]
        XCTAssertTrue(scrollUntilFloatingShows(app, top: top, floating: floating),
                      "Control: al bajar, el «+» flotante de Presupuestos no apareció.")
        // Un poco más abajo, para que nada de lo que sigue devuelva el botón de arriba al umbral.
        app.swipeUp()

        // Con la lista bajada la barra de pestañas del iPhone se encoge a la pestaña elegida y Panel no está en el árbol:
        // tocarla la despliega sin mover la lista. En el iPad no hay barra de abajo que encoger.
        app.selectTabExpandingCompactBar(.panel)
        XCTAssertTrue(floating.waitForNonExistence(timeout: 5), "Control: con el Panel delante, el «+» de Presupuestos sigue.")

        app.selectTabExpandingCompactBar(.planning)
        XCTAssertTrue(floating.waitForExistence(timeout: 5),
                      "Al volver a Presupuestos con la lista bajada, el «+» flotante ya no estaba.")
    }

    func test_statistics_actionsRowOnTop_floatingOnlyAfterScrolling() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "realista", deeplink: "statistics")
        XCTAssertTrue(app.waitForUITestReady(timeout: 90), "uitest_ready ausente — bootstrap/seed no completó.")

        let top = app.buttons["stats_action_new"]
        XCTAssertTrue(top.waitForExistence(timeout: 15), "Falta «Nuevo registro» bajo el hero (stats_action_new).")
        XCTAssertTrue(top.waitForHittable(timeout: 5), "«Nuevo registro» no es alcanzable bajo el hero.")
        let floating = app.buttons["fab_new_transaction"]
        XCTAssertFalse(floating.exists, "Con la fila a la vista, el «+» flotante sobra: volvió a ser fijo.")

        XCTAssertTrue(
            scrollUntilFloatingShows(app, top: top, floating: floating),
            "Al bajar, el «+» flotante de Estadísticas no apareció.")
    }

    // MARK: - Registros (página), card rtyu

    /// Registros desde Más (`-uitest-deeplink records`): fila arriba y sin flotante; al bajar, flotante; quieto abajo, se
    /// queda; al volver arriba, se va. Antes de la card rtyu la página no montaba el flotante nunca (97gc leído de más).
    func test_recordsPage_actionsRowOnTop_floatingOnlyAfterScrolling() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "realista", deeplink: "records")
        XCTAssertTrue(app.waitForUITestReady(timeout: 90), "uitest_ready ausente — bootstrap/seed no completó.")
        assertRecordsPageRevealsTheFloating(app, capturePrefix: "registros-desde-mas")
    }

    /// Registros como pestaña de la barra personalizada: la misma página, el mismo comportamiento.
    func test_recordsTab_fromTheCustomTabBar_floatingOnlyAfterScrolling() {
        let app = XCUIApplication()
        // Entre comillas de plist: sin ellas `{…}` llega como diccionario y `@AppStorage` lo ignora (testing.md).
        app.launchForUITest(pro: true, seed: "realista", extraArguments: [
            "-tabBarConfiguration", #""{\"activeTabs\":[\"panel\",\"records\",\"planning\"]}""#,
        ])
        XCTAssertTrue(app.waitForUITestReady(timeout: 90), "uitest_ready ausente — bootstrap/seed no completó.")
        let recordsTab = app.tabBars.buttons["Registros"].firstMatch
        XCTAssertTrue(recordsTab.waitForExistence(timeout: 15), "La barra personalizada no lleva la pestaña Registros.")
        recordsTab.tap()
        assertRecordsPageRevealsTheFloating(app, capturePrefix: "registros-pestana")
    }

    private func assertRecordsPageRevealsTheFloating(_ app: XCUIApplication, capturePrefix: String) {
        let top = app.buttons["stats_action_new"]
        XCTAssertTrue(top.waitForExistence(timeout: 15), "Falta «Nuevo registro» arriba en Registros (stats_action_new).")
        XCTAssertTrue(top.waitForHittable(timeout: 5), "«Nuevo registro» no es alcanzable arriba en Registros.")
        XCTAssertTrue(app.buttons.matching(identifier: "record_row").firstMatch.waitForExistence(timeout: 15),
                      "Control: Registros no tiene filas que desplazar.")
        let floating = app.buttons["fab_new_transaction"]
        XCTAssertFalse(floating.exists, "Con la fila a la vista, el «+» flotante sobra en Registros: volvió a ser fijo.")
        attach(app, "\(capturePrefix)-arriba")

        let shown = scrollUntilFloatingShows(app, top: top, floating: floating)
        attach(app, "\(capturePrefix)-abajo")
        XCTAssertTrue(shown, "Al bajar en Registros, el «+» flotante no apareció.")

        // Quieto abajo: el flotante se queda (no es un destello del desplazamiento).
        XCTAssertFalse(floating.waitForNonExistence(timeout: 3), "Con la lista quieta abajo, el «+» flotante se fue.")
        XCTAssertTrue(floating.isHittable, "Con la lista quieta abajo, el «+» flotante no es alcanzable.")

        // De vuelta arriba, se va.
        var swipes = 0
        while !top.isHittable && swipes < 12 {
            app.swipeDown()
            swipes += 1
        }
        XCTAssertTrue(top.waitForHittable(timeout: 5), "Control: no se pudo volver a la fila de arriba.")
        XCTAssertTrue(floating.waitForNonExistence(timeout: 5), "De vuelta arriba en Registros, el «+» flotante sigue.")
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
