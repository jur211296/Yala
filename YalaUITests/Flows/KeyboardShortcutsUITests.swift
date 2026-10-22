//
//  KeyboardShortcutsUITests.swift
//  YalaUITests
//
//  iPad con teclado, puntero y menús contextuales (carril adaptativo, fase 3).
//
//  - Atajos: solo en iPad (en iPhone no hay teclado en el simulador y la app no los enseña). Correr por UDID en
//    `YalaLane-Adapt-iPad-Pro-13`; en iPhone se saltan diciéndolo. El simulador entrega `typeKey` como teclado físico.
//  - Menú contextual de un registro: pulsación larga, en iPad y en iPhone (`YalaLane-Adapt-iPhone-ProMax`).
//  Seed `realista` + Pro: hacen falta registros para abrir y para el menú.
//

import XCTest

final class KeyboardShortcutsUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeLeft
    }

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
        super.tearDown()
    }

    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    private func launch(deeplink: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "realista", deeplink: deeplink)
        XCTAssertTrue(app.waitForUITestReady(timeout: 90), "uitest_ready ausente — bootstrap/seed no completó.")
        return app
    }

    private func requirePad() throws {
        guard isPad else { throw XCTSkip("Los atajos de teclado son de iPad: en iPhone no se enseñan.") }
    }

    /// ⌘N abre Nuevo registro desde cualquier página.
    func test_commandN_opensNewRecord() throws {
        try requirePad()
        let app = launch(deeplink: "records")
        XCTAssertTrue(app.buttons.matching(identifier: "record_row").firstMatch.waitForExistence(timeout: 15))

        app.typeKey("n", modifierFlags: .command)

        XCTAssertTrue(
            app.buttons["new_transaction_save"].waitForExistence(timeout: 10),
            "⌘N no abrió Nuevo registro.")
    }

    /// ⌘F lleva a Buscar con el campo activo.
    func test_commandF_opensSearch() throws {
        try requirePad()
        let app = launch()
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 15))

        app.typeKey("f", modifierFlags: .command)

        XCTAssertTrue(app.searchFields.firstMatch.waitForExistence(timeout: 10), "⌘F no abrió Buscar.")
        XCTAssertTrue(
            app.navigationBars["Buscar"].waitForExistence(timeout: 5),
            "⌘F no dejó Buscar delante.")
    }

    /// ⌘1…⌘6 siguen el orden de la barra lateral: con la configuración de fábrica, ⌘4 es Registros y ⌘1 el Panel.
    /// Y con un registro abierto, ⌘E abre su editor.
    func test_commandNumber_selectsSection_andCommandE_editsTheOpenRecord() throws {
        try requirePad()
        let app = launch()
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 15))

        app.typeKey("4", modifierFlags: .command)
        let rows = app.buttons.matching(identifier: "record_row")
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 10), "⌘4 no llevó a Registros.")

        rows.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["transaction_detail_edit"].waitForExistence(timeout: 10), "No se abrió el registro.")

        app.typeKey("e", modifierFlags: .command)
        XCTAssertTrue(
            app.buttons["new_transaction_save"].waitForExistence(timeout: 10),
            "⌘E no abrió el editor del registro abierto.")
    }

    /// Pulsación larga sobre un registro: el menú con Editar, y Editar abre el editor. En iPad y en iPhone.
    func test_recordRowContextMenu_offersEdit() {
        let app = launch(deeplink: "records")
        let row = app.buttons.matching(identifier: "record_row").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 15), "No hay filas de registro.")

        row.press(forDuration: 1.2)

        let edit = app.buttons["Editar"].firstMatch
        XCTAssertTrue(edit.waitForExistence(timeout: 5), "La pulsación larga no abrió el menú del registro.")
        XCTAssertTrue(app.buttons["Cambiar categoría"].exists || app.buttons["Eliminar"].exists,
                      "El menú no trae las acciones de un registro.")
        edit.tap()
        XCTAssertTrue(
            app.buttons["new_transaction_save"].waitForExistence(timeout: 10),
            "Editar desde el menú no abrió el editor.")
    }

    /// «Editar» en el menú de un presupuesto abre ESE presupuesto, no el formulario de uno nuevo (que además se
    /// saltaba el límite de presupuestos del plan gratis). Lo cazó la review adversarial de la fase 3.
    func test_budgetRowContextMenu_editsThatBudget() {
        let app = launch(deeplink: "budgets")
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'budget_row_'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 15), "No hay presupuestos sembrados.")
        let name = row.identifier.replacingOccurrences(of: "budget_row_", with: "")

        row.press(forDuration: 1.2)
        let edit = app.buttons["Editar"].firstMatch
        XCTAssertTrue(edit.waitForExistence(timeout: 5), "La pulsación larga no abrió el menú del presupuesto.")
        edit.tap()

        let field = app.textFields["budget_name_field"]
        XCTAssertTrue(field.waitForExistence(timeout: 10), "Editar no abrió el editor de presupuesto.")
        XCTAssertEqual(field.value as? String, name, "El editor no trae el presupuesto de la fila: abrió uno nuevo.")
    }
}
