//
//  NotaSaludCuentasConElMismoNombreTests.swift
//  YalaTests
//
//  Barrido de QA antes de la build 12 de 2.3 (27-nov-2026, iPhone 14): con tres cuentas en negativo que se llaman
//  igual, la nota de salud decía «La nota no ve: Cuenta Principal en negativo · Cuenta Principal en negativo · Cuenta
//  Principal en negativo». Cada texto sale una vez y el orden se conserva.
//

import Testing
@testable import Yala

@Suite("Nota de salud · cuentas en negativo con el mismo nombre")
struct NotaSaludCuentasConElMismoNombreTests {

    private func score(negativas: [String]) -> FinancialScore {
        var score = FinancialScore(total: 99, budget: 99, activity: 100, bills: 98)
        score.alerts = FinancialScoreAlerts(overBudgets: [], negativeAccounts: negativas)
        return score
    }

    @Test("Tres cuentas que se llaman igual salen una sola vez")
    func mismoNombre_saleUnaVez() {
        let linea = FinancialScoreCopy.unseenLine(
            for: score(negativas: ["Cuenta Principal", "Cuenta Principal", "Cuenta Principal"]),
            isExpensesOnlyMode: false)
        #expect(linea == L10n.Panel.Health.unseen(L10n.Panel.Health.unseenNegativeAccount("Cuenta Principal")))
    }

    @Test("Nombres distintos siguen saliendo todos, en su orden")
    func nombresDistintos_salenTodosEnOrden() {
        let linea = FinancialScoreCopy.unseenLine(
            for: score(negativas: ["Efectivo", "Banco", "Efectivo"]), isExpensesOnlyMode: false)
        let esperado = [
            L10n.Panel.Health.unseenNegativeAccount("Efectivo"),
            L10n.Panel.Health.unseenNegativeAccount("Banco"),
        ].joined(separator: " · ")
        #expect(linea == L10n.Panel.Health.unseen(esperado))
    }
}
