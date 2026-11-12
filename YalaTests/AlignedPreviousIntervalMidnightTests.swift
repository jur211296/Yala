//
//  AlignedPreviousIntervalMidnightTests.swift
//  YalaTests
//
//  Ticket `aligned-previous-interval-counts-the-next-midnight`: el «vs mes pasado» de los heros de Tendencias
//  (`InsightsCalculator`) y del Panel (`HeroBucketsCalculator`) contaba un gasto del día SIGUIENTE al equivalente si
//  se fechó a medianoche (lo que guarda el selector de fecha). Hoy es 15 de abril: «el mes pasado hasta hoy» es del
//  1 al 15 de marzo, y un gasto del 16 de marzo a las 00:00 no entra.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("vs mes pasado · el día siguiente a medianoche no entra en el tramo del mes pasado")
struct AlignedPreviousIntervalMidnightTests {

    private let calendar = Calendar.current

    private func day(_ y: Int, _ m: Int, _ d: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: hour)) ?? .distantPast
    }

    private let account = Account(name: "Main", currencyCode: "USD", colorHex: "#6366F1", iconName: "creditcard", type: "bank")
    private let food = YalaCategory(name: "Food", colorHex: "#FF0000", isIncome: false)

    private func expense(_ amount: Double, on date: Date) -> TransactionItem {
        let tx = TransactionItem(
            date: date, amount: -amount, currencyCode: "USD", note: "", category: food, account: account,
            tags: [], amountInPreferredCurrency: -amount
        )
        tx.preferredCurrencyCode = "USD"
        return tx
    }

    /// 100 en abril (en curso), 100 el 2 de marzo y 50 el 16 de marzo a las 00:00. Con el bug, «el mes pasado hasta
    /// hoy» suma 150; sin él, 100.
    private var corpus: [TransactionItem] {
        [expense(100, on: day(2026, 4, 2, hour: 10)),
         expense(100, on: day(2026, 3, 2, hour: 10)),
         expense(50, on: day(2026, 3, 16))]
    }

    private var now: Date { day(2026, 4, 15, hour: 12) }

    @Test("Hero del Panel: el previo alineado no suma el gasto del 16 a medianoche")
    func panelHero() throws {
        let current = DetailPeriod.thisMonth.dateInterval(now: now)
        let previo = try #require(HeroBucketsCalculator.periodPreviousInterval(
            period: .thisMonth, currentInterval: current, now: now, calendar: calendar))
        #expect(!previo.contains(day(2026, 3, 16)))
        #expect(previo.contains(day(2026, 3, 15, hour: 23)))

        let buckets = HeroBucketsCalculator.calculate(
            transactions: corpus,
            monthInterval: current,
            prevInterval: PreviousPeriodHelper.previousInterval(for: .thisMonth, mode: .month, now: now),
            periodInterval: current,
            periodPrevInterval: previo,
            eligibleAccountIDs: [account.persistentModelID],
            currencyCode: "USD"
        )
        #expect(buckets.periodExpense == 100)
        #expect(buckets.periodPrevExpense == 100, "con el bug: 150 (\(buckets.periodPrevExpense))")
    }

    @Test("Hero de Tendencias: la variación del gasto compara 100 con 100, no con 150")
    func trendsHero() {
        let data = InsightsCalculator.calculate(
            transactions: corpus, accounts: [account], categories: [food], budgets: [], scheduledPayments: [],
            period: .thisMonth, criteria: FilterCriteria(), currencyCode: "USD", customRange: nil, now: now
        )
        let variation = data.periodSummary.expenseVariation ?? .nan
        #expect(abs(variation) < 0.0001, "con el bug, el mes pasado suma 150 y la variación no es 0 (\(variation))")
    }

    @Test("Control: el gasto del día equivalente a última hora sí entra")
    func control() {
        var txs = corpus
        txs.append(expense(30, on: day(2026, 3, 15, hour: 23)))
        let current = DetailPeriod.thisMonth.dateInterval(now: now)
        let previo = HeroBucketsCalculator.periodPreviousInterval(
            period: .thisMonth, currentInterval: current, now: now, calendar: calendar)
        let buckets = HeroBucketsCalculator.calculate(
            transactions: txs,
            monthInterval: current,
            prevInterval: PreviousPeriodHelper.previousInterval(for: .thisMonth, mode: .month, now: now),
            periodInterval: current,
            periodPrevInterval: previo,
            eligibleAccountIDs: [account.persistentModelID],
            currencyCode: "USD"
        )
        #expect(buckets.periodPrevExpense == 130)
    }
}
