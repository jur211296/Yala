//
//  ShellNoticeOverSettingsUITests.swift
//  YalaUITests
//
//  Card ulks (lote N1 de la 2.3): «Con Ajustes abierto, un aviso importante (cambio de Apple ID, vaciado remoto) puede
//  perderse hasta el siguiente arranque». Decisión de Jürgen del 2026-11-04 (opción A): el aviso crítico cierra Ajustes y
//  sale al momento (`RouterConsumerGateLogic.closesSettingsFirst`); con otras hojas, los críticos siguen como el 11-oct.
//  El aviso se pide con Yala delante y Ajustes abierto por el seam `<scheme>://uitest-notice?kind=…`
//  (`UITestRouterNoticeStage`), que solo encola el intent por la puerta de siempre.
//

import XCTest

final class ShellNoticeOverSettingsUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func openFromOutside(_ url: String) {
        guard let url = URL(string: url) else { return XCTFail("URL inválida: \(url)") }
        XCUIDevice.shared.system.open(url)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let open = springboard.alerts.buttons.element(boundBy: 1)
        if springboard.alerts.firstMatch.waitForExistence(timeout: 3), open.exists { open.tap() }
    }

    /// Lanza con datos y deja Ajustes abierto.
    private func launchWithSettingsOpen() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(seed: "minimal")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap no completó.")
        app.openProfile()
        // Con Ajustes delante el avatar del Panel sigue en el árbol pero deja de ser alcanzable (regla de `testing.md`).
        let covered = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == false"),
                                                object: app.buttons["profile_avatar"])
        XCTAssertEqual(XCTWaiter().wait(for: [covered], timeout: 10), .completed, "Ajustes no se abrió.")
        return app
    }

    /// La hoja «Cambiaste de cuenta de iCloud» pedida con Ajustes abierto tiene que llegar a verse.
    func test_appleIDChangedNotice_withSettingsOpen_reachesTheScreen() {
        let app = launchWithSettingsOpen()
        openFromOutside("yaladev://uitest-notice?kind=apple-id-changed")
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15), "El enlace no trajo Yala delante.")

        let asking = app.descendants(matching: .any).matching(identifier: "apple_id_close_asking").firstMatch
        let shown = asking.waitForExistence(timeout: 30)
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "apple-id-con-ajustes"
        shot.lifetime = .keepAlways
        add(shot)
        XCTAssertTrue(shown, "Con Ajustes abierto, la hoja del cambio de Apple ID no llegó a verse.")
        XCTAssertTrue(app.buttons["apple_id_close_later"].isHittable, "La hoja salió pero no quedó delante.")

        // Decisión A (2026-11-04): el aviso cerró Ajustes. Al contestar, debajo está el Panel, no Ajustes.
        app.buttons["apple_id_close_later"].tap()
        XCTAssertTrue(asking.waitForNonExistence(timeout: 10), "La hoja no se cerró con «Ahora no».")
        XCTAssertTrue(app.buttons["profile_avatar"].waitForHittable(timeout: 10),
                      "Tras contestar el aviso, Ajustes seguía abierto: el aviso no lo cerró antes de salir.")
        // Y se cerró bien: quien lo abrió no se quedó con su hoja «puesta». Si UIKit la tumbó por debajo sin que SwiftUI
        // bajara la bandera, el avatar ya no abre Ajustes (la bandera sigue en `true` y no cambia).
        app.buttons["profile_avatar"].tap()
        let reopened = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == false"),
                                                 object: app.buttons["profile_avatar"])
        XCTAssertEqual(XCTWaiter().wait(for: [reopened], timeout: 10), .completed,
                       "Tras el aviso, el avatar ya no abre Ajustes: su hoja quedó pegada.")
    }

    /// El aviso de «la cuenta de iCloud cambió» (un `.alert` del shell) pedido con Ajustes abierto.
    func test_iCloudMismatchNotice_withSettingsOpen_reachesTheScreen() {
        let app = launchWithSettingsOpen()
        openFromOutside("yaladev://uitest-notice?kind=icloud-mismatch")
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15), "El enlace no trajo Yala delante.")
        let shown = app.alerts.firstMatch.waitForExistence(timeout: 30)
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "icloud-mismatch-con-ajustes"
        shot.lifetime = .keepAlways
        add(shot)
        XCTAssertTrue(shown, "Con Ajustes abierto, el aviso de la cuenta de iCloud no llegó a verse.")
    }
}
