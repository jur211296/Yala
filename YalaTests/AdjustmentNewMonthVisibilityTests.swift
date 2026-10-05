//
//  AdjustmentNewMonthVisibilityTests.swift
//  YalaTests
//
//  Investigación del 2026-10-02 (ticket `adjustment-hides-new-month-activity-from-available-and-widget`):
//  un reporte decía que, tras registrar un ajuste de cuenta el mes anterior, los movimientos del día 1
//  del mes siguiente salían en la lista pero NO en «Disponible» del Panel ni en el widget.
//
//  Este fichero deja la MEDIDA, no un arreglo. Siembra el caso tal como lo crea la app —el ajuste por
//  `InitialBalanceService`, los movimientos con categoría y subcategoría como los guarda el formulario—
//  y lo pasa por las MISMAS llamadas que alimentan cada superficie:
//
//  - Panel, «Disponible · Período»: `HeroBucketsCalculator.calculate` con `DetailPeriod.thisMonth.dateInterval()`
//    y el mes calendario de `Calendar.current`, igual que `PanelViewModel.calculateHeroWidget`.
//  - Widget: `WidgetDataCache.buildPeriodSummary` con el intervalo de `.thisMonth`, igual que `buildSnapshot`.
//
//  Resultado medido: el ajuste NO esconde nada. Si alguno de estos tests se pone rojo, el reporte
//  pasó a reproducirse y el ticket de investigación tiene que reabrirse.
//
//  Las fechas son RELATIVAS a hoy (mes en curso / mes anterior) porque las dos superficies leen
//  `Date.now` sin inyección posible: así el escenario «día 1 del mes en curso» vale cualquier día.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite(.serialized)
struct AdjustmentNewMonthVisibilityTests {

    // MARK: - Escenario

    enum AdjustmentKind: String, CaseIterable, CustomTestStringConvertible {
        /// «Ajustar por registro»: crea una transacción `adjustment` en la fecha elegida.
        case byEntryUp
        case byEntryDown
        /// «Cambiar saldo inicial»: reescribe la transacción `initial_balance`.
        case changeInitialBalance

        var testDescription: String { rawValue }
    }

    /// Hora del movimiento del día 1. `.midnight` es lo que deja `DatePicker([.date])`: el instante
    /// exacto del borde de mes, donde un `DateInterval` cerrado ya mordió otras veces.
    enum DayOneTime: String, CaseIterable, CustomTestStringConvertible {
        case midnight
        case morning

        var testDescription: String { rawValue }
    }

    struct Fixture {
        let context: ModelContext
        let account: Account
        let dayOneIncome: TransactionItem
        let dayOneExpense: TransactionItem
        let adjustment: TransactionItem
    }

    private let calendar = Calendar.current

    private var startOfThisMonth: Date {
        calendar.dateInterval(of: .month, for: .now)?.start ?? .now
    }

    private var startOfLastMonth: Date {
        calendar.date(byAdding: .month, value: -1, to: startOfThisMonth) ?? startOfThisMonth
    }

    private func makeFixture(
        kind: AdjustmentKind,
        time: DayOneTime,
        accountCurrency: String
    ) throws -> Fixture {
        let context = try makeTestContext()

        let account = Account(
            name: "Cuenta",
            currencyCode: accountCurrency,
            colorHex: "#6366F1",
            iconName: "creditcard",
            type: "bank"
        )
        context.insert(account)

        let incomeCategory = Yala.Category(name: "Salario", colorHex: "#0F0", isIncome: true)
        let expenseCategory = Yala.Category(name: "Comida", colorHex: "#F00", isIncome: false)
        context.insert(incomeCategory)
        context.insert(expenseCategory)
        let incomeSub = Subcategory(name: "Nómina", category: incomeCategory)
        let expenseSub = Subcategory(name: "Mercado", category: expenseCategory)
        context.insert(incomeSub)
        context.insert(expenseSub)
        // El mismo camino que usa el formulario de cuenta para encontrar «Ajuste de saldo».
        let adjustmentSub = try #require(InitialBalanceService.ensureBalanceAdjustmentSubcategoryExists(context: context))

        func movement(_ amount: Double, on date: Date, sub: Subcategory, cat: Yala.Category) -> TransactionItem {
            let tx = TransactionItem(
                date: date,
                amount: amount,
                currencyCode: accountCurrency,
                note: "",
                category: cat,
                account: account,
                tags: [],
                amountInPreferredCurrency: amount
            )
            tx.preferredCurrencyCode = accountCurrency
            tx.subcategory = sub
            context.insert(tx)
            return tx
        }

        // Mes anterior: actividad normal, para que el saldo inicial tenga dónde anclarse.
        let lastMonthDay10 = calendar.date(byAdding: .day, value: 9, to: startOfLastMonth) ?? startOfLastMonth
        _ = movement(2_000, on: lastMonthDay10, sub: incomeSub, cat: incomeCategory)
        _ = movement(-300, on: lastMonthDay10, sub: expenseSub, cat: expenseCategory)
        try context.save()

        let allSoFar = try context.fetch(FetchDescriptor<TransactionItem>())
        let currentBalance = InitialBalanceService.currentBalance(for: account, allTransactions: allSoFar)
        let lastMonthDay20 = calendar.date(byAdding: .day, value: 19, to: startOfLastMonth) ?? startOfLastMonth

        // El ajuste, registrado el MES ANTERIOR.
        let adjustment: TransactionItem
        switch kind {
        case .byEntryUp, .byEntryDown:
            let target = kind == .byEntryUp ? currentBalance + 450 : currentBalance - 450
            adjustment = InitialBalanceService.createAdjustment(
                targetBalance: target,
                currentBalance: currentBalance,
                for: account,
                subcategory: adjustmentSub,
                date: lastMonthDay20,
                context: context
            )
        case .changeInitialBalance:
            adjustment = InitialBalanceService.setInitialBalance(
                amount: 5_000,
                for: account,
                subcategory: adjustmentSub,
                allTransactions: allSoFar,
                context: context
            )
        }
        try context.save()

        // Día 1 del mes en curso.
        let dayOne: Date = switch time {
        case .midnight: startOfThisMonth
        case .morning: calendar.date(byAdding: .hour, value: 9, to: startOfThisMonth) ?? startOfThisMonth
        }
        let income = movement(1_200, on: dayOne, sub: incomeSub, cat: incomeCategory)
        let expense = movement(-80, on: dayOne, sub: expenseSub, cat: expenseCategory)
        try context.save()

        return Fixture(context: context, account: account, dayOneIncome: income, dayOneExpense: expense, adjustment: adjustment)
    }

    // MARK: - Medida

    @Test(arguments: AdjustmentKind.allCases, DayOneTime.allCases)
    func dayOneMovements_countInPanelAvailableAndWidget_afterLastMonthAdjustment(
        kind: AdjustmentKind,
        time: DayOneTime
    ) throws {
        for accountCurrency in ["COP", "USD"] {
            let f = try makeFixture(kind: kind, time: time, accountCurrency: accountCurrency)

            // Lista: las dos filas del día 1 existen en el store (es lo que pinta Transacciones).
            let all = try f.context.fetch(FetchDescriptor<TransactionItem>())
            #expect(all.contains { $0.persistentModelID == f.dayOneIncome.persistentModelID })
            #expect(all.contains { $0.persistentModelID == f.dayOneExpense.persistentModelID })
            // Y el ajuste quedó en el mes ANTERIOR, que es la premisa del reporte.
            #expect(f.adjustment.balanceAdjustmentType != nil)
            #expect(f.adjustment.date < startOfThisMonth)

            // Panel — mismos intervalos que `PanelViewModel.calculateHeroWidget`.
            let monthInterval = try #require(calendar.dateInterval(of: .month, for: .now))
            let prevEnd = calendar.date(byAdding: .second, value: -1, to: monthInterval.start) ?? monthInterval.start
            let prevStart = calendar.date(byAdding: .month, value: -1, to: monthInterval.start) ?? monthInterval.start
            let periodInterval = DetailPeriod.thisMonth.dateInterval()

            let hero = HeroBucketsCalculator.calculate(
                transactions: all,
                monthInterval: monthInterval,
                prevInterval: DateInterval(start: prevStart, end: prevEnd),
                periodInterval: periodInterval,
                eligibleAccountIDs: [f.account.persistentModelID]
            )
            #expect(hero.periodIncome == 1_200, "Panel · ingresos del mes [\(accountCurrency)]")
            #expect(hero.periodExpense == 80, "Panel · gastos del mes [\(accountCurrency)]")
            #expect(hero.monthIncome == 1_200)
            #expect(hero.monthExpense == 80)

            // Widget — misma llamada que `WidgetDataCache.buildSnapshot` para `.thisMonth`.
            let widget = WidgetDataCache.buildPeriodSummary(
                transactions: all,
                periodStart: periodInterval.start,
                periodEnd: periodInterval.end,
                currencyCode: accountCurrency,
                allTransactionsForBalance: all
            )
            #expect(widget.totalIncome == 1_200, "Widget · ingresos del mes [\(accountCurrency)]")
            #expect(widget.totalExpense == 80, "Widget · gastos del mes [\(accountCurrency)]")
        }
    }
}
