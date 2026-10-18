//
//  AccountCardReportsUITests.swift
//  YalaUITests
//
//  Tarjeta con varias divisas, entrega 4 (`multi-currency-accounts-4-reports-and-export`). Seed `tarjeta-dos-lineas`:
//  «Visa QA» (PEN) con su línea «Visa QA · USD» (−80 US$), «Ahorros QA» (PEN) y «Dólares QA» (USD).
//  - Informe agrupado por cuenta: «Por tarjeta» da una fila con la tarjeta convertida y «≈»; «Por línea», las dos.
//  - Flujo de caja por cuenta: «Por tarjeta» no enseña la línea como página propia; «Por línea», sí.
//  - Exportar: la tarjeta sale una vez en el filtro, ofrece las divisas de sus dos líneas y la columna «Tarjeta».
//  Convenciones: sin sleeps, scheme Yala Dev, ids y no textos (salvo los nombres sembrados, que no se traducen).
//

import XCTest

final class AccountCardReportsUITests: XCTestCase {

    private let card = "Visa QA"
    private let line = "Visa QA · USD"

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "tarjeta-dos-lineas")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        XCTAssertTrue(app.buttons["panel_action_new"].waitForExistence(timeout: 10), "La app no llegó al Panel.")
        return app
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id]
    }

    /// El selector «Por tarjeta · Por línea»: su segmento `index` (0 = por tarjeta, 1 = por línea).
    private func grouping(_ app: XCUIApplication, _ index: Int) -> XCUIElement {
        let picker = element(app, "account_card_grouping_picker")
        XCTAssertTrue(picker.waitForExistence(timeout: 10), "No salió el selector «Por tarjeta · Por línea».")
        return picker.buttons.element(boundBy: index)
    }

    // MARK: - Informe

    func test_report_byCard_showsTheCardOnceConverted_andByLineShowsBothLines() {
        let app = launch()
        let moreTab = app.tabBars.buttons.element(boundBy: 3)
        XCTAssertTrue(moreTab.waitForExistence(timeout: 10), "No apareció el tab Más.")
        moreTab.tap()
        let cashflowCard = app.buttons["more_card_flujoDeCaja"]
        XCTAssertTrue(cashflowCard.waitForExistence(timeout: 5), "No apareció la card Flujo de Caja en Más.")
        cashflowCard.tap()
        let comparativa = app.buttons["report_chip_comparativa"]
        XCTAssertTrue(comparativa.waitForExistence(timeout: 10), "No se abrió Reportes.")
        comparativa.tap()

        // Sin agrupar por cuenta, el selector no sale.
        let drillDown = app.buttons["report_grouping_drill_down"]
        XCTAssertTrue(drillDown.waitForExistence(timeout: 10), "No está «Profundizar».")
        XCTAssertFalse(element(app, "account_card_grouping_picker").exists, "El selector sale sin agrupar por cuenta.")

        drillDown.tap()
        let addAccount = app.buttons["report_grouping_add_cuenta"]
        XCTAssertTrue(addAccount.waitForExistence(timeout: 5), "No está la opción Cuenta en «Profundizar».")
        // El centro de esa fila no responde (la fila no tiene `contentShape`): se toca el «+».
        addAccount.coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: 0.5)).tap()
        let save = app.buttons["toolbar_save_button"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        save.tap()

        let cardRow = element(app, "pivot_row_cuenta_\(card)")
        XCTAssertTrue(cardRow.waitForExistence(timeout: 10), "No salió la fila de la tarjeta.")
        XCTAssertTrue(cardRow.label.contains("≈"), "La tarjeta no sale convertida con «≈»: «\(cardRow.label)».")
        XCTAssertTrue(cardRow.label.contains("S/"), "La tarjeta no sale en soles: «\(cardRow.label)».")
        XCTAssertFalse(element(app, "pivot_row_cuenta_\(line)").exists, "«Por tarjeta» enseña la línea suelta.")

        grouping(app, 1).tap()
        let lineRow = element(app, "pivot_row_cuenta_\(line)")
        XCTAssertTrue(lineRow.waitForExistence(timeout: 10), "«Por línea» no enseña la línea en dólares.")
        XCTAssertTrue(lineRow.label.contains("-80"), "La línea no sale en su divisa: «\(lineRow.label)».")
        XCTAssertFalse(lineRow.label.contains("≈"), "La línea no se convierte: «\(lineRow.label)».")
        XCTAssertFalse(element(app, "pivot_row_cuenta_\(card)").label.contains("≈"), "«Por línea» convierte la principal.")
    }

    // MARK: - Flujo de caja

    /// Deja `element` en la franja central: arriba lo tapa la barra de chips flotante de Estadísticas (un toque ahí
    /// cambia de pestaña) y abajo, la barra de pestañas. Arrastres cortos y lentos, sin inercia.
    private func bringToMiddle(_ app: XCUIApplication, _ element: XCUIElement) {
        let height = app.frame.height
        for _ in 0..<8 {
            let midY = element.frame.midY
            if midY > height * 0.35 && midY < height * 0.6 { return }
            let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: midY > height * 0.6 ? 0.65 : 0.45))
            let to = app.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: midY > height * 0.6 ? 0.45 : 0.65))
            from.press(forDuration: 0.1, thenDragTo: to, withVelocity: .slow, thenHoldForDuration: 0.3)
        }
        XCTAssertTrue(element.frame.midY > height * 0.35 && element.frame.midY < height * 0.6,
                      "No se pudo dejar el selector a media pantalla (y=\(element.frame.midY)).")
    }

    /// Recorre el carrusel por cuenta hacia la derecha y dice si alguna página se titula `title`.
    private func carouselShows(_ app: XCUIApplication, title: String) -> Bool {
        for _ in 0..<5 {
            if app.staticTexts[title].exists && app.staticTexts[title].isHittable { return true }
            let picker = element(app, "account_card_grouping_picker")
            let y = picker.frame.maxY + 120
            let start = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: app.frame.width * 0.85, dy: y))
            let end = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: app.frame.width * 0.1, dy: y))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        return app.staticTexts[title].exists && app.staticTexts[title].isHittable
    }

    func test_cashFlow_byCard_hidesTheLinePage_andByLineShowsIt() {
        let app = launch()
        let statsTab = app.tabBars.buttons.element(boundBy: 1)
        XCTAssertTrue(statsTab.waitForExistence(timeout: 10))
        statsTab.tap()
        let trends = app.buttons["detail_chip_tendencias"]
        XCTAssertTrue(trends.waitForExistence(timeout: 10), "No está el chip Tendencias.")
        trends.tap()

        let byAccount = app.buttons["cashflow_view_byAccount"]
        XCTAssertTrue(byAccount.waitForExistence(timeout: 10), "No está la vista por cuenta del flujo de caja.")
        var swipes = 0
        while !byAccount.isHittable && swipes < 10 {
            app.swipeUp()
            swipes += 1
        }
        byAccount.tap()

        let picker = element(app, "account_card_grouping_picker")
        XCTAssertTrue(picker.waitForExistence(timeout: 10), "No salió el selector «Por tarjeta · Por línea».")
        bringToMiddle(app, picker)

        XCTAssertTrue(carouselShows(app, title: card), "«Por tarjeta» no tiene página para la tarjeta.")
        XCTAssertFalse(app.staticTexts[line].exists, "«Por tarjeta» enseña la línea como página propia.")
        let estimate = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", "≈")).firstMatch
        XCTAssertTrue(estimate.waitForExistence(timeout: 5), "La página de la tarjeta no sale convertida con «≈».")

        grouping(app, 1).tap()
        XCTAssertTrue(carouselShows(app, title: line), "«Por línea» no tiene página para la línea en dólares.")
    }

    // MARK: - Exportar

    func test_export_offersTheCardOnce_itsCurrencies_andTheCardColumn() {
        let app = launch()
        app.openProfile()
        let exportRow = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Exportar datos")).firstMatch
        XCTAssertTrue(exportRow.waitForExistence(timeout: 10), "No apareció la fila Exportar datos en el Perfil.")
        var swipes = 0
        while !exportRow.isHittable && swipes < 14 {
            app.swipeUp()
            swipes += 1
        }
        exportRow.tap()

        let cardChip = app.buttons["export_account_chip_\(card)"]
        XCTAssertTrue(cardChip.waitForExistence(timeout: 10), "El filtro de cuentas no ofrece la tarjeta.")
        XCTAssertFalse(app.buttons["export_account_chip_\(line)"].exists, "El filtro ofrece la línea como cuenta suelta.")

        // Solo la tarjeta: el filtro de divisas ofrece las de sus dos líneas.
        app.buttons["export_account_chip_Ahorros QA"].tap()
        app.buttons["export_account_chip_Dólares QA"].tap()
        XCTAssertTrue(app.buttons["export_currency_chip_PEN"].waitForExistence(timeout: 5), "Falta la divisa de la principal.")
        XCTAssertTrue(app.buttons["export_currency_chip_USD"].exists, "Falta la divisa de la línea en dólares.")

        let next = app.navigationBars.buttons.matching(NSPredicate(format: "label == %@", "Siguiente")).firstMatch
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        next.tap()
        let cardColumn = element(app, "export_column_card")
        XCTAssertTrue(cardColumn.waitForExistence(timeout: 10), "No se ofrece la columna Tarjeta.")
        XCTAssertEqual(cardColumn.value as? String, "1", "La columna Tarjeta no sale activada.")
    }
}
