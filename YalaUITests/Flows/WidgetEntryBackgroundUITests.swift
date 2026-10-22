//
//  WidgetEntryBackgroundUITests.swift
//  YalaUITests
//
//  Una entrada de widget o Siri (`voice-entry`, `new-transaction`) que la app aún no ha presentado sobrevive a un paso
//  a segundo plano (ticket `widget-and-siri-entries-lost-on-background`). Hasta el 2026-10-11, si entre medias la app
//  salía a segundo plano, `AppRouter.resetTransients` las tiraba y el toque del widget no había servido de nada.
//  Desde el 2026-10-12 estas entradas llevan al Panel (ticket `widget-and-siri-entries-wait-for-the-panel-tab`), así que
//  ya no esperan en Estadísticas: lo que las deja esperando es un «Nuevo registro» a medias en otra pestaña, que el Panel
//  no tapa (#453). Es ese caso el que sale y vuelve.
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

    /// Lanza, deja «Nuevo registro» a medias en Estadísticas, abre `url` desde fuera (la pestaña cambia al Panel por
    /// debajo y la entrada espera a que se cierre el formulario), sale otra vez a segundo plano y vuelve. Devuelve la app
    /// ya de vuelta, con el formulario todavía abierto, y su campo del importe.
    private func entryWaitsBehindAFormThenAppGoesAwayAndBack(
        _ url: String, extraArguments: [String] = []
    ) -> (XCUIApplication, XCUIElement) {
        let app = XCUIApplication()
        // Pro y consentimiento: la voz va directa a su hoja, sin la de Pro ni la del consentimiento.
        app.launchForUITest(pro: true, aiConsent: true, extraArguments: extraArguments)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        // Estadísticas es el 2.º tab del config default [panel, statistics, planning].
        let statsTab = app.tabBars.buttons.element(boundBy: 1)
        XCTAssertTrue(statsTab.waitForExistence(timeout: 10), "No apareció el tab Estadísticas.")
        statsTab.tap()

        let fabMenu = app.buttons["fab_new_transaction"]
        XCTAssertTrue(fabMenu.waitForExistence(timeout: 10), "Falta el «+» de Estadísticas (fab_new_transaction).")
        fabMenu.tap()
        let manual = app.buttons["fab_manual"]
        XCTAssertTrue(manual.waitForExistence(timeout: 5), "No se expandió el menú del «+» (fab_manual).")
        manual.tap()
        let amountField = app.textFields["new_transaction_amount"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 10), "No se abrió Nuevo registro (new_transaction_amount).")
        amountField.tap()
        amountField.typeText("1234")

        sendToBackground(app, "antes del enlace")
        openFromOutside(url)
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15), "El enlace no trajo Yala delante.")

        sendToBackground(app, "con la entrada esperando")
        app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15), "Yala no volvió a primer plano.")
        XCTAssertTrue(amountField.waitForExistence(timeout: 10),
                      "El formulario a medias de Estadísticas tenía que seguir abierto al volver.")
        return (app, amountField)
    }

    private func closeForm(_ app: XCUIApplication) {
        let close = app.buttons["new_transaction_close"]
        XCTAssertTrue(close.waitForExistence(timeout: 5), "Falta la X de Nuevo registro (new_transaction_close).")
        close.tap()
    }

    private func assertPanelSelected(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(app.tabBars.buttons.element(boundBy: 0).isSelected,
                      "La entrada del widget tenía que haber dejado el Panel delante.", file: file, line: line)
    }

    func test_voiceEntryWaitingForThePanel_survivesTheBackground() {
        let (app, _) = entryWaitsBehindAFormThenAppGoesAwayAndBack(
            "yaladev://voice-entry", extraArguments: ["-uitest-voice-result", "one"])
        closeForm(app)
        XCTAssertTrue(app.buttons["voice_done"].waitForExistence(timeout: 15),
                      "Al cerrar el formulario, la voz pedida desde el widget antes de salir tenía que abrirse (voice_done).")
        assertPanelSelected(app)
    }

    func test_newTransactionWaitingForThePanel_survivesTheBackground() {
        let (app, amountField) = entryWaitsBehindAFormThenAppGoesAwayAndBack("yaladev://new-transaction")
        closeForm(app)
        // El Nuevo registro del widget es una hoja nueva: sale vacía, no con el 1234 del formulario cerrado. No se
        // espera a ver el hueco entre las dos: la del widget se abre en cuanto se cierra la otra, a veces antes de que
        // XCUITest lo vea (como en `SharedImageEntryUITests#test_background_twice_bothStartReading`).
        let emptyForm = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND NOT (value CONTAINS '234')"), object: amountField)
        XCTAssertEqual(XCTWaiter().wait(for: [emptyForm], timeout: 15), .completed,
                       "Al cerrar el formulario, el Nuevo registro pedido desde el widget tenía que abrirse vacío "
                       + "(valor: «\((amountField.value as? String) ?? "")»).")
        assertPanelSelected(app)
    }
}
