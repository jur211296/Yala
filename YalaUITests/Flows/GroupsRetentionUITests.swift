//
//  GroupsRetentionUITests.swift
//  YalaUITests
//
//  D1 — Retención «Seguir con mis grupos» (§3.3.2). El flujo REAL (Vaciar → 2ª confirmación →
//  wipe destructivo → cover raíz → cambio de shell) depende del alert localizado y del wipe; el
//  seam `-uitest-retention-demo` (#if DEBUG-inerte en release vía hasArg) ARMA el cover de
//  retención al arrancar (con deuda) SIN ejecutar el wipe, para cubrir el CABLEADO/UI de la
//  bifurcación de forma determinista. La lógica pura va por unit tests (ShellModeLogicTests,
//  TabBarConfigurationSecondaryTests, ContentViewReadinessLogicTests).
//  Convenciones: sin sleeps, scheme Yala Dev, targeting por accessibilityIdentifier.
//

import XCTest

final class GroupsRetentionUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Con el seam demo: el cover de retención aparece con AMBAS opciones; «Solo mis grupos»
    /// reduce la shell (la tab bar cae a Grupos + Más + Buscar = 3 tabs).
    func test_retention_screenAppears_andGroupsOnlyReducesShell() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "grupos", extraArguments: ["-uitest-retention-demo"])
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        let groupsOnly = app.buttons["retention_groups_only"]
        XCTAssertTrue(groupsOnly.waitForExistence(timeout: 10),
                      "No apareció la pantalla de retención (retention_groups_only).")
        XCTAssertTrue(app.buttons["retention_start_fresh"].exists,
                      "La salida «Empezar de cero» debe estar igual de accesible (no dark pattern).")

        groupsOnly.tap()

        XCTAssertTrue(groupsOnly.waitForNonExistence(timeout: 10),
                      "El cover de retención no se cerró tras elegir «Solo mis grupos».")
        // Shell reducida: Grupos + Más + Buscar = 3 tabs (vs 5 en la app completa).
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10), "No se montó la tab bar reducida.")
        XCTAssertEqual(app.tabBars.buttons.count, 3,
                       "La shell no se redujo a solo Grupos (+ Más + Buscar).")
    }

    /// «Empezar de cero» también cierra el cover (la elección se procesa en el onDismiss).
    func test_retention_startFresh_dismissesCover() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "grupos", extraArguments: ["-uitest-retention-demo"])
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        let startFresh = app.buttons["retention_start_fresh"]
        XCTAssertTrue(startFresh.waitForExistence(timeout: 10),
                      "No apareció la pantalla de retención (retention_start_fresh).")
        startFresh.tap()

        XCTAssertTrue(startFresh.waitForNonExistence(timeout: 10),
                      "El cover de retención no se cerró tras elegir «Empezar de cero».")
    }
}
