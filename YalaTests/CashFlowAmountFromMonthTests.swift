//
//  CashFlowAmountFromMonthTests.swift
//  YalaTests
//
//  Auditoría UX 2.2 · L18-8 (opción A de Jürgen): «Este mes y los siguientes» cambiaba también los meses anteriores,
//  porque pasaba la línea entera a «monto fijo». Ahora la línea guarda desde qué mes vale el monto nuevo. Lo que fija:
//   - la lógica pura del formato y de qué cambio vale para cada mes;
//   - en el plan: un cambio desde un mes que viene no toca el mes en curso ni los pasados; el ajuste de un solo mes
//     gana; un segundo cambio más adelante no borra el primero;
//   - en el ViewModel: «y los siguientes» no toca el método de la línea, retira el ajuste de ese mes, y cambiar el
//     método («Cómo se calcula · Cambiar», L18-7) retira los cambios.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

// MARK: - Lógica pura

struct CashFlowAmountChangeLogicTests {

    typealias Logic = CashFlowAmountChangeLogic

    @Test func parse_roundTripsWhatEncodeWrites_sortedByMonth() {
        let changes = [Logic.Change(monthKey: "2027-02", amount: 9500), Logic.Change(monthKey: "2026-11", amount: 9000.5)]
        let raw = Logic.encode(changes)
        #expect(raw == "2026-11=9000.5,2027-02=9500.0")
        #expect(Logic.parse(raw) == changes.sorted { $0.monthKey < $1.monthKey })
    }

    @Test func parse_dropsWhatItCannotUnderstand() {
        let parsed = Logic.parse("2026-11=9000,basura,2026-13=5,2026-12=-3,2027-01=,2027-02=abc,2027-03=10")
        #expect(parsed == [Logic.Change(monthKey: "2026-11", amount: 9000), Logic.Change(monthKey: "2027-03", amount: 10)])
    }

    /// Un mes que ordena antes de tiempo como texto («2026--05» < «2026-01») no se acepta.
    @Test func parse_rejectsMalformedMonthKeys() {
        let parsed = Logic.parse("2026--05=1,-2026-05=2,+026-05=3,2026-5=4,２０２６-05=5,2026-05=6")
        #expect(parsed == [Logic.Change(monthKey: "2026-05", amount: 6)])
    }

    @Test func encode_withoutChanges_isNil() {
        #expect(Logic.encode([]) == nil)
        #expect(Logic.parse(nil).isEmpty)
        #expect(Logic.parse("").isEmpty)
    }

    @Test func change_forAMonth_isTheLastOneOnOrBeforeIt() {
        let changes = Logic.parse("2026-11=9000,2027-02=9500")
        #expect(Logic.change(for: "2026-10", in: changes) == nil, "antes del primer cambio, el método de la línea")
        #expect(Logic.change(for: "2026-11", in: changes)?.amount == 9000)
        #expect(Logic.change(for: "2027-01", in: changes)?.amount == 9000)
        #expect(Logic.change(for: "2027-02", in: changes)?.amount == 9500)
        #expect(Logic.change(for: "2027-06", in: changes)?.amount == 9500)
    }

    @Test func applying_dropsLaterChanges_keepsEarlierOnes() {
        let changes = Logic.parse("2026-11=9000,2027-02=9500,2027-05=9800")
        let updated = Logic.applying(.init(monthKey: "2027-02", amount: 1000), to: changes)
        #expect(updated == [Logic.Change(monthKey: "2026-11", amount: 9000), Logic.Change(monthKey: "2027-02", amount: 1000)])
    }
}

// MARK: - En el plan

@Suite(.serialized)
@MainActor
struct CashFlowAmountFromMonthProjectionTests {

    private let calendar = Calendar.current

    private var currentMonthStart: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: .now)) ?? .now
    }

    private func key(monthsFromNow offset: Int) -> String {
        let date = calendar.date(byAdding: .month, value: offset, to: currentMonthStart) ?? currentMonthStart
        return CashFlowProjectionCalculator.monthKey(for: date, calendar: calendar)
    }

    private func project(_ line: CashFlowLine, plan: CashFlowPlan) -> CashFlowProjection {
        CashFlowProjectionCalculator.calculate(
            plan: plan, lines: [line], transactions: [],
            allExpenseCategories: [], scheduledPayments: [],
            monthsBack: 2, monthsAhead: 4,
            currencyCode: "USD", converter: MockCurrencyConverter()
        )
    }

    private func planned(_ projection: CashFlowProjection, monthsFromNow offset: Int) -> CashFlowLineResult? {
        projection.months.first { $0.monthKey == key(monthsFromNow: offset) }?.expenseLines.first
    }

    @Test func aChangeFromNextMonth_leavesThePastAndTheCurrentMonthAlone() {
        let plan = CashFlowPlan(name: "", startingBalance: 0)
        let line = CashFlowLine(name: "Alquiler", estimationMethod: .manual, manualAmount: 100)
        line.amountChangesRaw = CashFlowAmountChangeLogic.encode([.init(monthKey: key(monthsFromNow: 1), amount: 200)])

        let projection = project(line, plan: plan)

        #expect(planned(projection, monthsFromNow: -2)?.plannedAmount == 100, "un mes pasado sigue con su monto")
        #expect(planned(projection, monthsFromNow: -1)?.plannedAmount == 100)
        #expect(planned(projection, monthsFromNow: 0)?.plannedAmount == 100, "el mes en curso, también")
        #expect(planned(projection, monthsFromNow: 1)?.plannedAmount == 200, "desde el mes del cambio, el monto nuevo")
        #expect(planned(projection, monthsFromNow: 4)?.plannedAmount == 200)
        #expect(planned(projection, monthsFromNow: 1)?.amountChangeFromMonthKey == key(monthsFromNow: 1))
        #expect(planned(projection, monthsFromNow: 0)?.amountChangeFromMonthKey == nil)
        #expect(planned(projection, monthsFromNow: 1)?.isOverride == false, "un cambio de varios meses no es un ajuste")
    }

    @Test func aSecondChangeLater_keepsTheFirstOneInBetween() {
        let plan = CashFlowPlan(name: "", startingBalance: 0)
        let line = CashFlowLine(name: "Salario", isIncome: true, estimationMethod: .manual, manualAmount: 8500)
        line.amountChangesRaw = CashFlowAmountChangeLogic.encode([
            .init(monthKey: key(monthsFromNow: 1), amount: 9000),
            .init(monthKey: key(monthsFromNow: 3), amount: 9500),
        ])

        let projection = project(line, plan: plan)
        let incomes = { (offset: Int) in
            projection.months.first { $0.monthKey == self.key(monthsFromNow: offset) }?.incomeLines.first?.plannedAmount
        }

        #expect(incomes(0) == 8500)
        #expect(incomes(1) == 9000)
        #expect(incomes(2) == 9000, "el segundo cambio no borra el primero")
        #expect(incomes(3) == 9500)
        #expect(incomes(4) == 9500)
    }

    @Test func aOneMonthAdjustment_winsOverAChange() throws {
        let context = try makeTestContext()
        let plan = CashFlowPlan(name: "", startingBalance: 0)
        context.insert(plan)
        let line = CashFlowLine(name: "Luz", estimationMethod: .manual, manualAmount: 100)
        context.insert(line)
        line.plan = plan
        line.amountChangesRaw = CashFlowAmountChangeLogic.encode([.init(monthKey: key(monthsFromNow: 1), amount: 200)])
        let override = CashFlowOverride(monthKey: key(monthsFromNow: 2), amount: 50)
        context.insert(override)
        override.cashFlowLine = line
        try context.save()

        let projection = project(line, plan: plan)

        #expect(planned(projection, monthsFromNow: 1)?.plannedAmount == 200)
        #expect(planned(projection, monthsFromNow: 2)?.plannedAmount == 50, "el ajuste de un solo mes gana")
        #expect(planned(projection, monthsFromNow: 2)?.isOverride == true)
        #expect(planned(projection, monthsFromNow: 3)?.plannedAmount == 200)
    }
}
