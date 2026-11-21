//
//  RegistroB1OtrasPantallasUITests.swift
//  YalaUITests
//
//  La hoja B1 llevada al resto de pantallas de registro (encargo del 20-nov): el editor de favorito, Pago entre miembros
//  y la hoja de un borrador de grupo en la Bandeja. En las tres, la fila de abajo va en UNA línea (Cuenta · #, Hoy ·
//  Cuenta o la fecha y lo que falta) y la subcategoría, cuando la hay, sube bajo el monto.
//
//  Discriminante: antes, el favorito pintaba cuenta, categoría y etiquetas en filas que bajaban (categoría junto a la
//  cuenta); el pago llevaba la fecha en una caja con la nota, sin «Hoy»; y el borrador de grupo, la fecha arriba.
//
//  Convenciones: sin sleeps, scheme Yala Dev, ids y no textos (salvo los nombres sembrados, que no se traducen).
//

import XCTest

final class RegistroB1OtrasPantallasUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func assertSameRow(_ a: XCUIElement, _ b: XCUIElement, _ message: String,
                               file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertLessThan(abs(a.frame.midY - b.frame.midY), a.frame.height / 2, message, file: file, line: line)
    }

    // MARK: - Editor de favorito

    /// «Café» (gasto): la cuenta y el «#» en una fila; la subcategoría, encima, bajo el monto; la cápsula de moneda junto
    /// al monto.
    func test_favorito_cuentaYEtiquetasEnUnaFila_subcategoriaBajoElMonto() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "formulario")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        app.openProfile()
        app.openSettingsSection("profile_favorites")
        let row = app.buttons["favorites_row_Café"]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "No apareció el favorito «Café».")
        row.tap()

        let account = app.buttons["favorite_editor_account_chip"]
        let tags = app.buttons["favorite_editor_tags_chip"]
        let category = app.buttons["favorite_editor_subcategory_chip"]
        XCTAssertTrue(account.waitForExistence(timeout: 5), "No se abrió el editor con la cuenta abajo.")
        XCTAssertTrue(app.waitForSettledLayout(of: account))
        assertSameRow(account, tags, "La cuenta y el «#» van en la misma fila.")
        XCTAssertLessThan(category.frame.maxY, account.frame.minY, "La subcategoría va encima de la fila de abajo.")
        XCTAssertTrue(category.isSelected, "Control: «Café» trae su subcategoría.")
        XCTAssertTrue(element(app, "favorite_editor_currency_capsule").exists, "Falta la cápsula de moneda del monto.")
    }

    // MARK: - Pago entre miembros

    /// «Viaje a Lima»: «Saldar» abre el pago con «Hoy» en la fila de abajo, y tocarlo abre la hoja de fecha de Nuevo
    /// registro. La nota va arriba, con el tamaño de la descripción.
    func test_pago_hoyEnLaFilaDeAbajo_abreLaHojaDeFecha() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "grupos", deeplink: "groups")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        let card = app.buttons.matching(identifier: "group_card")
            .matching(NSPredicate(format: "label BEGINSWITH 'Viaje a Lima'")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 15), "No apareció «Viaje a Lima».")
        card.tap()
        let tab = app.buttons["group_detail_tab_balances"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10), "No apareció la pestaña de saldos.")
        tab.tap()
        let settle = element(app, "group_debt_settle")
        for _ in 0..<8 where !(settle.exists && settle.isHittable) { app.swipeUp() }
        XCTAssertTrue(settle.exists, "No hay «Saldar» en Lima.")
        settle.tap()

        let amount = app.textFields["settlement_form_amount"]
        let note = app.textFields["settlement_form_note"]
        let date = app.buttons["settlement_form_date_chip"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5), "No abrió el pago.")
        XCTAssertTrue(note.exists, "Falta la nota.")
        XCTAssertLessThan(note.frame.maxY, amount.frame.minY, "La nota va encima del monto, como la descripción.")
        XCTAssertTrue(date.exists, "Falta «Hoy» en la fila de abajo.")
        XCTAssertGreaterThan(date.frame.minY, amount.frame.maxY, "La fecha va debajo del monto.")
        date.tap()
        XCTAssertTrue(app.datePickers.firstMatch.waitForExistence(timeout: 5), "«Hoy» no abrió la hoja de fecha.")
    }

    // MARK: - Borrador de grupo en la Bandeja

    /// «Recarga Sip» (pagó otro: solo pide la categoría): la subcategoría por elegir sube bajo el monto y la fecha va
    /// en la fila de abajo, junto a «Partir».
    func test_borradorDeGrupo_subcategoriaBajoElMonto_fechaEnLaFilaDeAbajo() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "grupos", extraArguments: ["-uitest-seed-group-split-lines"])
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        let inbox = app.buttons["panel_inbox_button"]
        XCTAssertTrue(inbox.waitForExistence(timeout: 10), "No apareció el botón de la Bandeja.")
        inbox.tap()
        let row = app.buttons["inbox_draft_row_Recarga Sip"]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "No está el borrador de «Recarga Sip».")
        row.tap()

        let category = app.buttons["group_draft_subcategory_chip"]
        let date = element(app, "group_draft_date_chip")
        let split = app.buttons["group_draft_split_button"]
        XCTAssertTrue(category.waitForExistence(timeout: 8), "No abrió la hoja del borrador.")
        XCTAssertTrue(date.exists, "Falta la fecha en la fila de abajo.")
        XCTAssertLessThan(category.frame.maxY, date.frame.minY, "La subcategoría va encima de la fila de abajo.")
        if split.exists {
            assertSameRow(date, split, "«Partir» va en la fila de la fecha.")
        }
    }
}
