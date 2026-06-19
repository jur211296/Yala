//
//  BudgetsCrudUITests.swift
//  YalaUITests
//
//  Cobertura XCUITest del área `budgets` (escenarios 6.x): navegación al tab
//  Planificación (sub-tab Presupuestos por defecto) y creación de un presupuesto
//  global (nombre + monto; los filtros de subcategoría/cuenta son opcionales).
//  Verifica la persistencia en la lista (budget_row_<name>). Lanza en modo Pro
//  para evitar el FeatureGate de creación. Seed `minimal`.
//  Convenciones: ver CLAUDE.md (sin sleeps, scheme Yala Dev).
//

import XCTest

final class BudgetsCrudUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Navega al tab Planificación. Es el 3er tab del config por defecto
    /// (`[panel, statistics, planning]`), targeteado por índice para no depender
    /// del label localizado. El sub-tab Presupuestos es el default de PlanningView.
    private func openPlanningBudgets(_ app: XCUIApplication) {
        let planningTab = app.tabBars.buttons.element(boundBy: 2)
        XCTAssertTrue(planningTab.waitForExistence(timeout: 10), "No apareció el tab bar / tab Planificación.")
        planningTab.tap()
    }

    /// Navegación: tab Planificación → BudgetsListView (FAB de crear visible).
    func test_opensBudgetsListFromPlanningTab() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        openPlanningBudgets(app)

        XCTAssertTrue(
            app.buttons["budgets_create_fab"].waitForExistence(timeout: 5),
            "No se montó BudgetsListView (budgets_create_fab) tras abrir el tab Planificación."
        )
    }

    /// CRUD — crear un presupuesto global (nombre + monto, periodo mensual por
    /// defecto, sin filtros) y verificar que aparece en la lista.
    func test_createBudgetAppearsInList() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        openPlanningBudgets(app)

        let fab = app.buttons["budgets_create_fab"]
        XCTAssertTrue(fab.waitForExistence(timeout: 5), "No apareció budgets_create_fab.")
        fab.tap()

        // Nombre (el editor auto-enfoca este campo para presupuestos nuevos).
        let nameField = app.textFields["budget_name_field"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "No se montó BudgetEditorView (budget_name_field).")
        nameField.tap()
        let budgetName = "QA Presupuesto"
        nameField.typeText(budgetName)

        // Monto
        let amountField = app.textFields["budget_amount_field"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 5), "No apareció budget_amount_field.")
        amountField.tap()
        amountField.typeText("200")

        // Guardar (periodo usa el default mensual; sin filtros = presupuesto global).
        let saveButton = app.buttons["toolbar_save_button"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "No apareció toolbar_save_button.")
        XCTAssertTrue(saveButton.isEnabled, "El botón guardar está deshabilitado (nombre/monto requeridos).")
        saveButton.tap()

        // Tras guardar, el sheet del editor se cierra y volvemos a BudgetsListView.
        XCTAssertTrue(
            app.buttons["budget_row_\(budgetName)"].waitForExistence(timeout: 5),
            "El presupuesto creado no apareció en la lista."
        )
    }
}
