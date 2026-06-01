//
//  LaunchSliceUITests.swift
//  YalaUITests
//
//  Vertical slice F3 — prueba la espina dorsal de la infra de QA autónomo:
//  launch args (-uitest), seam de aislamiento sin CloudKit, skip-onboarding,
//  seed y la señal uitest_ready. Si esto pasa, F1a funciona en runtime.
//

import XCTest

final class LaunchSliceUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Lanza con reset + skip-onboarding + seed minimal + Pro y verifica que la app
    /// arranca en MainTabView (sin tocar CloudKit ni onboarding).
    func test_launchesIntoMainTabWithSeed() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true)

        XCTAssertTrue(
            app.waitForUITestReady(),
            "El root nunca expuso uitest_ready — bootstrap/seed no completó en modo uitest."
        )
        XCTAssertTrue(
            app.tabBars.firstMatch.waitForExistence(timeout: 10),
            "No se montó MainTabView (¿el skip-onboarding no aplicó?)."
        )
    }

    /// Perfil `grupos`: el seed de grupo compartido (DevSeedGroups) completa sin crash
    /// y la app queda lista. El display del tab Grupos se valida en device QA.
    func test_launchesWithGroupsSeed() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "grupos")
        XCTAssertTrue(app.waitForUITestReady(), "El seed 'grupos' no completó (uitest_ready ausente).")
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10), "MainTabView no se montó con seed grupos.")
    }
}
