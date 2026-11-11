//
//  GroupSplitAmountFieldUITests.swift
//  YalaUITests
//
//  Ticket `group-split-amount-field-keeps-the-old-value-and-drops-typed-digits` (lote 2.3 de Grupos, 10-nov).
//  Los campos del reparto por monto llegan con el importe repartido. Tocarlo a la izquierda dejaba el cursor delante:
//  borrar no hacía nada y escribir «150» acababa en «1,200.00» (medido también con Device MCP en el iPhone 14 el mismo
//  día). Ahora, al entrar en el campo, el cursor va al final: seis borrados lo vacían y queda lo escrito.
//
//  Convenciones: scheme Yala Dev, sin sleeps, por `accessibilityIdentifier` salvo los botones del segmentado y los
//  campos del reparto, que no tienen id y se buscan por su etiqueta de accesibilidad.
//

import XCTest

final class GroupSplitAmountFieldUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_correctingASplitAmount_keepsWhatWasTyped() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "grupos", deeplink: "groups")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        let card = app.buttons.matching(identifier: "group_card")
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Viaje a Cusco")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 30), "No apareció «Viaje a Cusco».")
        card.tap()
        let fab = app.buttons["group_detail_fab_new_expense"]
        XCTAssertTrue(fab.waitForExistence(timeout: 15), "El detalle no montó.")
        fab.tap()

        let amount = app.textFields["group_expense_amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 10), "«Nuevo gasto» no montó.")
        amount.tap()
        amount.typeText("300")

        let splitRow = app.buttons["group_expense_split_row"]
        XCTAssertTrue(splitRow.waitForHittable(timeout: 10), "La frase del reparto no se puede tocar.")
        splitRow.tap()
        let exact = app.buttons["Monto exacto"].firstMatch
        XCTAssertTrue(exact.waitForHittable(timeout: 10), "El segmento «Monto exacto» no apareció.")
        exact.tap()

        // Ana: 300 entre tres llega como «100.00».
        let field = app.textFields["Monto exacto Ana"]
        XCTAssertTrue(field.waitForExistence(timeout: 10), "No apareció el campo del reparto de Ana.")
        XCTAssertEqual(field.value as? String, "100.00", "Control: el campo no llegó con el importe repartido.")
        XCTAssertTrue(field.waitForHittable(timeout: 10), "El campo de Ana no se puede tocar.")

        // El toque a la izquierda del número, donde la revisión dejó el cursor delante.
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.5)).tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "El teclado no salió.")
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 6))
        field.typeText("150")

        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "reparto-tras-corregir"
        shot.lifetime = .keepAlways
        add(shot)
        XCTAssertEqual(field.value as? String, "150", "Corregir el importe del reparto no dejó lo escrito.")

        // El filtro reescribe el número al poner la coma de miles: el cursor tiene que seguir al final. Con la posición
        // del texto de antes, «1,500» + «5» acababa en «15,050».
        field.typeText("05")
        XCTAssertEqual(field.value as? String, "15,005", "Tras la coma de miles, lo escrito no fue al final.")
        // Y el tercer decimal se descarta sin mover el cursor de sitio.
        field.typeText(".255")
        XCTAssertEqual(field.value as? String, "15,005.25", "El tercer decimal movió el cursor.")
        field.typeText("1")
        XCTAssertEqual(field.value as? String, "15,005.25", "Tras descartar un decimal, el cursor no siguió al final.")
    }
}
