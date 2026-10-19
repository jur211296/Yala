//
//  UXAudit22Lote11DecididasUITests.swift
//  YalaUITests
//
//  Las decisiones de Jürgen sobre el lote 11 de la auditoría UX 2.2 (Estadísticas), 2026-10-18:
//  L11-5 «Lo que te falta pagar» y «Tus presupuestos», L11-6 el para qué de la necesidad, L11-7 el resumen con IA
//  que sale solo en Pro, L11-10 una tarjeta de saldo con «Ver el mes anterior» y «Entradas y salidas», L11-12 el editor
//  del informe con lo que llegará y «Probar» sin permiso.
//

import XCTest

final class UXAudit22Lote11DecididasUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func launchStatistics(pro: Bool = false, insightsAIConsent: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(pro: pro, seed: "realista", deeplink: "statistics", insightsAIConsent: insightsAIConsent)
        XCTAssertTrue(app.waitForUITestReady(timeout: 90), "uitest_ready ausente — bootstrap/seed no completó.")
        return app
    }

    /// Cambia el período a «Este mes» desde la píldora del período.
    private func chooseThisMonth(_ app: XCUIApplication) {
        let periodMenu = app.buttons["Todo el tiempo"].firstMatch
        if periodMenu.waitForExistence(timeout: 10) {
            periodMenu.tap()
            let thisMonth = app.buttons["Este mes"].firstMatch
            XCTAssertTrue(thisMonth.waitForExistence(timeout: 5), "No salió «Este mes» en el menú del período.")
            thisMonth.tap()
        }
    }

    /// Baja hasta que el elemento existe y está en pantalla, o se rinde.
    @discardableResult
    private func scrollTo(_ app: XCUIApplication, _ target: XCUIElement, swipes: Int = 12) -> Bool {
        for _ in 0..<swipes {
            if target.exists, target.isHittable { return true }
            app.swipeUp()
        }
        return target.exists
    }

    // MARK: - L11-5 · L11-6

    func test_summary_showsWhatYouStillHaveToPay_andBudgetsWithTheirAmounts() {
        let app = launchStatistics()
        chooseThisMonth(app)

        let toPay = element(app, "insights_to_pay_header")
        XCTAssertTrue(scrollTo(app, toPay), "Falta «Lo que te falta pagar».")
        XCTAssertTrue(toPay.label.contains("Lo que te falta pagar"), "Rótulo inesperado: \(toPay.label)")
        // La cabecera plegable vieja era un botón «Compromisos»; la fila «Compromisos, N de 100» de «Tu salud
        // financiera» es otra cosa y se queda.
        XCTAssertFalse(app.buttons["Compromisos"].exists, "La sección «Compromisos» debería haber desaparecido.")

        // Con más de cuatro presupuestos el bloque sale plegado («abiertos si caben»): el corpus `realista` tiene seis.
        let budgets = element(app, "insights_budgets_header")
        XCTAssertTrue(scrollTo(app, budgets), "Falta «Tus presupuestos».")
        let usage = element(app, "insights_budget_usage")
        if !usage.exists { budgets.tap() }
        XCTAssertTrue(scrollTo(app, usage), "Falta la línea «S/ X de S/ Y · Z %» de un presupuesto.")
        XCTAssertTrue(usage.label.contains(" de "), "La barra no dice de cuánto: \(usage.label)")
    }

    func test_needSection_explainsWhatItIsFor_andGivesAnExamplePerRow() {
        let app = launchStatistics()
        chooseThisMonth(app)

        let header = app.buttons["Distribución del gasto por necesidad"].firstMatch
        XCTAssertTrue(scrollTo(app, header), "Falta la sección de la necesidad.")
        header.tap()
        let purpose = element(app, "insights_need_purpose")
        XCTAssertTrue(scrollTo(app, purpose), "Falta la línea con el para qué.")
        XCTAssertTrue(app.staticTexts["Gustos y caprichos."].exists, "Falta el ejemplo de «Opcional».")
    }

    // MARK: - L11-7

    /// En Pro con el consentimiento dado, Observaciones ya no manda «arriba»: el resumen se pide solo.
    func test_proObservations_doNotAskForATap() {
        let app = launchStatistics(pro: true, insightsAIConsent: true)
        chooseThisMonth(app)

        let observations = app.buttons["Observaciones"].firstMatch
        XCTAssertTrue(scrollTo(app, observations), "Falta la píldora Observaciones.")
        observations.tap()

        XCTAssertFalse(
            app.staticTexts["Toca el botón de arriba para generar observaciones con IA"].waitForExistence(timeout: 3),
            "Pro con consentimiento sigue viendo la caja que manda «arriba»."
        )
        XCTAssertFalse(element(app, "insights_observations_generate_ai").exists,
                       "Con el consentimiento dado no debería hacer falta tocar nada.")
    }

    /// Sin consentimiento hace falta un toque, y el botón está en Observaciones mismo.
    func test_proObservations_withoutConsent_offerTheButtonInPlace() {
        let app = launchStatistics(pro: true)
        chooseThisMonth(app)

        let observations = app.buttons["Observaciones"].firstMatch
        XCTAssertTrue(scrollTo(app, observations), "Falta la píldora Observaciones.")
        observations.tap()
        XCTAssertTrue(element(app, "insights_observations_generate_ai").waitForExistence(timeout: 5),
                      "Falta «Generar con IA» en Observaciones.")
    }

    // MARK: - L11-10

    func test_trends_oneBalanceCard_withPreviousMonthToggle_andMoneyInAndOut() {
        let app = launchStatistics()
        chooseThisMonth(app)
        let chip = app.buttons["detail_chip_tendencias"]
        XCTAssertTrue(chip.waitForExistence(timeout: 10), "El chip Tendencias no apareció.")
        chip.tap()

        let toggle = element(app, "trends_show_previous_toggle")
        XCTAssertTrue(toggle.waitForExistence(timeout: 10), "Falta «Ver el mes anterior».")
        XCTAssertEqual(toggle.label, "Ver el mes anterior")
        XCTAssertFalse(element(app, "trends_previous_period_chart").exists, "La curva anterior sale sin pedirla.")
        toggle.tap()
        XCTAssertTrue(element(app, "trends_previous_period_chart").waitForExistence(timeout: 5),
                      "«Ver el mes anterior» no superpone la curva anterior.")
        XCTAssertFalse(app.staticTexts["Comparativa"].exists, "La tarjeta Comparativa debería haber desaparecido.")

        let inAndOut = app.staticTexts["Entradas y salidas"].firstMatch
        XCTAssertTrue(scrollTo(app, inAndOut), "Falta «Entradas y salidas».")
        XCTAssertFalse(app.staticTexts["Flujo de Efectivo"].exists, "Sigue el nombre viejo.")
        XCTAssertEqual(app.buttons["cashflow_view_byAccount"].label, "Por cuenta")
    }

    // MARK: - L11-12

    func test_reportEditor_saysWhatWillArrive_andTestExplainsAMissingPermission() {
        let app = XCUIApplication()
        app.launchForUITest(notificationsDenied: true)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        _ = app.openProfile()
        app.openSettingsSection("profile_notifications")

        let weekly = app.staticTexts["Resumen semanal"].firstMatch
        XCTAssertTrue(weekly.waitForExistence(timeout: 10), "Falta el resumen semanal en la lista.")
        weekly.tap()

        let line = element(app, "notification_upcoming_line")
        XCTAssertTrue(line.waitForExistence(timeout: 5), "El editor no dice qué llegará.")
        XCTAssertTrue(line.label.hasPrefix("El lunes a las"), "Línea inesperada: \(line.label)")
        XCTAssertTrue(line.label.contains(" del lunes ") && line.label.contains(" al domingo "),
                      "La línea no dice qué días entran: \(line.label)")

        let test = element(app, "notification_test_button")
        XCTAssertTrue(scrollTo(app, test), "Falta «Probar recordatorio».")
        test.tap()
        XCTAssertTrue(app.alerts["Activa las notificaciones"].waitForExistence(timeout: 5),
                      "«Probar» sin permiso no explica nada.")
    }
}
