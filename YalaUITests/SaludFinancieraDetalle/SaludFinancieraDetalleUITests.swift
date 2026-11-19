//
//  SaludFinancieraDetalleUITests.swift
//  YalaUITests
//
//  La hoja de la nota de salud, visual y accionable (pedido de Jürgen del 17-nov-2026). Tocar la tarjeta del Panel abre
//  alertas, presupuestos, próximos pagos y racha en vez del párrafo de pesos; tocar una alerta lleva a su vista, y sin
//  presupuestos la hoja invita a crear uno y lleva a Presupuestos.
//

import XCTest

final class SaludFinancieraDetalleUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Semilla `realista` con los presupuestos en sus cuatro estados: hay presupuestos pasados, así que la primera
    /// alerta es «Te pasaste en …», y tocarla abre ese presupuesto.
    func test_hoja_enseñaLasSecciones_yLaAlertaAbreSuPresupuesto() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "realista", budgetStates: true)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        abrirHoja(app)

        XCTAssertTrue(app.descendants(matching: .any)["health_section_alerts"].waitForExistence(timeout: 15),
                      "La hoja no enseña «Para revisar».")
        XCTAssertTrue(app.descendants(matching: .any)["health_section_budgets"].exists, "Falta «Tus presupuestos».")
        XCTAssertTrue(app.descendants(matching: .any)["health_budget_row"].firstMatch.exists,
                      "Con presupuestos, la hoja no pinta sus barras.")
        XCTAssertTrue(app.descendants(matching: .any)["health_section_payments"].exists, "Falta «Próximos pagos».")
        XCTAssertTrue(app.descendants(matching: .any)["health_section_streak"].exists, "Falta «Tu racha».")
        XCTAssertTrue(app.descendants(matching: .any)["health_how_it_works"].exists,
                      "«¿Cómo se calcula?» no está al final.")

        let alerta = app.buttons["health_alert_over_budget"].firstMatch
        XCTAssertTrue(alerta.waitForExistence(timeout: 5), "Con un presupuesto pasado no sale su alerta.")
        alerta.tap()
        XCTAssertTrue(app.descendants(matching: .any)["budget_detail"].waitForExistence(timeout: 10),
                      "Tocar la alerta no abre el presupuesto.")
    }

    /// Semilla `cuenta-con-movimientos`: sin presupuestos ni pagos. La hoja invita a crear un presupuesto en vez de
    /// decir «Aún no cuenta», y la invitación lleva a Presupuestos.
    func test_sinPresupuestos_invitaACrearUno_yLlevaAPresupuestos() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "cuenta-con-movimientos")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        abrirHoja(app)

        let invitacion = app.buttons["health_budgets_empty"]
        XCTAssertTrue(invitacion.waitForExistence(timeout: 15), "Sin presupuestos, la hoja no invita a crear uno.")
        XCTAssertTrue(app.descendants(matching: .any)["health_payments_empty"].exists,
                      "Sin pagos planificados, la hoja no invita a agregar uno.")
        XCTAssertTrue(app.descendants(matching: .any)["health_alert_negative_account"].exists,
                      "La cuenta en rojo de la semilla no sale como alerta.")

        invitacion.tap()
        let chip = app.buttons["planning_chip_budgets"]
        XCTAssertTrue(chip.waitForExistence(timeout: 10), "La invitación no lleva a Planificación.")
        XCTAssertTrue(chip.isSelected, "La invitación no deja Presupuestos elegido.")
    }

    private func abrirHoja(_ app: XCUIApplication) {
        let card = app.buttons["panel_health_compact"]
        XCTAssertTrue(card.waitForExistence(timeout: 20), "La nota de salud no sale en el Panel.")
        card.tap()
        XCTAssertTrue(app.descendants(matching: .any)["health_breakdown"].waitForExistence(timeout: 5),
                      "Tocar la tarjeta no abre la hoja.")
    }
}
