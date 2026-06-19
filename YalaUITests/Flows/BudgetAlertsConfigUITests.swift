//
//  BudgetAlertsConfigUITests.swift
//  YalaUITests
//
//  Cobertura XCUITest del área `budget-alerts-configuration` (escenarios 6.x de
//  alertas): dentro del editor de presupuesto, activar el toggle de alertas
//  revela los chips de umbral (50/75/90/100) y seleccionar uno lo marca.
//  Verificación in-place en el editor nuevo (el toggle es condicional: los chips
//  solo se montan con `alertEnabled == true`). Lanza en modo Pro para saltar el
//  FeatureGate de creación de presupuestos. Seed `minimal`.
//  Convenciones: ver CLAUDE.md (sin sleeps, scheme Yala Dev).
//

import XCTest

final class BudgetAlertsConfigUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Navega al tab Planificación (3er tab del config por defecto
    /// `[panel, statistics, planning]`, por índice para no acoplar al label) y
    /// abre el editor de un presupuesto nuevo (FAB de crear → BudgetEditorView).
    private func openNewBudgetEditor(_ app: XCUIApplication) {
        let planningTab = app.tabBars.buttons.element(boundBy: 2)
        XCTAssertTrue(planningTab.waitForExistence(timeout: 10), "No apareció el tab Planificación.")
        planningTab.tap()

        let fab = app.buttons["budgets_create_fab"]
        XCTAssertTrue(fab.waitForExistence(timeout: 5), "No apareció budgets_create_fab.")
        fab.tap()

        XCTAssertTrue(
            app.textFields["budget_name_field"].waitForExistence(timeout: 5),
            "No se montó BudgetEditorView (budget_name_field)."
        )
    }

    /// El `Toggle` de SwiftUI expone un Switch contenedor que abarca todo el row;
    /// su centro cae en el label y no togglea → tocar el sub-switch real cuando
    /// existe (patrón de panel-dashboard-logic), con fallback al contenedor.
    private func toggleSwitch(_ app: XCUIApplication, id: String) {
        let container = app.switches[id]
        XCTAssertTrue(container.waitForExistence(timeout: 5), "No apareció el switch '\(id)'.")
        let inner = container.switches.firstMatch
        if inner.exists {
            inner.tap()
        } else {
            container.tap()
        }
    }

    /// Activar el toggle de alertas revela los chips de umbral (que están ocultos
    /// mientras `alertEnabled == false`).
    func test_enablingAlertsRevealsThresholds() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        openNewBudgetEditor(app)

        // Con alertEnabled=false los chips no se montan todavía.
        XCTAssertFalse(
            app.buttons["budget_alert_threshold_50"].exists,
            "Los chips de umbral no deberían existir antes de activar las alertas."
        )

        toggleSwitch(app, id: "budget_alert_toggle")

        // Tras activar, la sección revela los chips (50/75/90/100).
        XCTAssertTrue(
            app.buttons["budget_alert_threshold_50"].waitForExistence(timeout: 5),
            "No aparecieron los chips de umbral tras activar las alertas."
        )
        XCTAssertTrue(
            app.buttons["budget_alert_threshold_75"].exists,
            "Falta el chip de umbral 75%."
        )
    }

    /// Seleccionar un chip de umbral lo marca (`.isSelected`). El re-render del
    /// binding @State es asíncrono → esperar el snapshot con predicate, no leerlo
    /// de inmediato.
    func test_selectingThresholdMarksItSelected() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        openNewBudgetEditor(app)
        toggleSwitch(app, id: "budget_alert_toggle")

        let chip = app.buttons["budget_alert_threshold_75"]
        XCTAssertTrue(chip.waitForExistence(timeout: 5), "No apareció el chip de umbral 75%.")
        XCTAssertFalse(chip.isSelected, "El chip 75% no debería estar seleccionado al inicio.")

        chip.tap()

        let selected = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isSelected == true"),
            object: chip
        )
        XCTAssertEqual(
            XCTWaiter().wait(for: [selected], timeout: 5),
            .completed,
            "El chip de umbral 75% no quedó seleccionado tras el tap."
        )
    }
}
