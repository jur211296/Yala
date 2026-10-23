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
}
