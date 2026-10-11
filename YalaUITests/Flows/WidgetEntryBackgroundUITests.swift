//
//  WidgetEntryBackgroundUITests.swift
//  YalaUITests
//
//  Una entrada de widget o Siri (`voice-entry`, `new-transaction`) que la app aún no ha presentado sobrevive a un paso
//  a segundo plano (ticket `widget-and-siri-entries-lost-on-background`). Estas entradas no llevan al Panel: con otra
//  pestaña delante esperan a que la persona vuelva a él. Hasta el 2026-10-11, si entre medias la app salía a segundo
//  plano, `AppRouter.resetTransients` las tiraba y el toque del widget no había servido de nada.
//  Los enlaces se abren con `XCUIDevice.shared.system.open`, como los abriría un widget: `XCUIApplication.open(_:)`
//  relanza la app (regla de `.claude/rules/testing.md`). Scheme `Yala Dev` ⇒ `yaladev://`.
//

import XCTest

final class WidgetEntryBackgroundUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Abre `url` por el sistema. Si SpringBoard pregunta «¿Abrir en …?», se acepta (molde de `SharedImageEntryUITests`).
    private func openFromOutside(_ url: String) {
        guard let url = URL(string: url) else { return XCTFail("URL inválida: \(url)") }
        XCUIDevice.shared.system.open(url)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let open = springboard.alerts.buttons.element(boundBy: 1)
        if springboard.alerts.firstMatch.waitForExistence(timeout: 3), open.exists { open.tap() }
    }

    private func sendToBackground(_ app: XCUIApplication, _ when: String) {
        XCUIDevice.shared.press(.home)
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 15), "Yala no pasó a segundo plano \(when).")
    }

    /// Lanza, deja Estadísticas delante, abre `url` desde fuera (la entrada queda esperando al Panel), sale otra vez a
    /// segundo plano y vuelve. Devuelve la app ya de vuelta, todavía en Estadísticas.
    private func entryWaitsThenAppGoesAwayAndBack(_ url: String, extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        // Pro y consentimiento: la voz va directa a su hoja, sin la de Pro ni la del consentimiento.
        app.launchForUITest(pro: true, aiConsent: true, extraArguments: extraArguments)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        // Estadísticas es el 2.º tab del config default [panel, statistics, planning].
        let statsTab = app.tabBars.buttons.element(boundBy: 1)
        XCTAssertTrue(statsTab.waitForExistence(timeout: 10), "No apareció el tab Estadísticas.")
        statsTab.tap()

        sendToBackground(app, "antes del enlace")
        openFromOutside(url)
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15), "El enlace no trajo Yala delante.")

        sendToBackground(app, "con la entrada esperando")
        app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15), "Yala no volvió a primer plano.")
        return app
    }

    private func goToPanel(_ app: XCUIApplication) {
        let panelTab = app.tabBars.buttons.element(boundBy: 0)
        XCTAssertTrue(panelTab.waitForExistence(timeout: 10), "No apareció el tab Panel.")
        panelTab.tap()
    }

    func test_voiceEntryWaitingForThePanel_survivesTheBackground() {
        let app = entryWaitsThenAppGoesAwayAndBack(
            "yaladev://voice-entry", extraArguments: ["-uitest-voice-result", "one"])
        goToPanel(app)
        XCTAssertTrue(app.buttons["voice_done"].waitForExistence(timeout: 15),
                      "Al volver al Panel, la voz pedida desde el widget antes de salir tenía que abrirse (voice_done).")
    }

    func test_newTransactionWaitingForThePanel_survivesTheBackground() {
        let app = entryWaitsThenAppGoesAwayAndBack("yaladev://new-transaction")
        goToPanel(app)
        XCTAssertTrue(app.textFields["new_transaction_amount"].waitForExistence(timeout: 15),
                      "Al volver al Panel, el Nuevo registro pedido desde el widget tenía que abrirse.")
    }
}
