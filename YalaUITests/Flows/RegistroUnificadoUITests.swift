//
//  RegistroUnificadoUITests.swift
//  YalaUITests
//
//  Registro unificado, opción A de Jürgen (31-oct-2026, «Va la A»), y desde el 20-nov la hoja B1 en las tres pantallas:
//  los selectores de Nuevo registro, de la aprobación de un borrador de la Bandeja y de Nuevo gasto de Grupos. Con una tarjeta con su línea en dólares («Visa QA» del perfil
//  `tarjeta-dos-lineas`), la tarjeta y sus dos líneas van en una fila y la categoría y la etiqueta en otra. En Grupos, la
//  cuenta es una pastilla junto a la categoría y el grupo va encima de la fecha.
//
//  Discriminante (B1): con la aprobación de antes la fecha iba arriba, la categoría en la fila de las etiquetas y la
//  línea en dólares era una pastilla; en Grupos la fecha iba sobre la descripción y la categoría junto a la cuenta.
//
//  Convenciones: sin sleeps, scheme Yala Dev, ids y no textos (salvo los nombres sembrados, que no se traducen).
//

import XCTest

final class RegistroUnificadoUITests: XCTestCase {

    private let card = "Visa QA"

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    private func launchWithCard() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "tarjeta-dos-lineas", extraArguments: ["-uitest-seed-registro-unificado"])
        XCTAssertTrue(app.waitForUITestReady(timeout: 90), "uitest_ready ausente — bootstrap/seed no completó.")
        XCTAssertTrue(app.buttons["panel_action_new"].waitForExistence(timeout: 10), "La app no llegó al Panel.")
        return app
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func waitForSelected(_ element: XCUIElement, timeout: TimeInterval = 3) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isSelected == true"), object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    /// Mismo renglón: los centros a menos de media pastilla.
    private func assertSameRow(_ a: XCUIElement, _ b: XCUIElement, _ message: String,
                               file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertLessThan(abs(a.frame.midY - b.frame.midY), a.frame.height / 2, message, file: file, line: line)
    }

    /// `b` en una fila de debajo de `a`.
    private func assertBelow(_ b: XCUIElement, _ a: XCUIElement, _ message: String,
                             file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertGreaterThanOrEqual(b.frame.minY, a.frame.maxY, message, file: file, line: line)
    }

    // MARK: - Nuevo registro

    /// Hoja B1 (2026-11-20): la tarjeta con su línea en dólares ya no pinta las pastillas PEN · USD junto a la cuenta.
    /// El chip dice la tarjeta y la cápsula de moneda del monto elige la línea.
    func test_nuevoRegistro_tarjetaConDosLineas_laCapsulaDeMonedaEligeLaLinea() {
        let app = launchWithCard()
        app.buttons["panel_action_new"].tap()
        _ = app.openSelectorFirstRow(chip: "new_transaction_account_chip", rowPrefix: "account_selector_row_")
        let cardRow = app.buttons["account_selector_row_\(card)"]
        XCTAssertTrue(cardRow.waitForExistence(timeout: 5), "No está la fila de la tarjeta.")
        cardRow.tap()

        let account = app.buttons["new_transaction_account_chip"]
        XCTAssertTrue(account.waitForExistence(timeout: 5))
        XCTAssertEqual(account.label, card, "La pastilla de cuenta no dice la tarjeta.")
        XCTAssertFalse(app.buttons["new_transaction_card_currency_USD"].exists, "Vuelven las pastillas de moneda.")

        let capsule = app.buttons["new_transaction_currency_capsule"]
        XCTAssertTrue(capsule.waitForExistence(timeout: 5), "Falta la cápsula de moneda junto al monto.")
        XCTAssertEqual(capsule.value as? String, "PEN", "Con el importe en soles, la línea elegida es la principal.")
        capsule.tap()
        let usd = app.buttons["new_transaction_currency_option_USD"].firstMatch
        XCTAssertTrue(usd.waitForExistence(timeout: 5), "La cápsula no ofreció dólares.")
        usd.tap()
        expectation(for: NSPredicate(format: "value == 'USD'"), evaluatedWith: capsule)
        waitForExpectations(timeout: 5)
        XCTAssertEqual(account.label, card, "Elegir dólares deja la tarjeta en el chip: cambia su línea.")
    }

    // MARK: - Aprobación de la Bandeja

    /// Hoja B1 en la aprobación (20-nov): Hoy · Cuenta · # en UNA fila, la subcategoría bajo el monto, y la línea en
    /// dólares de la tarjeta la elige la cápsula de moneda (ya no hay pastillas PEN · USD). El título dice el tipo.
    func test_aprobacion_filaDeAbajoEnUnaLinea_yLaCapsulaEligeLaLinea() {
        let app = launchWithCard()
        app.buttons["panel_inbox_button"].tap()
        let row = app.buttons["inbox_draft_row_Almuerzo con el equipo"]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "No está el borrador sembrado.")
        row.tap()

        let account = app.buttons["draft_editor_account_chip"]
        let date = app.buttons["draft_editor_date_chip"]
        let tags = app.buttons["draft_editor_tags_chip"]
        let category = app.buttons["draft_editor_subcategory_chip"]
        let amount = app.textFields["draft_editor_amount"]
        XCTAssertTrue(account.waitForExistence(timeout: 10), "No abrió la aprobación.")
        XCTAssertTrue(app.waitForSettledLayout(of: account))
        XCTAssertEqual(account.label, card, "La pastilla de cuenta no dice la tarjeta.")
        assertSameRow(date, account, "La fecha tiene que ir en la fila de la cuenta.")
        assertSameRow(account, tags, "El «#» tiene que ir en la fila de la cuenta.")
        XCTAssertLessThan(category.frame.maxY, account.frame.minY, "La subcategoría va encima de la fila, bajo el monto.")
        XCTAssertGreaterThan(category.frame.minY, amount.frame.maxY, "La subcategoría va bajo el monto.")
        XCTAssertFalse(app.buttons["card_currency_chip_USD"].exists, "Vuelven las pastillas de moneda.")
        XCTAssertTrue(app.buttons["draft_editor_type_menu"].exists, "El título tenía que abrir el menú de tipo.")

        let capsule = app.buttons["draft_editor_currency_capsule"]
        XCTAssertTrue(capsule.exists, "Falta la cápsula de moneda junto al monto.")
        XCTAssertEqual(capsule.value as? String, "PEN", "El borrador va en soles: la línea elegida es la principal.")
        capsule.tap()
        let usd = app.buttons["draft_editor_currency_option_USD"].firstMatch
        XCTAssertTrue(usd.waitForExistence(timeout: 5), "La cápsula no ofreció la línea en dólares.")
        usd.tap()
        expectation(for: NSPredicate(format: "value == 'USD'"), evaluatedWith: capsule)
        waitForExpectations(timeout: 5)
        XCTAssertEqual(account.label, card, "Elegir la línea no puede cambiar el nombre de la tarjeta.")
    }

    /// El título abre Gasto | Ingreso, como en Nuevo registro: pasar a ingreso vacía la subcategoría (la de un gasto no
    /// vale) y el título lo dice.
    func test_aprobacion_elTituloCambiaElTipo() {
        let app = launchWithCard()
        app.buttons["panel_inbox_button"].tap()
        let row = app.buttons["inbox_draft_row_Almuerzo con el equipo"]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "No está el borrador sembrado.")
        row.tap()
        let menu = app.buttons["draft_editor_type_menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 10), "El título no abre el menú de tipo.")
        let expenseTitle = menu.value as? String
        let category = app.buttons["draft_editor_subcategory_chip"]
        XCTAssertTrue(category.isSelected, "Control: el borrador trae su subcategoría.")
        menu.tap()
        let income = app.buttons["draft_editor_type_income"].firstMatch
        XCTAssertTrue(income.waitForExistence(timeout: 5), "El menú no ofrece «Ingreso».")
        income.tap()
        expectation(for: NSPredicate(format: "isSelected == false"), evaluatedWith: category)
        waitForExpectations(timeout: 5)
        XCTAssertNotEqual(menu.value as? String, expenseTitle, "El título no cambió con el tipo.")
    }

    // MARK: - Nuevo gasto de Grupos

    /// Hoja B1 en Grupos (20-nov): pagas tú, así que la cuenta va en la fila de abajo junto a «Hoy», en una línea; la
    /// subcategoría sube bajo el monto, encima de «Pagado por»; el grupo sigue arriba, y debajo de la fila, la línea de
    /// lo que pasa en tus registros.
    func test_grupos_hoyYCuentaEnUnaFila_subcategoriaBajoElMonto_yLaLineaDeLoQueSale() throws {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "grupos", deeplink: "groups")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        let groupCard = app.descendants(matching: .any).matching(identifier: "group_card").firstMatch
        XCTAssertTrue(groupCard.waitForExistence(timeout: 10), "No apareció la tarjeta del grupo.")
        groupCard.tap()
        let fab = app.buttons["group_detail_action_new_expense"]
        XCTAssertTrue(fab.waitForExistence(timeout: 10), "No apareció el FAB de nuevo gasto.")
        fab.tap()

        let group = element(app, "group_expense_group_chip")
        let amount = app.textFields["group_expense_amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5), "El formulario no montó.")
        XCTAssertTrue(group.exists, "No está el grupo.")
        XCTAssertLessThan(group.frame.maxY, amount.frame.minY, "El grupo tiene que ir encima del monto.")

        amount.tap()
        amount.typeText("240")
        // Tocar fuera de los campos (el grupo, que dentro del detalle no responde) cierra el teclado.
        group.tap()

        let date = app.buttons["group_expense_date_chip"]
        let account = app.buttons["group_expense_account_row"]
        let category = app.buttons["group_expense_subcategory_chip"]
        XCTAssertTrue(account.waitForExistence(timeout: 5), "Pagaste tú y no se pidió la cuenta.")
        XCTAssertTrue(app.waitForSettledLayout(of: account))
        assertSameRow(date, account, "«Hoy» y la cuenta van en la misma fila, como en Nuevo registro.")
        let paidBy = element(app, "group_expense_paidby_card")
        XCTAssertGreaterThan(category.frame.minY, amount.frame.maxY, "La subcategoría va bajo el monto.")
        XCTAssertLessThan(category.frame.maxY, paidBy.frame.minY, "La subcategoría va encima de «Pagado por».")
        XCTAssertGreaterThanOrEqual(account.frame.minY, paidBy.frame.maxY,
                                    "La cuenta sigue dentro de la tarjeta de «Pagado por».")

        // «Viaje a Cusco» es de tres, a partes iguales: salen 240 de tu cuenta y te deben 160 (los dos de los demás).
        let outflow = element(app, "group_expense_outflow_line")
        XCTAssertTrue(outflow.waitForExistence(timeout: 5), "No salió la línea de lo que sale de tu cuenta.")
        XCTAssertGreaterThan(outflow.frame.minY, account.frame.minY, "La línea va debajo de la fila.")
        XCTAssertTrue(outflow.label.contains("240"), "La línea no dice lo que sale de tu cuenta: «\(outflow.label)».")
        XCTAssertTrue(outflow.label.contains("160"), "La línea no dice lo que te deben: «\(outflow.label)».")
        let firstLabel = outflow.label
        XCTAssertLessThan(try XCTUnwrap(firstLabel.range(of: "240")).lowerBound,
                          try XCTUnwrap(firstLabel.range(of: "160")).lowerBound, "Los importes van cruzados.")

        app.chooseFirstSelectorRow(chip: "group_expense_account_row", rowPrefix: "account_selector_row_")
        XCTAssertTrue(waitForSelected(account, timeout: 5), "La cuenta no quedó elegida.")
    }
}
