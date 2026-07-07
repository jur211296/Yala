//
//  IncomeExpenseClassificationUITests.swift
//  YalaUITests
//
//  XCUI DISCRIMINANTE del fix de clasificación income/expense por CATEGORÍA
//  (commits 8347a776/13f2cbb0). Con `-uitest-seed-desync` se siembran 4 TX donde DOS
//  tienen el signo del monto CONTRARIO a su categoría:
//    · categoría INCOME  con monto NEGATIVO  (Salario −100)
//    · categoría EXPENSE con monto POSITIVO  (Restaurantes +200)
//  La cifra de Ingresos debe INCLUIR la income-negativa (NO en Gastos) y la de Gastos la
//  expense-positiva (NO en Ingresos). Con acumulación signed por categoría (regla canónica
//  `TransactionClassificationLogic.isIncome`): Ingresos = 500 · Gastos = 300. Si clasificara
//  por SIGNO (el bug): 800 / 600. A nivel lógica lo cubre `TransactionClassificationLogicTests`;
//  este es el e2e de UI que lo distingue en las cifras de Insights ("Tus cifras").
//

import XCTest

final class IncomeExpenseClassificationUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_incomeExpenseFigures_classifyByCategory_notBySign() {
        let app = XCUIApplication()
        // Sin perfil de seed (seed: nil) para no contaminar los totales: solo las 4 TX desync.
        app.launchForUITest(seed: nil, seedDesync: true)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — el seed desync no completó.")

        // Esperar a que el Panel monte del todo (avatar del toolbar) antes de tocar el tab
        // bar: `boundBy:` sobre un tab bar aún en construcción puede resolver al índice
        // equivocado (flake observado: golpeaba "Más" en un sim no asentado).
        XCTAssertTrue(app.buttons["profile_avatar"].waitForExistence(timeout: 10), "El Panel no terminó de montar.")

        // Estadísticas (2º tab) → sub-tab Insights (landing por defecto).
        app.tabBars.buttons.element(boundBy: 1).tap()
        XCTAssertTrue(
            app.descendants(matching: .any).matching(identifier: "stats_tab_insights").firstMatch.waitForExistence(timeout: 15),
            "No montó la tab Insights de Estadísticas."
        )

        // Cifras del hero "Tus cifras". El id vive en el `AmountText` (leaf a11y: `children: .ignore`
        // + `accessibilityLabel = monto formateado`) → puede surfacear como staticText/otherElement.
        let income = app.descendants(matching: .any).matching(identifier: "stats_kpi_income").firstMatch
        let expense = app.descendants(matching: .any).matching(identifier: "stats_kpi_expense").firstMatch
        XCTAssertTrue(income.waitForExistence(timeout: 10), "No apareció la cifra de Ingresos (stats_kpi_income).")
        XCTAssertTrue(expense.waitForExistence(timeout: 10), "No apareció la cifra de Gastos (stats_kpi_expense).")

        // Comparo por DÍGITOS del label (robusto a símbolo de divisa, separador de miles y decimales).
        let incomeDigits = income.label.filter(\.isNumber)
        let expenseDigits = expense.label.filter(\.isNumber)

        // Fix (por categoría): Ingresos = 600 − 100 = 500. Bug (por signo): 600 + 200 = 800.
        XCTAssertTrue(
            incomeDigits.contains("500"),
            "Ingresos debe INCLUIR la TX income de monto negativo (total esperado 500). Label: '\(income.label)'"
        )
        XCTAssertFalse(
            incomeDigits.contains("800"),
            "Ingresos NO debe clasificar por signo (800 = bug: contaría la expense-positiva). Label: '\(income.label)'"
        )

        // Fix (por categoría): Gastos = 500 − 200 = 300. Bug (por signo): 100 + 500 = 600.
        XCTAssertTrue(
            expenseDigits.contains("300"),
            "Gastos debe INCLUIR la TX expense de monto positivo como reembolso (total esperado 300). Label: '\(expense.label)'"
        )
        XCTAssertFalse(
            expenseDigits.contains("600"),
            "Gastos NO debe clasificar por signo (600 = bug: contaría la income-negativa). Label: '\(expense.label)'"
        )
    }
}
