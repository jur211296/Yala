//
//  UXAudit22Lote11y16UITests.swift
//  YalaUITests
//
//  Implementación de la auditoría UX 2.2, lotes 11 (Estadísticas) y 16 (Ajustes): las cuatro pestañas caben, las
//  flechas del período, el enlace con pestaña y período (y que ese período vale solo para la visita), y la
//  confirmación antes de cambiar la moneda principal. Seed `minimal`.
//

import XCTest

final class UXAudit22Lote11y16UITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id]
    }

    private func openStatistics(_ app: XCUIApplication) {
        app.tabBars.buttons.element(boundBy: 1).tap()
        XCTAssertTrue(app.buttons["detail_chip_insights"].waitForExistence(timeout: 10), "No apareció Estadísticas.")
    }

    /// L11-1: con los cuatro nombres, «Registros» quedaba fuera de la pantalla. Ahora los cuatro chips caben a la vista.
    func test_statistics_theFourTabsFitOnScreen() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        openStatistics(app)

        let width = app.windows.firstMatch.frame.width
        for id in ["detail_chip_insights", "detail_chip_tendencias", "detail_chip_categorías", "detail_chip_registros"] {
            let chip = app.buttons[id]
            XCTAssertTrue(chip.waitForExistence(timeout: 5), "Falta el chip \(id).")
            XCTAssertLessThanOrEqual(chip.frame.maxX, width, "El chip \(id) sale de la pantalla.")
        }
    }

    /// L11-3: las flechas pasan al período anterior y vuelven, y el rango de días cambia con ellas.
    func test_statistics_arrowsStepThePeriod_andComeBack() {
        let app = XCUIApplication()
        // «Este mes» como período por defecto: con «Todo el tiempo» (el de la semilla) no hay flechas.
        app.launchForUITest(extraArguments: ["-defaultPeriod", "thisMonth"])
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        openStatistics(app)

        let range = element(app, "stats_period_range")
        XCTAssertTrue(range.waitForExistence(timeout: 10), "Bajo la píldora no sale el rango de días.")
        let original = range.label
        let previous = app.buttons["stats_period_previous"]
        let next = app.buttons["stats_period_next"]
        XCTAssertTrue(previous.exists, "Falta la flecha del período anterior.")
        XCTAssertFalse(next.isEnabled, "Con «Este mes», la flecha de siguiente tendría que estar apagada.")

        previous.tap()
        XCTAssertTrue(next.waitForEnabled(timeout: 5), "Tras ir al anterior, la flecha de siguiente sigue apagada.")
        XCTAssertNotEqual(range.label, original, "La flecha no cambió el período.")

        next.tap()
        let back = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", original), object: range)
        XCTAssertEqual(XCTWaiter().wait(for: [back], timeout: 5), .completed, "La flecha de siguiente no volvió a «Este mes».")
    }

    /// L11-2: `statistics/trends` abría la última pestaña usada; solo se entendían `records` y `categories`.
    func test_link_opensTrends() {
        let app = XCUIApplication()
        app.launchForUITest(deeplinkURL: "yaladev://statistics/trends")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        let trends = app.buttons["detail_chip_tendencias"]
        XCTAssertTrue(trends.waitForExistence(timeout: 15), "No se abrió Estadísticas.")
        let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isSelected == true"), object: trends)
        XCTAssertEqual(XCTWaiter().wait(for: [selected], timeout: 10), .completed, "El enlace no abrió Tendencias.")
    }

    /// L11-2: el informe abre el Resumen con su período, y ese período vale para esa visita: al salir de Estadísticas
    /// vuelve el que había (en la semilla, «Todo el tiempo», que no tiene rango de días).
    func test_reportLink_opensItsPeriod_andLeavingRestoresTheOldOne() {
        let app = XCUIApplication()
        app.launchForUITest(deeplinkURL: "yaladev://statistics/insights/last7Days")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        XCTAssertTrue(element(app, "stats_period_range").waitForExistence(timeout: 15),
                      "El enlace no puso su período (sin rango de días bajo la píldora).")
        XCTAssertTrue(app.buttons["detail_chip_insights"].isSelected, "El enlace no abrió el Resumen.")

        app.tabBars.buttons.element(boundBy: 0).tap()
        app.tabBars.buttons.element(boundBy: 1).tap()
        XCTAssertTrue(app.buttons["detail_chip_insights"].waitForExistence(timeout: 10))
        XCTAssertTrue(element(app, "stats_period_range").waitForNonExistence(timeout: 5),
                      "Al volver a Estadísticas sigue el período del aviso: no se devolvió el de antes.")
    }

    /// L16-3: elegir otra moneda ya no la aplica: pide confirmar con el antes y el después, y cancelar no toca nada.
    func test_changingTheMainCurrency_asksFirst_andCancelKeepsIt() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        app.openProfile()
        app.openSettingsSection("profile_currency")

        let preferred = app.buttons["currency_preferred_button"]
        XCTAssertTrue(preferred.waitForExistence(timeout: 5), "No se montó la pantalla de moneda.")
        let before = preferred.label
        preferred.tap()

        let euro = app.buttons["currency_row_EUR"]
        XCTAssertTrue(euro.waitForExistence(timeout: 5), "No se abrió la lista de monedas.")
        euro.tap()

        let confirm = app.buttons["currency_change_confirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "Elegir otra moneda no pidió confirmar.")
        XCTAssertTrue(element(app, "currency_change_before_after").exists, "La confirmación no enseña el antes y el después.")

        app.buttons["currency_change_cancel"].tap()
        XCTAssertTrue(confirm.waitForNonExistence(timeout: 5), "Cancelar no cerró la confirmación.")
        XCTAssertEqual(preferred.label, before, "Cancelar cambió la moneda principal.")
    }
}

private extension XCUIElement {
    func waitForEnabled(timeout: TimeInterval) -> Bool {
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == true"), object: self)
        return XCTWaiter().wait(for: [enabled], timeout: timeout) == .completed
    }
}
