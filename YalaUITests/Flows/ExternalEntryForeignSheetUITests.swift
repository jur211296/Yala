//
//  ExternalEntryForeignSheetUITests.swift
//  YalaUITests
//
//  Entrar a Yala desde fuera con una hoja abierta en OTRA pestaña no la cierra (ticket
//  entry-to-panel-closes-sheets-of-other-tabs). Medido el 2026-10-11 (iPhone 17 Pro, iOS 27.0): ir al Panel cambia la
//  pestaña por debajo y la hoja sigue abierta; lo que la cerraba era lo que el Panel PRESENTABA después (la lectura de
//  una foto compartida), porque su candado solo miraba sus propias hojas. Un «Nuevo registro» a medias en Estadísticas
//  se perdía sin aviso. Ahora el Panel espera a que la ventana no tenga nada presentado.
//  Los enlaces se abren con `XCUIDevice.shared.system.open`, como los abriría otra app o un widget:
//  `XCUIApplication.open(_:)` relanza la app (regla de `.claude/rules/testing.md`). Scheme `Yala Dev` ⇒ `yaladev://`.
//

import XCTest

final class ExternalEntryForeignSheetUITests: XCTestCase {
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

    /// Lanza, va a Estadísticas y deja «Nuevo registro» abierto con `1234` escrito. Devuelve el campo del importe.
    private func launchWithHalfFilledFormInStatistics() -> (XCUIApplication, XCUIElement) {
        let app = XCUIApplication()
        // Pro y consentimiento: la foto compartida va directa a la lectura, sin la hoja de Pro ni la del consentimiento.
        app.launchForUITest(pro: true, aiConsent: true, extraArguments: ["-uitest-image-result", "one"])
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

        XCUIDevice.shared.press(.home)
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 15), "Yala no pasó a segundo plano.")
        return (app, amountField)
    }

    /// Espera `seconds` a que el formulario desaparezca; lo correcto es que la espera se agote. Deja una captura de lo
    /// que ve la persona en ese momento (las del antes/después del PR).
    private func assertFormSurvives(
        _ app: XCUIApplication, _ amountField: XCUIElement, seconds: TimeInterval, capture: String,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        let closes = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: amountField)
        let waited = XCTWaiter().wait(for: [closes], timeout: seconds)
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = capture
        shot.lifetime = .keepAlways
        add(shot)
        XCTAssertEqual(waited, .timedOut,
                       "La entrada desde fuera cerró el Nuevo registro que estaba a medias en Estadísticas.",
                       file: file, line: line)
        let typed = (amountField.value as? String) ?? ""
        XCTAssertTrue(typed.contains("1234") || typed.contains("1.234") || typed.contains("1,234"),
                      "El importe escrito se perdió (valor: «\(typed)»).", file: file, line: line)
    }

    private func closeForm(_ app: XCUIApplication) {
        let close = app.buttons["new_transaction_close"]
        XCTAssertTrue(close.waitForExistence(timeout: 5), "Falta la X de Nuevo registro (new_transaction_close).")
        close.tap()
    }

    /// El caso que perdía datos: la foto compartida lleva al Panel y el Panel presentaba la lectura encima, lo que
    /// cerraba el formulario de Estadísticas. Ahora la lectura espera y arranca al cerrar el formulario.
    func test_halfFilledFormInAnotherTab_sharedPhoto_keepsTheFormAndReadsWhenClosed() {
        let (app, amountField) = launchWithHalfFilledFormInStatistics()
        openFromOutside("yaladev://shared-image?uitest-stage=readable")
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15), "La foto compartida no trajo Yala delante.")

        assertFormSurvives(app, amountField, seconds: 10, capture: "formulario-tras-compartir-foto")
        closeForm(app)
        XCTAssertTrue(app.staticTexts["image_review_title"].waitForExistence(timeout: 30),
                      "Al cerrar el formulario, la foto compartida tenía que leerse (image_review_title).")
    }

    /// Ir al Panel desde fuera, sin nada que presentar, nunca cerró la hoja (medido el 2026-10-11): la pestaña cambia
    /// por debajo y la hoja sigue. Red de esa medida, para que un cambio en la navegación no la rompa.
    func test_halfFilledFormInAnotherTab_panelLink_keepsTheForm() {
        let (app, amountField) = launchWithHalfFilledFormInStatistics()
        openFromOutside("yaladev://panel")
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15), "El enlace no trajo Yala delante.")

        assertFormSurvives(app, amountField, seconds: 6, capture: "formulario-tras-enlace-al-panel")
        closeForm(app)
        let panelTab = app.tabBars.buttons.element(boundBy: 0)
        let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isSelected == true"), object: panelTab)
        XCTAssertEqual(XCTWaiter().wait(for: [selected], timeout: 10), .completed,
                       "Tras cerrar la hoja, el enlace tenía que haber dejado el Panel delante.")
    }
}
