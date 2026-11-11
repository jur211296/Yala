//
//  CashFlowSetupLogic.swift
//  Yala
//
//  Auditoría UX 2.2 · L18-5 (opción C, variante 2) y L18-10 (opción C).
//  - El plan nace con lo que la persona tiene hoy en sus cuentas, no en S/ 0: la misma cifra y las mismas cuentas que
//    el «Tienes X en N cuentas» del Panel sin filtros (`LiveBalanceCalculator` + `PanelTotalAccountsLogic`).
//  - La lista de crear el plan se parte: lo que se repite cada mes a la vista y los gastos que cambian, plegados.
//    «Se repite» = viene de un pago planificado, o tuvo actividad en al menos 5 de los 6 meses completos anteriores con
//    montos parecidos (cada mes a ≤ 25 % de su media). Asumido en el Paso 0 del encargo.
//
//  Lógica pura salvo la lectura de los modelos que recibe.
//

import Foundation
import SwiftData

enum CashFlowSetupLogic {

    /// Lo que tiene la persona hoy en sus cuentas, en la divisa del plan.
    struct TodayBalance: Equatable {
        let amount: Double
        /// Cuántas cuentas suma (las que suman en el Panel).
        let accountCount: Int
        /// Alguna divisa se convirtió con una tasa que no era la de hoy y pesa en la cifra («≈»).
        let isApproximate: Bool
    }

    /// La cifra del «Tienes X en N cuentas» del Panel sin filtro de cuentas, con su ajuste de incluir los grupos.
    @MainActor
    static func todayBalance(
        accounts: [Account],
        transactions: [TransactionItem],
        currencyCode: String,
        includeGroups: Bool,
        now: Date = .now,
        converter: CurrencyConverting = CurrencyConverter.shared
    ) -> TodayBalance {
        let effective = PanelTotalAccountsLogic.accountsForTotal(accounts, includeGroups: includeGroups, hasSelectedAccount: false)
        let breakdown = LiveBalanceCalculator.liveBalanceBreakdown(
            accounts: effective,
            transactions: transactions,
            preferredCurrencyCode: currencyCode,
            asOf: now,
            converter: converter
        )
        return TodayBalance(
            amount: (breakdown.convertedTotal as NSDecimalNumber).doubleValue,
            accountCount: PanelTotalAccountsLogic.summedAccountsCount(accounts, summedAccountIDs: breakdown.eligibleAccountIDs),
            isApproximate: breakdown.amountsAreApproximate
        )
    }

    /// ¿Se repite cada mes con un monto parecido? `monthlyTotals` son los 6 meses completos anteriores (0 = sin
    /// movimientos ese mes).
    static func isRecurring(monthlyTotals: [Double]) -> Bool {
        let active = monthlyTotals.filter { $0 > 0 }
        guard active.count >= 5 else { return false }
        let mean = active.reduce(0, +) / Double(active.count)
        guard mean > 0 else { return false }
        return active.allSatisfy { abs($0 - mean) <= mean * 0.25 }
    }

    /// El texto de los ejemplos de «Gastos que cambian»: los tres primeros nombres.
    static func variableExamples(_ names: [String]) -> String {
        names.prefix(3).joined(separator: ", ")
    }

    // MARK: - Sin ingresos a la vista (decisión 33 de la revisión 2.3, opción A)

    /// El armado pregunta «¿Cuánto recibes al mes?» cuando tiene algo que sugerir pero ninguna línea de ingreso: la
    /// primera semana el sueldo aún no está en el historial, y sin él el resumen anunciaba «Te faltan al mes S/ 2,573».
    static func asksForIncome(suggestedIncomeLines: Int, suggestedLines: Int) -> Bool {
        suggestedLines > 0 && suggestedIncomeLines == 0
    }

    /// Lo que dice la última fila del resumen.
    enum SummaryOutcome: Equatable {
        case surplus(Double)
        case shortfall(Double)
        /// No hay ingresos a la vista y la persona contestó «Aún no lo sé»: no se anuncia que falta dinero.
        case incomeMissing
    }

    /// `typedIncome`: lo que escribió la persona al preguntarle; `nil` si no escribió nada.
    static func summaryOutcome(
        suggestedIncome: Double, expense: Double, asksForIncome: Bool, typedIncome: Double?
    ) -> SummaryOutcome {
        if asksForIncome && typedIncome == nil { return .incomeMissing }
        let net = suggestedIncome + (typedIncome ?? 0) - expense
        return CashFlowMonthSummaryLogic.isShortfall(net) ? .shortfall(abs(net)) : .surplus(abs(net))
    }

    /// La categoría a la que se ata el ingreso escrito: la primera de ingreso que la persona ve y no es de sistema
    /// («Cobros de grupos» no). Atada a una categoría, el sueldo real cuenta en esa línea al llegar; sin ella, el plan lo
    /// sumaría dos veces (la línea escrita y «otros ingresos»). `nil` si no hay ninguna.
    static func typedIncomeCategory(in categories: [Category]) -> Category? {
        categories
            .filter { $0.isIncome && $0.isVisible && !$0.isSystem }
            .min { $0.sortOrder < $1.sortOrder }
    }
}
