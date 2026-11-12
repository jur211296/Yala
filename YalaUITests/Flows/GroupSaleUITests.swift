//
//  GroupSaleUITests.swift
//  YalaUITests
//
//  Grupos B · card 7: el selector de categoría del gasto de grupo ofrece también las de ingreso. Con una de ingreso
//  desaparece la cuenta (no salió dinero) y la frase de abajo dice quién te debe y cuándo cuenta como ingreso. Con una
//  de gasto el formulario es el de siempre.
//
//  Discriminante: sin el cambio, el selector no tiene «Gasto | Ingreso» y el caso cae al buscarlo; con la cuenta todavía
//  pedida para una venta, la pastilla de cuenta sigue ahí y «Guardar» no se enciende.
//
//  Convenciones: sin sleeps, scheme Yala Dev, ids y no textos (salvo importes sembrados).
//

import XCTest

final class GroupSaleUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    /// «Viaje a Cusco» es de tres, a partes iguales, y pagas tú: una venta de 120 deja 80 por cobrar.
    func test_altaDeUnaVenta_sinCuenta_yLaFraseDeLoPorCobrar() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "grupos", deeplink: "groups")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        let groupCard = element(app, "group_card")
        XCTAssertTrue(groupCard.waitForExistence(timeout: 10), "No apareció la tarjeta del grupo.")
        groupCard.tap()
        let fab = app.buttons["group_detail_fab_new_expense"]
        XCTAssertTrue(fab.waitForExistence(timeout: 10), "No apareció el FAB de nuevo gasto.")
        fab.tap()

        let description = app.textFields["group_expense_description"]
        XCTAssertTrue(description.waitForExistence(timeout: 5), "El formulario no montó.")
        description.tap()
        description.typeText("Venta de zapatillas")
        let amount = app.textFields["group_expense_amount"]
        amount.tap()
        amount.typeText("120")
        element(app, "group_expense_group_chip").tap()

        // Con una categoría de gasto (o sin elegir), el formulario de siempre: cuenta y «Salen … de tu cuenta».
        let account = app.buttons["group_expense_account_row"]
        let category = app.buttons["group_expense_subcategory_chip"]
        XCTAssertTrue(account.waitForExistence(timeout: 5), "Pagas tú y no se pidió la cuenta.")
        XCTAssertTrue(element(app, "group_expense_outflow_line").waitForExistence(timeout: 5),
                      "Sin venta tiene que salir la línea de lo que sale de tu cuenta.")
        XCTAssertFalse(element(app, "group_expense_sale_line").exists, "Sin venta no hay frase de lo por cobrar.")
        XCTAssertTrue(app.waitForSettledLayout(of: category))

        // El selector ofrece también las de ingreso.
        category.tap()
        let typePill = app.buttons.matching(identifier: "subcategory_selector_type")
        XCTAssertTrue(typePill.element(boundBy: 1).waitForExistence(timeout: 5),
                      "El selector del gasto de grupo no ofrece «Gasto | Ingreso».")
        typePill.element(boundBy: 1).tap()
        let firstRow = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'subcategory_selector_row_'")).firstMatch
        XCTAssertTrue(firstRow.waitForExistence(timeout: 5), "No hay categorías de ingreso en el selector.")
        firstRow.tap()

        // Una venta: sin cuenta, y la frase dice lo que te deben.
        let saleLine = element(app, "group_expense_sale_line")
        XCTAssertTrue(saleLine.waitForExistence(timeout: 5), "No salió la frase de lo por cobrar.")
        XCTAssertTrue(saleLine.label.contains("80"), "La frase no dice lo que te deben: «\(saleLine.label)».")
        XCTAssertFalse(account.exists, "Con una categoría de ingreso no se pide cuenta.")
        XCTAssertFalse(element(app, "group_expense_outflow_line").exists, "Una venta no sale de tu cuenta.")

        let save = app.buttons["group_expense_save"]
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == true"), object: save)
        XCTAssertEqual(XCTWaiter().wait(for: [enabled], timeout: 8), .completed,
                       "«Guardar» no se encendió: la venta sigue pidiendo algo.")
        save.tap()
        XCTAssertTrue(app.buttons["group_expense_success_accept"].waitForExistence(timeout: 10),
                      "No apareció la pantalla de éxito tras guardar la venta.")
        XCTAssertFalse(app.alerts.firstMatch.exists, "Una venta no pregunta si registrarla en una cuenta.")
    }
}
