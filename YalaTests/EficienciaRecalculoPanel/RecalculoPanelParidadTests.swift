//
//  RecalculoPanelParidadTests.swift
//  YalaTests
//
//  Lote 4 de eficiencia (26-nov-2026): el recálculo del Panel va por tramos y acota sus recorridos con un índice por
//  fecha (`IndiceFechasMovimientos`). Las cifras tienen que salir idénticas, al bit: aquí se compara el cálculo de
//  siempre (sobre el historial entero) contra el nuevo (sobre lo que da el índice) con un historial grande y con las
//  filas que separan las reglas: medianoches exactas en el borde de cada mes, empates de fecha, ajustes de saldo,
//  gastos de grupo, movimientos sin categoría y de signo contrario a su categoría.
//
//  Sin ModelContext: `@Model` en memoria, como `PanelBudgetPlanningParityTests`.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Recálculo del Panel · el cálculo por tramos da las mismas cifras")
struct RecalculoPanelParidadTests {

    private static var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Lima") ?? .current
        return calendar
    }()

    /// El «ahora» de las pruebas: fijo, a mitad de mes y de semana.
    private static let now: Date = {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: 19, hour: 15, minute: 30)) ?? .distantPast
    }()

    private struct Fixture {
        let accounts: [Account]
        let transactions: [TransactionItem]
        let budgets: [Budget]
    }

    /// Generador determinista (el mismo historial en cada corrida).
    private struct Azar {
        var estado: UInt64
        mutating func siguiente() -> UInt64 {
            estado = estado &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return estado >> 33
        }
        mutating func entre(_ rango: ClosedRange<Int>) -> Int {
            rango.lowerBound + Int(siguiente() % UInt64(rango.count))
        }
    }

    private static func fixture(count: Int = 6_000) -> Fixture {
        let cal = calendar
        let bank = Account(name: "Banco", currencyCode: "PEN", colorHex: "#000", iconName: "banknote", type: "bank")
        let cash = Account(name: "Efectivo", currencyCode: "PEN", colorHex: "#111", iconName: "banknote", type: "cash")
        let food = Yala.Category(name: "Comida", colorHex: "#000", isIncome: false)
        let taxi = Yala.Category(name: "Taxi", colorHex: "#000", isIncome: false)
        let salary = Yala.Category(name: "Sueldo", colorHex: "#000", isIncome: true)
        let categories: [Yala.Category?] = [food, taxi, salary, nil]
        var azar = Azar(estado: 42)
        let start = cal.date(from: DateComponents(year: 2019, month: 1, day: 1)) ?? .distantPast
        let span = Int(now.timeIntervalSince(start) / 86_400)
        var transactions: [TransactionItem] = []
        for i in 0..<count {
            let day = azar.entre(0...span)
            var date = cal.date(byAdding: .day, value: day, to: start) ?? start
            switch i % 7 {
            case 0:
                // Medianoche exacta (como deja `DatePicker`), a veces el día 1: el borde de los períodos.
                date = cal.startOfDay(for: date)
            case 1:
                date = cal.date(from: cal.dateComponents([.year, .month], from: date)) ?? date
            default:
                date = date.addingTimeInterval(TimeInterval(azar.entre(0...86_399)))
            }
            let category = categories[azar.entre(0...3)]
            var amount = Double(azar.entre(1...90_000)) / 100
            if category?.isIncome != true { amount = -amount }
            if i % 23 == 0 { amount = -amount }   // signo contrario a su categoría (devolución)
            let tx = TransactionItem(
                date: date, amount: amount, currencyCode: "PEN", category: category,
                account: i % 5 == 0 ? cash : bank,
                amountInPreferredCurrency: amount, preferredCurrencyCode: "PEN"
            )
            if i % 31 == 0 { tx.balanceAdjustmentType = "adjustment" }
            if i % 37 == 0 { tx.splitExpenseID = "split-\(i)" }
            transactions.append(tx)
            if i % 50 == 0 {
                // Empate exacto de fecha con la anterior.
                let twin = TransactionItem(
                    date: date, amount: -12.34, currencyCode: "PEN", category: food, account: bank,
                    amountInPreferredCurrency: -12.34, preferredCurrencyCode: "PEN"
                )
                transactions.append(twin)
            }
        }
        // Lo de hoy, para el cupo del día.
        for amount in [-15.5, -7.25, 30.0] {
            transactions.append(TransactionItem(
                date: now.addingTimeInterval(-600), amount: amount, currencyCode: "PEN", category: food, account: bank,
                amountInPreferredCurrency: amount, preferredCurrencyCode: "PEN"
            ))
        }
        // El Panel guarda los movimientos del más nuevo al más viejo.
        transactions.sort { $0.date > $1.date }

        let created = cal.date(from: DateComponents(year: 2018, month: 6, day: 1)) ?? .distantPast
        func budget(_ name: String, _ period: String, limit: Double, shared: Bool = true) -> Budget {
            let b = Budget(
                currencyCode: "PEN", limitAmount: limit, name: name, periodType: period,
                isFavorite: true, includeSharedExpenses: shared
            )
            b.createdAt = created
            return b
        }
        var budgets = [
            budget("Mes", "monthly", limit: 9_000),
            budget("Mes ajustado", "monthly", limit: 500, shared: false),
            budget("Semana", "weekly", limit: 2_000),
            budget("Año", "yearly", limit: 200_000)
        ]
        let unique = budget("Viaje", "unique", limit: 3_000)
        unique.startDate = cal.date(from: DateComponents(year: 2026, month: 11, day: 1))
        unique.endDate = cal.date(from: DateComponents(year: 2026, month: 11, day: 30))
        budgets.append(unique)
        for (i, b) in budgets.enumerated() { b.favoriteOrder = i }
        return Fixture(accounts: [bank, cash], transactions: transactions, budgets: budgets)
    }

    // MARK: - Nota de salud

    @Test("La nota de salud da lo mismo con el índice que sin él, en cada período", arguments: [
        DetailPeriod.thisMonth, .lastMonth, .thisYear, .lastYear, .allTime
    ])
    func healthScore_sameWithAndWithoutIndex(period: DetailPeriod) {
        let f = Self.fixture()
        let indice = IndiceFechasMovimientos(f.transactions, fecha: \.date)
        func score(_ indice: IndiceFechasMovimientos<TransactionItem>?) -> FinancialScore {
            FinancialScoreCalculator.calculate(
                transactions: f.transactions, budgets: f.budgets, scheduledPayments: [], accounts: f.accounts,
                paidAmounts: [:], period: period, preferredCurrencyCode: "PEN",
                now: Self.now, calendar: Self.calendar, coverageAccounts: f.accounts, indice: indice
            )
        }
        let viejo = score(nil)
        let nuevo = score(indice)
        #expect(nuevo == viejo, "\(period): \(nuevo) ≠ \(viejo)")
        // Control del fixture: la nota tiene presupuesto y ritmo que comparar (si no, saldría igual con cualquier índice).
        #expect(viejo.budget != nil)
        #expect(viejo.activity != nil)
    }

    @Test("Control: un índice que pierde movimientos SÍ cambia la nota (la paridad no es casual)")
    func healthScore_brokenIndexChangesIt() {
        let f = Self.fixture()
        func score(_ indice: IndiceFechasMovimientos<TransactionItem>?) -> FinancialScore {
            FinancialScoreCalculator.calculate(
                transactions: f.transactions, budgets: f.budgets, scheduledPayments: [], accounts: f.accounts,
                paidAmounts: [:], period: .thisMonth, preferredCurrencyCode: "PEN",
                now: Self.now, calendar: Self.calendar, coverageAccounts: f.accounts, indice: indice
            )
        }
        // Mutante: un índice armado sin los movimientos más nuevos (los de este mes).
        let roto = IndiceFechasMovimientos(Array(f.transactions.dropFirst(80)), fecha: \.date)
        #expect(score(roto) != score(nil), "con movimientos perdidos la nota tendría que cambiar")
    }

    @Test("Las alertas de la nota dan lo mismo con el índice")
    func alerts_sameWithIndex() {
        let f = Self.fixture()
        let indice = IndiceFechasMovimientos(f.transactions, fecha: \.date)
        let viejo = FinancialScoreAlertsLogic.overBudgets(
            transactions: f.transactions, budgets: f.budgets, now: Self.now, calendar: Self.calendar,
            adjustment: .none, converter: CurrencyConverter.shared
        )
        let nuevo = FinancialScoreAlertsLogic.overBudgets(
            transactions: f.transactions, budgets: f.budgets, now: Self.now, calendar: Self.calendar,
            adjustment: .none, converter: CurrencyConverter.shared, movimientosEn: { indice.elementos(en: $0) }
        )
        #expect(nuevo == viejo)
        #expect(viejo.contains("Mes ajustado"), "control: el presupuesto ajustado tiene que estar pasado")
    }

    // MARK: - Ritmo

    /// El cálculo del hueco de antes, tal cual: ordena los movimientos y agrupa por el mes de cada uno.
    private static func huecoViejo(_ transactions: [TransactionItem], calendar: Calendar) -> Int {
        let ordenados = transactions.sorted { $0.date < $1.date }
        let unique = Array(Set(ordenados.map { calendar.startOfDay(for: $0.date) })).sorted()
        guard unique.count > 1 else { return 0 }
        var maxGap = 0
        for i in 1..<unique.count {
            maxGap = max(maxGap, (calendar.dateComponents([.day], from: unique[i - 1], to: unique[i]).day ?? 0) - 1)
        }
        return maxGap
    }

    @Test("El ritmo sin ordenar los movimientos da los mismos huecos, total y por mes")
    func rhythmGaps_sameWithoutSorting() {
        let f = Self.fixture(count: 1_500)
        let cal = Self.calendar
        let txs = f.transactions.filter { $0.balanceAdjustmentType == nil }
        let days = Set(txs.map { cal.startOfDay(for: $0.date) })

        #expect(FinancialScoreCalculator.computeMaxGap(days: days, calendar: cal) == Self.huecoViejo(txs, calendar: cal))

        let porMesViejo = Dictionary(grouping: txs) { cal.dateComponents([.year, .month], from: $0.date) }
            .mapValues { Self.huecoViejo($0, calendar: cal) }
        #expect(FinancialScoreCalculator.computeMonthlyMaxGaps(days: days, calendar: cal) == porMesViejo)
    }

    // MARK: - Presupuestos del Panel

    @Test("La tarjeta de presupuestos del Panel da lo gastado y lo de hoy de Planificación sobre el historial entero")
    func panelBudgets_sameAsFullHistory() throws {
        let f = Self.fixture()
        // El Panel mide los períodos de los presupuestos con el reloj: lo de hoy se fecha con `aMomentAgoToday()` para que
        // el período en curso tenga gasto en cualquier día y hora de la corrida.
        let food = Yala.Category(name: "Comida", colorHex: "#000", isIncome: false)
        let hoy = [-18.5, -40.25, 15.0].map { amount in
            TransactionItem(
                date: aMomentAgoToday(), amount: amount, currencyCode: "PEN", category: food, account: f.accounts.first,
                amountInPreferredCurrency: amount, preferredCurrencyCode: "PEN"
            )
        }
        let transactions = (hoy + f.transactions).sorted { $0.date > $1.date }
        let panel = PanelViewModel()
        panel.calculateBudgetsWidget(budgets: f.budgets, transactions: transactions, defaultCurrencyCode: "PEN")
        let summaries = panel.budgetsWidget.topBudgetSummaries
        try #require(!summaries.isEmpty)
        for summary in summaries {
            let interval = panel.getBudgetDateInterval(budget: summary.budget)
            let spent = BudgetsViewModel.calculateSpending(
                budget: summary.budget, transactions: transactions, interval: interval
            )
            let today = BudgetsViewModel.calculateSpentToday(
                budget: summary.budget, transactions: transactions, period: interval,
                calendar: Calendar.current
            )
            #expect(summary.spent == spent, "\(summary.budget.name): \(summary.spent) ≠ \(spent)")
            #expect(summary.spentToday == today, "\(summary.budget.name) hoy: \(summary.spentToday) ≠ \(today)")
        }
        #expect(summaries.contains { $0.spent > 0 }, "control: algún presupuesto tiene gasto en su período")
        #expect(summaries.contains { $0.spentToday > 0 }, "control: algún presupuesto tiene gasto hoy")
    }

    // MARK: - Gastos por cuenta

    @Test("Los gastos por cuenta del período dan lo mismo sobre lo que da el índice")
    func accountPeriodExpenses_sameWithIndex() {
        let f = Self.fixture()
        let indice = IndiceFechasMovimientos(f.transactions, fecha: \.date)
        let ids = f.accounts.map(\.persistentModelID)
        for period in [DetailPeriod.thisMonth, .lastMonth, .thisYear] {
            let interval = period.dateInterval(customRange: nil, now: Self.now)
            let viejo = AccountSpendingLogic.spentByAccount(
                f.transactions, accounts: ids, in: interval, key: \.persistentModelID
            )
            let nuevo = AccountSpendingLogic.spentByAccount(
                indice.elementos(en: interval), accounts: ids, in: interval, key: \.persistentModelID
            )
            #expect(nuevo == viejo, "\(period)")
            #expect(viejo.values.contains { $0 != 0 }, "control: \(period) tiene gastos")
        }
    }
}
