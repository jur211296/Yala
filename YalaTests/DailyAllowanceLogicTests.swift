//
//  DailyAllowanceLogicTests.swift
//  YalaTests
//
//  «Cuánto puedo gastar hoy» (2.3): el cupo del día de un presupuesto.
//  Cupo = (límite − gastado del período fuera de hoy) ÷ días que faltan con hoy − gastado hoy.
//
//  Los casos son DISCRIMINANTES frente a las dos cuentas ingenuas que se parecen:
//  - «lo que queda ÷ días» (el «al día» fijo de 2.2): al gastar hoy, el cupo bajaría solo una fracción del gasto.
//  - «límite ÷ días del período» (cupo plano): no mira lo ya gastado.
//
//  Sin ModelContext: `@Model` en memoria, como `PanelBudgetPlanningParityTests`.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Cupo del día · la cuenta")
struct DailyAllowanceLogicTests {

    @Test("Al empezar el día: lo que queda entre los días que faltan")
    func startOfDay() {
        // 3.000 de límite, 1.000 gastados antes de hoy, 20 días con hoy → 100.
        #expect(DailyAllowanceLogic.state(limit: 3_000, spent: 1_000, spentToday: 0, daysRemaining: 20) == .available(100))
    }

    @Test("Cada gasto de hoy baja el cupo en lo que cuesta, entero")
    func spendingTodayLowersTheAllowanceByItsFullAmount() {
        // Con «lo que queda ÷ días» saldría (3.000 − 1.030) ÷ 20 = 98,5: el gasto de 30 casi no se notaría.
        #expect(DailyAllowanceLogic.state(limit: 3_000, spent: 1_030, spentToday: 30, daysRemaining: 20) == .available(70))
    }

    @Test("Gastar más que el cupo del día dice por cuánto")
    func overToday() {
        #expect(DailyAllowanceLogic.state(limit: 3_000, spent: 1_130, spentToday: 130, daysRemaining: 20) == .overToday(30))
    }

    @Test("Gastar justo el cupo deja 0, no «te pasaste»")
    func exactlyTheAllowance() {
        #expect(DailyAllowanceLogic.state(limit: 3_000, spent: 1_100, spentToday: 100, daysRemaining: 20) == .available(0))
        // Medio céntimo de una conversión no cuenta como pasarse.
        #expect(DailyAllowanceLogic.state(limit: 3_000, spent: 1_100.004, spentToday: 100.004, daysRemaining: 20) == .available(0))
    }

    @Test("El último día, el cupo es todo lo que queda")
    func lastDay() {
        #expect(DailyAllowanceLogic.state(limit: 500, spent: 420, spentToday: 20, daysRemaining: 1) == .available(80))
    }

    @Test("Lo apuntado para días posteriores del período ya está comprometido")
    func futureDatedSpendingIsCommitted() {
        // 1.000 antes de hoy + 500 fechados el día 30 → quedan 1.500 para 20 días.
        #expect(DailyAllowanceLogic.state(limit: 3_000, spent: 1_500, spentToday: 0, daysRemaining: 20) == .available(75))
    }

    @Test("Sin cupo que enseñar: período cerrado o que no empieza, sin límite, o agotado antes de hoy")
    func nothingToShow() {
        #expect(DailyAllowanceLogic.state(limit: 3_000, spent: 0, spentToday: 0, daysRemaining: -1) == nil)
        #expect(DailyAllowanceLogic.state(limit: 3_000, spent: 0, spentToday: 0, daysRemaining: 0) == nil)
        #expect(DailyAllowanceLogic.state(limit: 0, spent: 0, spentToday: 0, daysRemaining: 10) == nil)
        #expect(DailyAllowanceLogic.state(limit: 1_000, spent: 1_000, spentToday: 0, daysRemaining: 10) == nil)
        #expect(DailyAllowanceLogic.state(limit: 1_000, spent: 1_200, spentToday: 50, daysRemaining: 10) == nil)
        // Agotado con lo de HOY: la fila ya dice «Te pasaste por S/ 15»; un «Hoy te pasaste por S/ 19» la contradiría.
        #expect(DailyAllowanceLogic.state(limit: 100, spent: 115, spentToday: 20, daysRemaining: 5) == nil)
        // Justo en el límite: «Te quedan S/ 0.00», sin cupo.
        #expect(DailyAllowanceLogic.state(limit: 100, spent: 100, spentToday: 20, daysRemaining: 5) == nil)
    }

    @Test("Cupo × días − gastado hoy es lo que queda del presupuesto («Te quedan» de la fila)")
    func agreesWithRemaining() {
        let cases: [(Double, Double, Double, Int)] = [(3_000, 1_030, 30, 20), (1_800, 400, 0, 27), (900, 700, 15, 3)]
        for (limit, spent, today, days) in cases {
            guard case .available(let left) = DailyAllowanceLogic.state(
                limit: limit, spent: spent, spentToday: today, daysRemaining: days
            ) else {
                Issue.record("Esperaba cupo disponible para \(limit)/\(spent)/\(today)/\(days)")
                continue
            }
            let allowance = left + today
            let remaining = BudgetRemainingLogic.remaining(limit: limit, spent: spent)
            #expect(abs(allowance * Double(days) - today - remaining) < 0.0001)
        }
    }
}

@Suite("Cupo del día · hoy dentro del período")
struct DailyAllowanceTodayIntervalTests {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Lima") ?? .gmt
        return calendar
    }

    private func date(_ day: Int, _ hour: Int = 0, _ minute: Int = 0, _ second: Int = 0, month: Int = 11) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute, second: second))
            ?? .distantPast
    }

    @Test("Hoy es de 00:00:00 a 23:59:59, sin el primer instante de mañana")
    func todayIsClosedOnItsLastSecond() throws {
        let month = BudgetPeriodInterval.month(startingAt: date(1), calendar: calendar)
        let today = try #require(DailyAllowanceLogic.todayInterval(in: month, now: date(4, 15), calendar: calendar))
        #expect(today.start == date(4))
        #expect(today.end == date(4, 23, 59, 59))
        #expect(!today.contains(date(5)))
    }

    @Test("Cambio de hora sin medianoche: mañana empieza en su inicio del día, no a la hora de hoy")
    func dstWithoutMidnight() throws {
        var santiago = Calendar(identifier: .gregorian)
        santiago.timeZone = try #require(TimeZone(identifier: "America/Santiago"))
        // 2026-09-06: en Chile el reloj salta de 00:00 a 01:00.
        let dayStart = try #require(santiago.date(from: DateComponents(year: 2026, month: 9, day: 6, hour: 12)))
        let monthStart = try #require(santiago.date(from: DateComponents(year: 2026, month: 9, day: 1)))
        let month = BudgetPeriodInterval.month(startingAt: monthStart, calendar: santiago)
        let today = try #require(DailyAllowanceLogic.todayInterval(in: month, now: dayStart, calendar: santiago))
        let tomorrowStart = santiago.startOfDay(for: try #require(santiago.date(byAdding: .day, value: 1, to: dayStart)))
        #expect(!today.contains(tomorrowStart))
        #expect(today.end == tomorrowStart.addingTimeInterval(-1))
    }

    @Test("Hoy fuera del período: no hay hoy que contar")
    func outsideThePeriod() {
        let october = BudgetPeriodInterval.month(startingAt: date(1, month: 10), calendar: calendar)
        #expect(DailyAllowanceLogic.todayInterval(in: october, now: date(4, 15), calendar: calendar) == nil)
    }
}

@MainActor
@Suite("Cupo del día · lo gastado hoy")
struct DailyAllowanceSpentTodayTests {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Lima") ?? .gmt
        return calendar
    }

    private func date(_ day: Int, _ hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour)) ?? .distantPast
    }

    @Test("Solo cuenta lo de hoy, con la regla de los presupuestos (sin ajustes de saldo ni ingresos)")
    func onlyTodaysSpending() {
        let account = Account(name: "Main", currencyCode: "PEN", colorHex: "#000", iconName: "creditcard", type: "bank")
        let food = Yala.Category(name: "Comida", colorHex: "#000", isIncome: false)
        let salaryCat = Yala.Category(name: "Sueldo", colorHex: "#000", isIncome: true)
        func tx(_ amount: Double, _ date: Date, _ category: Yala.Category?) -> TransactionItem {
            TransactionItem(
                date: date, amount: amount, currencyCode: "PEN", category: category, account: account,
                amountInPreferredCurrency: amount, preferredCurrencyCode: "PEN"
            )
        }
        let yesterday = tx(-80, date(3), food)
        let todayMidnight = tx(-25, calendar.startOfDay(for: date(4)), food)
        let todayNoon = tx(-40, date(4), food)
        let adjustment = tx(-500, date(4), food)
        adjustment.balanceAdjustmentType = "initial_balance"
        let salary = tx(1_000, date(4), salaryCat)
        let tomorrowMidnight = tx(-60, calendar.startOfDay(for: date(5)), food)
        let budget = Budget(currencyCode: "PEN", limitAmount: 3_000, name: "Mes", periodType: "monthly")
        let period = BudgetPeriodInterval.month(startingAt: calendar.startOfDay(for: date(1)), calendar: calendar)

        let spentToday = BudgetsViewModel.calculateSpentToday(
            budget: budget,
            transactions: [yesterday, todayMidnight, todayNoon, adjustment, salary, tomorrowMidnight],
            period: period, now: date(4, 18), calendar: calendar
        )
        #expect(spentToday == 65)
    }

    @Test("Con el período cerrado, lo gastado hoy es 0")
    func closedPeriod() {
        let budget = Budget(currencyCode: "PEN", limitAmount: 3_000, name: "Mes", periodType: "monthly")
        let october = BudgetPeriodInterval.month(
            startingAt: calendar.date(from: DateComponents(year: 2026, month: 10, day: 1)) ?? .distantPast,
            calendar: calendar
        )
        #expect(BudgetsViewModel.calculateSpentToday(
            budget: budget, transactions: [], period: october, now: date(4), calendar: calendar
        ) == 0)
    }

    @Test("El Panel y Planificación dan el mismo «gastado hoy»")
    func panelAndPlanningAgree() {
        let account = Account(name: "Main", currencyCode: "PEN", colorHex: "#000", iconName: "creditcard", type: "bank")
        let food = Yala.Category(name: "Comida", colorHex: "#000", isIncome: false)
        let spend = TransactionItem(
            date: aMomentAgoToday(), amount: -35, currencyCode: "PEN", category: food, account: account,
            amountInPreferredCurrency: -35, preferredCurrencyCode: "PEN"
        )
        let budget = Budget(currencyCode: "PEN", limitAmount: 1_000, name: "Mes", periodType: "monthly", isFavorite: true)

        let panel = PanelViewModel()
        panel.calculateBudgetsWidget(budgets: [budget], transactions: [spend], defaultCurrencyCode: "PEN")
        let panelSummary = panel.budgetsWidget.topBudgetSummaries.first

        let planning = BudgetsViewModel()
        planning.calculateBudgetData(budgets: [budget], transactions: [spend], accounts: [], defaultCurrencyCode: "PEN")
        let planningSummary = planning.groupedBudgets.flatMap(\.budgets).first

        #expect(panelSummary?.spentToday == 35)
        #expect(planningSummary?.spentToday == 35)
    }
}
