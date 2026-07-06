//
//  GroupExpenseSuccessUITests.swift
//  YalaUITests
//
//  Cobertura XCUITest determinista del área `groups-expense-form`: crear un gasto de
//  grupo desde el detalle muestra la pantalla de éxito (GroupExpenseSuccessView).
//  Reusa el seed `grupos` (grupo "Viaje a Cusco", 3 miembros). Para evitar el requisito
//  de cuenta del Caso A (bridge ON por default), cambia el pagador a otro miembro
//  (Caso B) → canSave solo depende de monto + descripción.
//  Convenciones: ver CLAUDE.md (sin sleeps, scheme Yala Dev, targetear por identifier).
//

import XCTest

final class GroupExpenseSuccessUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "grupos")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        return app
    }

    /// Navega al tab Grupos (oculto en "Más"): tab "Más" (4º) → card Grupos del dashboard.
    private func openGroups(_ app: XCUIApplication) {
        let moreTab = app.tabBars.buttons.element(boundBy: 3)
        XCTAssertTrue(moreTab.waitForExistence(timeout: 10), "No apareció el tab Más.")
        moreTab.tap()

        let groupsRow = app.buttons["more_card_groups"]
        var attempts = 0
        while !groupsRow.exists && attempts < 8 {
            app.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(groupsRow.waitForExistence(timeout: 5), "No apareció la card Grupos en Más.")
        groupsRow.tap()
    }

    /// groups-expense-form: detalle del grupo → FAB nuevo gasto → llenar → guardar →
    /// aparece GroupExpenseSuccessView.
    func test_createGroupExpenseShowsSuccessScreen() {
        let app = launch()
        openGroups(app)

        // Detalle del grupo sembrado.
        let card = app.descendants(matching: .any).matching(identifier: "group_card").firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10), "No apareció la tarjeta del grupo.")
        card.tap()

        // FAB nuevo gasto → formulario.
        let fab = app.buttons["group_detail_fab_new_expense"]
        XCTAssertTrue(fab.waitForExistence(timeout: 10), "No apareció el FAB de nuevo gasto en el detalle.")
        fab.tap()

        // Descripción.
        let description = app.textFields["group_expense_description"]
        XCTAssertTrue(description.waitForExistence(timeout: 5), "El form no montó (group_expense_description).")
        description.tap()
        description.typeText("Cena de prueba")

        // Monto.
        let amount = app.textFields["group_expense_amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5), "No apareció el campo de monto.")
        amount.tap()
        amount.typeText("120")

        // Cambiar el pagador a otro miembro (Caso B) → evita el requisito de cuenta del Caso A
        // (bridge ON por default). Abrir el picker también cierra el teclado (patrón como en
        // TransactionsCrudUITests: tras escribir, se tocan chips que abren sheets).
        let paidBy = app.buttons["group_expense_paidby_chip"]
        XCTAssertTrue(paidBy.waitForExistence(timeout: 5), "No apareció el chip 'Pagado por'.")
        paidBy.tap()

        // El selector lista Tú/Ana/Beto; tocar una fila la selecciona y cierra el sheet.
        let anaRow = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'Ana'")
        ).firstMatch
        XCTAssertTrue(anaRow.waitForExistence(timeout: 5), "El selector de pagador no listó a 'Ana'.")
        anaRow.tap()

        // Guardar: esperar a que el botón se habilite (canSave) y tocarlo.
        let save = app.buttons["group_expense_save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5), "No apareció el botón de guardar.")
        let enabled = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isEnabled == true"),
            object: save
        )
        XCTAssertEqual(
            XCTWaiter().wait(for: [enabled], timeout: 8),
            .completed,
            "El botón de guardar no se habilitó (canSave falso)."
        )
        save.tap()

        // La pantalla de éxito debe montar — verificamos su botón principal (inequívoco).
        XCTAssertTrue(
            app.buttons["group_expense_success_accept"].waitForExistence(timeout: 10),
            "No apareció la pantalla de éxito del gasto de grupo (group_expense_success_accept)."
        )
    }
}
