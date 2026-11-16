//
//  GroupsOnboardingCloseUITests.swift
//  YalaUITests
//
//  Card imbk (lote 2.3 · UI): la bienvenida de Grupos volvía en CADA entrada si se cerraba con la X. Decisión de Jürgen
//  (2026-11-06, opción B): la primera X la aplaza —vuelve en la siguiente entrada— y la segunda la da por vista.
//
//  Cada «entrada» es volver a la pestaña Grupos dentro del mismo arranque: se aterriza por deeplink y, para volver, se sale
//  a Panel y se abre `yaladev://groups` desde fuera con la app viva (Grupos no está en la barra por defecto y la pestaña
//  temporal se va al salir). Con la X sin efecto, la tercera entrada vuelve a enseñar la hoja y el caso cae (medido con
//  el mutante el 2026-11-06).
//

import XCTest

final class GroupsOnboardingCloseUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    func test_closingWithX_postponesOnce_andTheSecondXMarksItSeen() {
        let app = XCUIApplication()
        app.launchForUITest(deeplink: "groups", groupsEducativo: true)
        XCTAssertTrue(app.waitForUITestReady(timeout: 90), "uitest_ready ausente — bootstrap/seed no completó.")

        // 1.ª entrada: sale y se cierra con la X.
        closeTheWelcome(app, entry: "primera")

        // 2.ª entrada: vuelve una vez más, y se cierra con la X.
        reenterGroups(app)
        closeTheWelcome(app, entry: "segunda")

        // 3.ª entrada: ya no sale.
        reenterGroups(app)
        let close = app.buttons["groups_onboarding_close"]
        let cameBack = close.waitForExistence(timeout: 8)
        capture(app, "tercera-entrada")
        XCTAssertFalse(cameBack, "Tras dos cierres con la X, la bienvenida de Grupos volvió a salir.")
    }

    /// Sale a Panel y vuelve a Grupos por un enlace abierto desde fuera, con la app viva (`system.open`; `app.open`
    /// relanzaría). Grupos no está en la barra por defecto y la pestaña temporal se va al salir a Panel.
    private func reenterGroups(_ app: XCUIApplication) {
        let panel = app.tabEntry(.panel)
        XCTAssertTrue(panel.waitForExistence(timeout: 10), "No está la pestaña Panel.")
        panel.tap()
        guard let url = URL(string: "yaladev://groups") else { return XCTFail("URL inválida") }
        XCUIDevice.shared.system.open(url)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let open = springboard.alerts.buttons.element(boundBy: 1)
        if springboard.alerts.firstMatch.waitForExistence(timeout: 3), open.exists { open.tap() }
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15), "El enlace no trajo Yala delante.")
        let groups = app.tabEntry(.groups)
        XCTAssertTrue(groups.waitForExistence(timeout: 10), "El enlace no volvió a Grupos.")
        let selected = expectation(for: NSPredicate(format: "isSelected == true"), evaluatedWith: groups)
        wait(for: [selected], timeout: 10)
    }

    /// Con `YALA_CAPTURES` (vía `TEST_RUNNER_YALA_CAPTURES`) guarda la captura en disco para la evidencia.
    private func capture(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
        guard let dir = ProcessInfo.processInfo.environment["YALA_CAPTURES"], !dir.isEmpty else { return }
        do {
            try app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
        } catch {
            #if DEBUG
            print("GroupsOnboardingCloseUITests: Error: \(error)")
            #endif
        }
    }

    private func closeTheWelcome(_ app: XCUIApplication, entry: String) {
        let close = app.buttons["groups_onboarding_close"]
        XCTAssertTrue(close.waitForExistence(timeout: 20), "En la \(entry) entrada no salió la bienvenida de Grupos.")
        close.tap()
        XCTAssertTrue(close.waitForNonExistence(timeout: 10), "La X no cerró la bienvenida en la \(entry) entrada.")
    }
}
