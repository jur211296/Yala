//
//  WidgetEntryToPanelUITests.swift
//  YalaUITests
//
//  Voz, imagen o nuevo registro pedidos desde fuera (widget de entrada rápida, «Registrar con Siri», Centro de Control)
//  llevan al Panel y abren su hoja ahí, como la foto compartida (ticket `widget-and-siri-entries-wait-for-the-panel-tab`,
//  decisión de Jürgen del 2026-10-12). Hasta ese día, con Estadísticas delante, el toque traía Yala y no pasaba nada:
//  la hoja esperaba a que la persona volviera al Panel por su cuenta.
//  Los enlaces se abren con `XCUIDevice.shared.system.open`, como los abriría un widget: `XCUIApplication.open(_:)`
//  relanza la app (regla de `.claude/rules/testing.md`). Scheme `Yala Dev` ⇒ `yaladev://`.
//

import XCTest

final class WidgetEntryToPanelUITests: XCTestCase {
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

    /// Lanza con Pro y consentimiento (la hoja pedida sale directa, sin la de Pro ni la del consentimiento), deja
    /// Estadísticas delante, sale a segundo plano y abre `url` desde fuera.
    private func openFromStatistics(_ url: String, extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, aiConsent: true, extraArguments: extraArguments)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        // Estadísticas es el 2.º tab del config default [panel, statistics, planning].
        let statsTab = app.tabBars.buttons.element(boundBy: 1)
        XCTAssertTrue(statsTab.waitForExistence(timeout: 10), "No apareció el tab Estadísticas.")
        statsTab.tap()

        XCUIDevice.shared.press(.home)
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 15), "Yala no pasó a segundo plano.")
        openFromOutside(url)
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15), "El enlace no trajo Yala delante.")
        return app
    }

    /// La hoja pedida aparece y debajo queda el Panel. Deja la captura de lo que ve la persona (antes/después del PR).
    private func assertOpensOnThePanel(
        _ app: XCUIApplication, _ sheetElement: XCUIElement, what: String, capture: String,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        let appeared = sheetElement.waitForExistence(timeout: 15)
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = capture
        shot.lifetime = .keepAlways
        add(shot)
        XCTAssertTrue(appeared, "Con Estadísticas delante, \(what) pedido desde el widget tenía que abrirse.",
                      file: file, line: line)
        XCTAssertTrue(app.tabBars.buttons.element(boundBy: 0).isSelected,
                      "Debajo de la hoja tenía que quedar el Panel.", file: file, line: line)
    }

    func test_voiceEntryFromStatistics_goesToThePanelAndOpens() {
        let app = openFromStatistics("yaladev://voice-entry", extraArguments: ["-uitest-voice-result", "one"])
        assertOpensOnThePanel(app, app.buttons["voice_done"], what: "el dictado", capture: "voz-desde-estadisticas")
    }

    func test_imageEntryFromStatistics_goesToThePanelAndOpens() {
        let app = openFromStatistics("yaladev://image-entry")
        assertOpensOnThePanel(app, app.buttons["image_close"], what: "el registro por imagen",
                              capture: "imagen-desde-estadisticas")
    }

    /// Lote 15 de la auditoría UX 2.2: en una sesión solo grupos no hay Panel. El toque del widget «Nuevo registro»
    /// abría Yala en Grupos y no pasaba nada; ahora ofrece activar Yala completo, como el toque de un widget de datos.
    func test_newTransactionInAGroupsOnlySession_offersToActivateFullYala() {
        let app = XCUIApplication()
        app.launchForUITest(groupInvite: true)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        XCUIDevice.shared.press(.home)
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 15), "Yala no pasó a segundo plano.")
        openFromOutside("yaladev://new-transaction")
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15), "El enlace no trajo Yala delante.")

        let activation = app.buttons["onboarding_next_button"]
        let appeared = activation.waitForExistence(timeout: 15)
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "nuevo-registro-en-solo-grupos"
        shot.lifetime = .keepAlways
        add(shot)
        XCTAssertTrue(appeared, "En solo grupos, el widget «Nuevo registro» tenía que ofrecer activar Yala completo.")
    }

    func test_newTransactionFromStatistics_goesToThePanelAndOpens() {
        let app = openFromStatistics("yaladev://new-transaction")
        assertOpensOnThePanel(app, app.textFields["new_transaction_amount"], what: "el Nuevo registro",
                              capture: "nuevo-registro-desde-estadisticas")
    }
}
