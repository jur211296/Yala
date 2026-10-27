//
//  UsageModeUITests.swift
//  YalaUITests
//
//  «Cómo usas Yala» (card p0iu, decisiones de Jürgen del 2026-10-26): de Yala completo a solo grupos y vuelta, sin
//  perder datos ni repetir la bienvenida. Los tres desenlaces de la vuelta —sin registros, seguir donde lo dejé y
//  empezar de cero— van cada uno en su caso, con capturas adjuntas (`usageMode-*`). Scheme `Yala Dev`.
//

import XCTest

final class UsageModeUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    // MARK: - Pasos comunes

    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "usageMode-\(name)"
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// Baja por Ajustes hasta que el elemento sea alcanzable. Tope de intentos, sin sleeps.
    private func scrollTo(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        let element = app.buttons[identifier].firstMatch
        var tries = 0
        while !(element.exists && element.isHittable) && tries < 14 {
            app.swipeUp()
            tries += 1
        }
        return element
    }

    private func waitUntilGone(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: element)
        return XCTWaiter().wait(for: [gone], timeout: timeout) == .completed
    }

    /// La bandeja de la barra del Panel: solo existe con el Panel montado (en solo grupos no hay Panel).
    private func panelMarker(_ app: XCUIApplication) -> XCUIElement { app.buttons["panel_inbox_button"] }

    /// Ajustes › Preferencias › «Cómo usas Yala» › «Solo grupos» › «Usar solo grupos». Deja la shell reducida a Grupos.
    private func goGroupsOnly(_ app: XCUIApplication) {
        XCTAssertTrue(panelMarker(app).waitForExistence(timeout: 15), "Control: el Panel no estaba montado al empezar.")
        app.openProfile()
        let row = scrollTo(app, "profile_usage_mode")
        XCTAssertTrue(row.waitForExistence(timeout: 10), "No está la fila «Cómo usas Yala» en Preferencias.")
        XCTAssertTrue(row.label.contains("Yala completo"), "El subtítulo de la fila no dice el modo de ahora: \(row.label)")
        attach(app, "1-fila")
        row.tap()

        let groupsOnly = app.buttons["usage_mode_groups_only"]
        XCTAssertTrue(groupsOnly.waitForExistence(timeout: 10), "La pantalla «Cómo usas Yala» no enseñó «Solo grupos».")
        XCTAssertTrue(app.buttons["usage_mode_full"].exists, "La pantalla no enseñó «Yala completo».")
        attach(app, "2-pantalla")
        groupsOnly.tap()

        let confirm = app.buttons["usage_mode_leave_confirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 10), "No salió la hoja «¿Usar Yala solo para grupos?».")
        XCTAssertTrue(app.staticTexts["Se pausan tus recordatorios y pagos programados."].exists,
                      "La hoja no avisa de la pausa de recordatorios y pagos programados.")
        attach(app, "3-ida")
        confirm.tap()

        // La shell se reduce: el Panel se desmonta (con su bandeja) y Ajustes ofrece volver.
        XCTAssertTrue(waitUntilGone(panelMarker(app), timeout: 15),
                      "Tras «Usar solo grupos» el Panel sigue en pantalla.")
    }

    /// Desde la shell de solo grupos, el botón destacado de Ajustes dice «Volver a Yala completo» y lo pide.
    private func tapComeBack(_ app: XCUIApplication) {
        app.openProfile()
        let comeBack = app.buttons["profile_activate_full_yala"]
        XCTAssertTrue(comeBack.waitForExistence(timeout: 10), "En solo grupos no está el botón destacado de Ajustes.")
        XCTAssertTrue(comeBack.label.contains("Volver a Yala completo"), """
            Quien ya tuvo Yala completo ve «\(comeBack.label)» en vez de «Volver a Yala completo».
            """)
        XCTAssertTrue(comeBack.label.contains("Tus cuentas y registros te esperan"))
        attach(app, "4-solo-grupos-ajustes")
        comeBack.tap()
    }

    // MARK: - Casos

    /// Con registros: la hoja pregunta, «Seguir donde lo dejé» va marcado y devuelve todo, sin bienvenida.
    func test_withRecords_keepEverything_bringsTheDataBack() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "minimal")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        XCTAssertTrue(app.staticTexts["Bus"].firstMatch.waitForExistence(timeout: 15),
                      "Control: el Panel no enseñó los registros sembrados.")

        goGroupsOnly(app)
        tapComeBack(app)

        let title = app.staticTexts["usage_mode_return_title"]
        XCTAssertTrue(title.waitForExistence(timeout: 15), "Con registros guardados la vuelta no preguntó nada.")
        XCTAssertTrue(title.label.hasPrefix("Tienes "), "El título no cuenta los registros: \(title.label)")
        XCTAssertTrue(app.buttons["usage_mode_return_keep"].isSelected, "«Seguir donde lo dejé» no va marcado por defecto.")
        XCTAssertTrue(app.buttons["usage_mode_return_export"].exists, "La hoja no ofrece «Exportar una copia antes».")
        attach(app, "5-vuelta-pregunta")
        app.buttons["usage_mode_return_continue"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["positive_toast"].waitForExistence(timeout: 10),
                      "No salió el aviso «Ya tienes Yala completo de nuevo».")
        XCTAssertTrue(panelMarker(app).waitForExistence(timeout: 10), "La vuelta no llevó al Panel.")
        XCTAssertTrue(app.staticTexts["Bus"].firstMatch.waitForExistence(timeout: 10),
                      "Los registros no volvieron tras «Seguir donde lo dejé».")
        XCTAssertFalse(app.buttons["onboarding_next_button"].exists, "La vuelta repitió la bienvenida.")
        attach(app, "6-vuelta-panel")
    }

    /// «Empezar de cero»: segunda confirmación con el recuento, después solo la cuenta principal con lo de antes, y el
    /// Panel sin los registros viejos. Discrimina: el control ve «Bus» antes; con el borrado roto seguiría ahí.
    func test_startFresh_confirmsTwice_asksOnlyForTheMainAccount_andErasesTheRecords() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "minimal")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        XCTAssertTrue(app.staticTexts["Bus"].firstMatch.waitForExistence(timeout: 15),
                      "Control: el Panel no enseñó los registros sembrados.")

        goGroupsOnly(app)
        tapComeBack(app)

        let fresh = app.buttons["usage_mode_return_fresh"]
        XCTAssertTrue(fresh.waitForExistence(timeout: 15), "La hoja de la vuelta no ofrece «Empezar de cero».")
        fresh.tap()
        app.buttons["usage_mode_return_continue"].tap()

        let erase = app.alerts.buttons["Borrar y empezar de cero"].firstMatch
        XCTAssertTrue(erase.waitForExistence(timeout: 10), "No salió «¿Seguro? Esto es definitivo.».")
        XCTAssertTrue(app.alerts.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Tus grupos no se tocan"))
            .firstMatch.exists, "La segunda confirmación no dice que los grupos no se tocan.")
        attach(app, "7-seguro")
        erase.tap()

        let name = app.textFields["usage_mode_account_name"]
        XCTAssertTrue(name.waitForExistence(timeout: 10), "Tras confirmar no salió «¿Cuál es tu cuenta principal?».")
        let prefilled = (name.value as? String) ?? ""
        XCTAssertFalse(prefilled.isEmpty || prefilled == "Nombre de la cuenta",
                       "La cuenta principal no trae el nombre de antes.")
        XCTAssertFalse(app.buttons["onboarding_next_button"].exists, "Empezar de cero repitió la bienvenida.")
        attach(app, "8-cuenta-principal")
        app.buttons["usage_mode_account_start"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["positive_toast"].waitForExistence(timeout: 20),
                      "No salió el aviso «Ya tienes Yala completo de nuevo» tras empezar de cero.")
        XCTAssertTrue(panelMarker(app).waitForExistence(timeout: 10), "Empezar de cero no llevó al Panel.")
        XCTAssertFalse(app.staticTexts["Bus"].firstMatch.waitForExistence(timeout: 3),
                       "Los registros de antes siguen tras «Empezar de cero».")
        attach(app, "9-cero-panel")
    }

    /// Sin registros: ninguna pregunta, directo al Panel con el aviso. Las cuentas sembradas tienen saldo inicial, que no
    /// cuenta como registro (D5).
    func test_withoutRecords_comesBackWithoutAsking() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "sin-registros")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        goGroupsOnly(app)
        tapComeBack(app)

        XCTAssertTrue(app.descendants(matching: .any)["positive_toast"].waitForExistence(timeout: 15),
                      "Sin registros no salió el aviso «Ya tienes Yala completo de nuevo».")
        XCTAssertFalse(app.staticTexts["usage_mode_return_title"].exists, "Sin registros la vuelta preguntó igual.")
        XCTAssertTrue(panelMarker(app).waitForExistence(timeout: 10), "La vuelta no llevó al Panel.")
        attach(app, "10-sin-registros")
    }
}
