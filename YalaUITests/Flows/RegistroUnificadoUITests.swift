//
//  RegistroUnificadoUITests.swift
//  YalaUITests
//
//  Registro unificado, opción A de Jürgen (31-oct-2026, «Va la A»): los selectores de Nuevo registro, de la aprobación de
//  un borrador de la Bandeja y de Nuevo gasto de Grupos. Con una tarjeta con su línea en dólares («Visa QA» del perfil
//  `tarjeta-dos-lineas`), la tarjeta y sus dos líneas van en una fila y la categoría y la etiqueta en otra. En Grupos, la
//  cuenta es una pastilla junto a la categoría y el grupo va encima de la fecha.
//
//  Discriminante: con la aprobación de antes (una fila con desplazamiento), la categoría quedaba en la MISMA fila que las
//  líneas y la etiqueta fuera de la pantalla; con la cuenta de Grupos en la tarjeta de «Pagado por», la cuenta quedaba
//  encima de la categoría y no a su lado.
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

    /// Tarjeta con su línea en dólares: «Visa QA · PEN · USD» en una fila y la categoría empieza la siguiente.
    func test_nuevoRegistro_tarjetaConDosLineas_categoriaEnLaFilaDeDebajo() {
        let app = launchWithCard()
        app.buttons["panel_action_new"].tap()
        _ = app.openSelectorFirstRow(chip: "new_transaction_account_chip", rowPrefix: "account_selector_row_")
        let cardRow = app.buttons["account_selector_row_\(card)"]
        XCTAssertTrue(cardRow.waitForExistence(timeout: 5), "No está la fila de la tarjeta.")
        cardRow.tap()

        let account = app.buttons["new_transaction_account_chip"]
        let pen = app.buttons["new_transaction_card_currency_PEN"]
        let usd = app.buttons["new_transaction_card_currency_USD"]
        let category = app.buttons["new_transaction_subcategory_chip"]
        XCTAssertTrue(usd.waitForExistence(timeout: 5), "No salieron las líneas de la tarjeta.")
        XCTAssertTrue(app.waitForSettledLayout(of: usd))
        assertSameRow(account, pen, "La línea en soles no va junto a su tarjeta.")
        assertSameRow(account, usd, "La línea en dólares no va junto a su tarjeta.")
        assertBelow(category, usd, "La categoría tiene que empezar la fila de debajo de las líneas.")
        XCTAssertTrue(pen.isSelected, "Con el importe en soles, la línea elegida es la principal.")

        usd.tap()
        XCTAssertTrue(waitForSelected(usd), "Tocar la línea en dólares no la eligió.")
        XCTAssertFalse(pen.isSelected)
    }

    // MARK: - Aprobación de la Bandeja

    /// El borrador sembrado (tarjeta, Restaurantes y la etiqueta «Trabajo»): las mismas dos filas que Nuevo registro, la
    /// etiqueta a la vista sin desplazar, la línea elegida marcada y la otra elegible.
    func test_aprobacion_mismasDosFilasQueNuevoRegistro_yLaEtiquetaALaVista() {
        let app = launchWithCard()
        app.buttons["panel_inbox_button"].tap()
        let row = app.buttons["inbox_draft_row_Almuerzo con el equipo"]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "No está el borrador sembrado.")
        row.tap()

        let account = app.buttons["draft_editor_account_chip"]
        let pen = app.buttons["card_currency_chip_PEN"]
        let usd = app.buttons["card_currency_chip_USD"]
        let category = app.buttons["draft_editor_subcategory_chip"]
        let tag = element(app, "record_tag_chip_Trabajo")
        XCTAssertTrue(usd.waitForExistence(timeout: 10), "No salieron las líneas de la tarjeta en la aprobación.")
        XCTAssertTrue(app.waitForSettledLayout(of: usd))
        XCTAssertEqual(account.label, card, "La pastilla de cuenta no dice la tarjeta.")
        assertSameRow(account, usd, "Las líneas no van en la fila de la tarjeta.")
        assertBelow(category, usd, "La categoría tiene que ir en la fila de debajo de las líneas.")
        XCTAssertTrue(tag.exists, "No está la etiqueta puesta.")
        assertSameRow(category, tag, "La etiqueta no va junto a la categoría.")
        XCTAssertTrue(app.windows.firstMatch.frame.contains(tag.frame),
                      "La etiqueta se sale de la pantalla (la fila con desplazamiento de antes).")

        XCTAssertTrue(pen.isSelected, "El borrador va en soles: la línea elegida es la principal.")
        XCTAssertFalse(usd.isSelected)
        usd.tap()
        XCTAssertTrue(waitForSelected(usd), "Tocar la línea en dólares no la eligió.")
        XCTAssertFalse(pen.isSelected)
        XCTAssertEqual(account.label, card, "Elegir la línea no puede cambiar el nombre de la tarjeta.")
    }

    // MARK: - Nuevo gasto de Grupos

    /// Pagas tú: la cuenta es una pastilla junto a la categoría (ya no una fila dentro de «Pagado por»), el grupo va
    /// encima de la fecha, y debajo la línea de lo que pasa en tus registros (sale en cuanto el reparto cuadra).
    func test_grupos_cuentaJuntoALaCategoria_grupoEncimaDeLaFecha_yLaLineaDeLoQueSale() throws {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "grupos", deeplink: "groups")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        let groupCard = app.descendants(matching: .any).matching(identifier: "group_card").firstMatch
        XCTAssertTrue(groupCard.waitForExistence(timeout: 10), "No apareció la tarjeta del grupo.")
        groupCard.tap()
        let fab = app.buttons["group_detail_fab_new_expense"]
        XCTAssertTrue(fab.waitForExistence(timeout: 10), "No apareció el FAB de nuevo gasto.")
        fab.tap()

        let group = element(app, "group_expense_group_chip")
        let date = app.buttons["group_expense_date_chip"]
        XCTAssertTrue(date.waitForExistence(timeout: 5), "El formulario no montó.")
        XCTAssertTrue(group.exists, "No está el grupo.")
        XCTAssertLessThan(group.frame.maxY, date.frame.minY, "El grupo tiene que ir encima de la fecha.")

        let amount = app.textFields["group_expense_amount"]
        amount.tap()
        amount.typeText("240")
        // Los selectores van abajo, como en Nuevo registro: con el teclado puesto quedan debajo. Tocar fuera de los campos
        // (el grupo, que dentro del detalle no responde) cierra el teclado, como lo haría una persona.
        group.tap()

        let account = app.buttons["group_expense_account_row"]
        let category = app.buttons["group_expense_subcategory_chip"]
        XCTAssertTrue(account.waitForExistence(timeout: 5), "Pagaste tú y no se pidió la cuenta.")
        XCTAssertTrue(app.waitForSettledLayout(of: account))
        assertSameRow(account, category, "La cuenta tiene que ir junto a la categoría, como en Nuevo registro.")
        let paidBy = element(app, "group_expense_paidby_card")
        XCTAssertGreaterThanOrEqual(account.frame.minY, paidBy.frame.maxY,
                                    "La cuenta sigue dentro de la tarjeta de «Pagado por».")

        // «Viaje a Cusco» es de tres, a partes iguales: salen 240 de tu cuenta y te deben 160 (los dos de los demás).
        let outflow = element(app, "group_expense_outflow_line")
        XCTAssertTrue(outflow.waitForExistence(timeout: 5), "No salió la línea de lo que sale de tu cuenta.")
        XCTAssertGreaterThan(outflow.frame.minY, account.frame.minY, "La línea va debajo de los selectores.")
        XCTAssertTrue(outflow.label.contains("240"), "La línea no dice lo que sale de tu cuenta: «\(outflow.label)».")
        XCTAssertTrue(outflow.label.contains("160"), "La línea no dice lo que te deben: «\(outflow.label)».")
        let firstLabel = outflow.label
        XCTAssertLessThan(try XCTUnwrap(firstLabel.range(of: "240")).lowerBound,
                          try XCTUnwrap(firstLabel.range(of: "160")).lowerBound, "Los importes van cruzados.")

        app.chooseFirstSelectorRow(chip: "group_expense_account_row", rowPrefix: "account_selector_row_")
        XCTAssertTrue(waitForSelected(account, timeout: 5), "La cuenta no quedó elegida.")
    }
}
