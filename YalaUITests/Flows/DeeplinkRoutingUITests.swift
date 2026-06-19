//
//  DeeplinkRoutingUITests.swift
//  YalaUITests
//
//  Cobertura XCUITest del área `deeplinks-tab-routing` (DL-03/DL-04): un deeplink
//  externo navega directo al tab destino, incluido un tab OCULTO en "Más"
//  (el bug review-deeplinks: el TabView nativo exige que `Tab(value:)` esté
//  montado en el mismo tick → patrón temporaryTab en `selectMainTab`).
//  Usa el hook `-uitest-deeplink <target>` (vía `launchForUITest(deeplink:)`) que
//  encola `RouterIntent.navigate(...)` tras el seed; el RouterEntryGate lo drena
//  cuando el routing está listo. La decisión de tab (visible vs oculto) ya tiene
//  cobertura pure-logic en MainTabSelectionLogicTests; esto valida el wiring e2e.
//  Convenciones: ver CLAUDE.md (sin sleeps, scheme Yala Dev).
//

import XCTest

final class DeeplinkRoutingUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// DL-03: deeplink a un tab OCULTO (Grupos, fuera del config default) navega
    /// directo a su vista, sin pasar por el menú "Más".
    func test_deeplinkToHiddenGroupsTabNavigatesDirect() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "grupos", deeplink: "groups")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        // Sin tocar "Más": el deeplink monta GroupsContainerView con el grupo sembrado.
        XCTAssertTrue(
            app.descendants(matching: .any).matching(identifier: "group_card").firstMatch.waitForExistence(timeout: 15),
            "El deeplink a Grupos (tab oculto) no navegó directo a la vista de grupos."
        )
    }

    /// DL-04: deeplink a un tab VISIBLE (Estadísticas) lo selecciona al arranque.
    func test_deeplinkToVisibleStatisticsTab() {
        let app = XCUIApplication()
        app.launchForUITest(deeplink: "statistics")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        // Estadísticas es el 2º tab del config default [panel, statistics, planning].
        let statsTab = app.tabBars.buttons.element(boundBy: 1)
        XCTAssertTrue(statsTab.waitForExistence(timeout: 10), "No apareció el tab Estadísticas.")

        let selected = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isSelected == true"),
            object: statsTab
        )
        XCTAssertEqual(
            XCTWaiter().wait(for: [selected], timeout: 10),
            .completed,
            "El deeplink a Estadísticas no dejó ese tab seleccionado al arranque."
        )
    }
}
