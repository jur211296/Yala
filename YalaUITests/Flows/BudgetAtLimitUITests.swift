//
//  BudgetAtLimitUITests.swift
//  YalaUITests
//
//  «En el límite» junto a la barra naranja (decisión de Jürgen, 2026-11-05). Ningún seed deja un presupuesto entre el 80
//  y el 99 %, así que el test lo fabrica con lo gastado de verdad: crea uno global a S/ 1 (lee cuánto llevas gastado
//  este mes de su porcentaje) y otro con el límite que deja ese gasto al ~90 %. El primero, pasado, NO dice la palabra;
//  el segundo la dice en la fila y en el detalle.
//  `YALA_CAPTURES` (vía `TEST_RUNNER_YALA_CAPTURES`) guarda las capturas.
//  Scheme Yala Dev.
//

import XCTest

final class BudgetAtLimitUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_budgetAt90Percent_saysAtLimit_inTheRowAndTheDetail() throws {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "realista", deeplink: "budgets")
        XCTAssertTrue(app.waitForUITestReady(timeout: 90), "uitest_ready ausente — bootstrap/seed no completó.")

        // 1) Global a S/ 1: su porcentaje es lo gastado este mes × 100.
        createBudget(app, name: "QA Sonda", amount: "1")
        let probe = row(app, "QA Sonda")
        let percent = try XCTUnwrap(percentSpent(in: probe.label), "No se leyó el porcentaje de «\(probe.label)».")
        let spent = Double(percent) / 100
        XCTAssertGreaterThan(spent, 50, "El seed realista no dejó gasto este mes (\(spent)); el caso no discrimina.")
        XCTAssertFalse(probe.label.contains("En el límite"), "Un presupuesto PASADO dice «En el límite»: \(probe.label)")

        // 2) Otro global con el límite que deja ese gasto al ~90 %.
        let limit = Int((spent / 0.9).rounded())
        createBudget(app, name: "QA Limite", amount: "\(limit)")
        let atLimit = row(app, "QA Limite")
        capture(app, "fila")
        XCTAssertTrue(atLimit.label.contains("En el límite"),
                      "La fila al ~90 % no dice «En el límite» (VoiceOver): \(atLimit.label)")

        // 3) El detalle también lo dice.
        atLimit.tap()
        XCTAssertTrue(app.descendants(matching: .any)["budget_detail"].waitForExistence(timeout: 10),
                      "No se abrió el detalle del presupuesto.")
        let word = app.staticTexts["En el límite"].waitForExistence(timeout: 5)
        capture(app, "detalle")
        XCTAssertTrue(word, "El detalle al ~90 % no dice «En el límite».")
    }

    // MARK: - Helpers

    private func createBudget(_ app: XCUIApplication, name: String, amount: String) {
        let fab = app.buttons["budgets_create_button"]
        XCTAssertTrue(fab.waitForExistence(timeout: 15), "No apareció budgets_create_button.")
        fab.tap()

        let nameField = app.textFields["budget_name_field"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "No se montó el editor (budget_name_field).")
        nameField.tap()
        nameField.typeText(name)

        let amountField = app.textFields["budget_amount_field"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 5), "No apareció budget_amount_field.")
        amountField.tap()
        amountField.typeText(amount)

        let save = app.buttons["toolbar_save_button"]
        XCTAssertTrue(save.waitForExistence(timeout: 5), "No apareció toolbar_save_button.")
        XCTAssertTrue(save.isEnabled, "Guardar deshabilitado con nombre y monto.")
        save.tap()
        XCTAssertTrue(save.waitForNonExistence(timeout: 10), "El editor no se cerró al guardar.")
    }

    /// La fila del presupuesto, bajando la lista hasta tenerla en la franja central.
    private func row(_ app: XCUIApplication, _ name: String) -> XCUIElement {
        let element = app.buttons["budget_row_\(name)"]
        let window = app.windows.firstMatch.frame
        for _ in 0..<12 {
            if element.exists, element.frame.minY > window.minY + 120, element.frame.maxY < window.maxY - 140 {
                return element
            }
            app.swipeUp(velocity: .slow)
        }
        XCTFail("No se llegó a la fila de «\(name)».")
        return element
    }

    /// «Presupuesto X, 345600 por ciento gastado, …» → 345600.
    private func percentSpent(in label: String) -> Int? {
        guard let range = label.range(of: #"(\d+) por ciento"#, options: .regularExpression) else { return nil }
        return Int(label[range].split(separator: " ").first ?? "")
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
        guard let dir = ProcessInfo.processInfo.environment["YALA_CAPTURES"], !dir.isEmpty else { return }
        let url = URL(fileURLWithPath: dir).appendingPathComponent("\(name).png")
        do {
            try app.screenshot().pngRepresentation.write(to: url)
        } catch {
            #if DEBUG
            print("BudgetAtLimitUITests: Error: \(error)")
            #endif
        }
    }
}
