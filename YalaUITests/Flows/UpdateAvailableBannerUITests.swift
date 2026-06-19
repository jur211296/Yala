//
//  UpdateAvailableBannerUITests.swift
//  YalaUITests
//
//  Cobertura XCUITest del área `update-available-banner` (escenarios 50.x): el
//  banner que avisa de una versión nueva en el App Store. Normalmente lo gatilla
//  `AppUpdateService.checkForUpdate()` (URLSession a iTunes); el hook
//  `-uitest-force-update` fuerza el estado "hay update" sin red, volviendo el
//  banner determinista (display + interacción + dismiss). La DETECCIÓN real por
//  red (50.1 mecanismo / 50.4 cache) queda fuera del XCUITest (manual).
//  Convenciones: ver CLAUDE.md (sin sleeps, page-objects, scheme Yala Dev).
//

import XCTest

final class UpdateAvailableBannerUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// El banner se muestra en el Panel cuando hay un update disponible (forzado).
    func test_updateBannerShowsOnPanel() {
        let app = XCUIApplication()
        app.launchForUITest(forceUpdate: true)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        XCTAssertTrue(
            app.buttons["update_banner_action"].waitForExistence(timeout: 5),
            "No se mostró el UpdateAvailableBanner (update_banner_action ausente)."
        )
    }

    /// Descartar el banner lo oculta (dismissedInSession).
    func test_updateBannerDismisses() {
        let app = XCUIApplication()
        app.launchForUITest(forceUpdate: true)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        let action = app.buttons["update_banner_action"]
        XCTAssertTrue(action.waitForExistence(timeout: 5), "No apareció el banner.")

        let dismiss = app.buttons["update_banner_dismiss"]
        XCTAssertTrue(dismiss.waitForExistence(timeout: 5), "No apareció el botón de descartar del banner.")
        dismiss.tap()

        XCTAssertTrue(
            action.waitForNonExistence(timeout: 5),
            "El banner no se ocultó al descartar."
        )
    }
}
