//
//  AntExpensesAIProUITests.swift
//  YalaUITests
//
//  Gastos hormiga con IA, solo Pro (ticket `insights-ant-expenses-ai-version-for-pro`). La tarjeta gratis es la misma
//  para todos; Pro ve debajo lo que la IA juntó y un consejo. Corpus `realista` + dos grafías de la misma cafetería
//  (`-uitest-seed-ant-spellings`); la IA contesta sin red (`-uitest-stats-ai-reply`), y la decisión de cuándo pedir es
//  la de producción.
//

import XCTest

final class AntExpensesAIProUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    private func launch(pro: Bool, consent: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        var extra = ["-uitest-stats-ai-reply", "-uitest-seed-ant-spellings"]
        if consent { extra.append("-uitest-insights-ai-consent") }
        app.launchForUITest(pro: pro, seed: "realista", deeplink: "statistics", extraArguments: extra)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        return app
    }

    /// Arrastres cortos hasta que la tarjeta quede entera en la franja visible.
    private func bringIntoView(_ app: XCUIApplication, _ target: XCUIElement) {
        let window = app.windows.firstMatch.frame
        for _ in 0..<14 {
            let frame = target.frame
            if !frame.isEmpty, frame.minY > window.minY + 140, frame.maxY < window.maxY - 90 { return }
            let start = app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.72))
            let end = app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.42))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    func test_pro_seesWhatTheAIMerged_andATip_belowTheFreeCard() {
        let app = launch(pro: true, consent: true)
        let card = element(app, "insights_ant_expenses_card")
        XCTAssertTrue(card.waitForExistence(timeout: 20), "Resumen no enseñó la tarjeta de gastos hormiga.")

        let block = element(app, "insights_ant_expenses_ai")
        XCTAssertTrue(block.waitForExistence(timeout: 20), "Pro con la IA aceptada no vio el bloque de la IA.")
        XCTAssertTrue(element(app, "insights_ant_expenses_ai_merge").exists, "La IA no juntó las dos grafías.")
        XCTAssertTrue(element(app, "insights_ant_expenses_ai_tip").exists, "Falta el consejo.")
        // La tarjeta gratis sigue entera encima.
        XCTAssertTrue(element(app, "insights_ant_expenses_summary").exists)
        XCTAssertTrue(element(app, "insights_ant_expenses_row").exists)
        XCTAssertFalse(element(app, "insights_ant_expenses_ai_cta").exists)

        bringIntoView(app, card)
        attach(app, "pro-con-ia")
    }

    func test_free_seesTheSameCard_withNothingFromTheAI() {
        let app = launch(pro: false, consent: true)
        let card = element(app, "insights_ant_expenses_card")
        XCTAssertTrue(card.waitForExistence(timeout: 20), "Resumen no enseñó la tarjeta de gastos hormiga.")
        XCTAssertTrue(element(app, "insights_ant_expenses_row").exists)
        // Tiempo para que la decisión automática corriera si fuera a correr (espera de calma de 1,2 s).
        XCTAssertFalse(element(app, "insights_ant_expenses_ai").waitForExistence(timeout: 5), "Free vio el bloque de la IA.")
        XCTAssertFalse(element(app, "insights_ant_expenses_ai_cta").exists, "Free vio una invitación a la IA.")

        bringIntoView(app, card)
        attach(app, "free")
    }

    func test_proWithoutConsent_tapsTheButton_acceptsAndSeesTheBlock() {
        let app = launch(pro: true, consent: false)
        let cta = element(app, "insights_ant_expenses_ai_cta")
        XCTAssertTrue(cta.waitForExistence(timeout: 20), "Pro sin permiso no vio el botón de la IA en la tarjeta.")
        XCTAssertFalse(element(app, "insights_ant_expenses_ai").exists, "Sin permiso no se pide nada a la IA.")
        bringIntoView(app, cta)
        attach(app, "pro-sin-permiso")
        cta.tap()

        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "No se pidió el permiso de la IA.")
        attach(app, "permiso")
        alert.buttons.element(boundBy: 0).tap()

        XCTAssertTrue(element(app, "insights_ant_expenses_ai").waitForExistence(timeout: 15),
                      "Tras aceptar, no salió el bloque de la IA.")
        XCTAssertFalse(element(app, "insights_ant_expenses_ai_cta").exists)
    }
}
