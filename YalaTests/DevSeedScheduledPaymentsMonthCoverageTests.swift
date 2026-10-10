//
//  DevSeedScheduledPaymentsMonthCoverageTests.swift
//  YalaTests
//
//  El perfil `minimal` tiene que dejar al menos un pago en «Este mes» CUALQUIER día del año.
//  Ticket `scheduled-payment-skip-uitests-fail-at-the-end-of-the-month`: los 8 pagos del fixture van
//  del día 3 al 28 y `ScheduledPaymentDateCalculator` descarta las fechas anteriores a `createdAt`
//  (el día de la siembra), así que sembrando del 29 en adelante el mes en curso quedaba vacío y
//  `ScheduledPaymentSkipUITests` no tenía fila que tocar.
//
//  Se mide con el MISMO predicado que la lista (`ScheduledPaymentsViewModel.calculatePaymentData`
//  filtra por `getPaymentDatesInMonth`, que delega en el calculador) y con `today` inyectado, en vez
//  de esperar a fin de mes.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite(.serialized)
struct DevSeedScheduledPaymentsMonthCoverageTests {

    private let calendar = Calendar.current

    private func noon(_ year: Int, _ month: Int, _ day: Int) -> Date? {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))
    }

    private func makeAccount(in context: ModelContext) -> Account {
        let account = Account(name: "Soles", currencyCode: "PEN", colorHex: "#000000", iconName: "banknote", type: "bank")
        context.insert(account)
        return account
    }

    /// Todos los días de 2026, más febrero de 2028 (bisiesto: el 29 existe).
    private func everyDayToCheck() -> [Date] {
        var days: [Date] = []
        for month in 1...12 {
            guard let first = noon(2026, month, 1),
                  let count = calendar.range(of: .day, in: .month, for: first)?.count else { continue }
            days += (1...count).compactMap { noon(2026, month, $0) }
        }
        days += (1...29).compactMap { noon(2028, 2, $0) }
        return days
    }

    @Test func minimalSeed_leavesAPaymentInTheCurrentMonth_everyDayOfTheYear() throws {
        let context = try makeTestContext()
        let account = makeAccount(in: context)

        let emptyDays = everyDayToCheck().filter { today in
            let result = DevSeedScheduledPayments.create(
                account: account,
                subcategoryLookup: [:],
                today: today,
                includeEndOfMonthPayment: true,
                in: context
            )
            return !result.payments.contains { payment in
                !ScheduledPaymentDateCalculator.paymentDatesInMonth(
                    params: payment.dateCalculatorParams, month: today, calendar: calendar
                ).isEmpty
            }
        }
        #expect(emptyDays.isEmpty, "«Este mes» sin pagos sembrando en: \(emptyDays)")
    }

    @Test func endOfMonthPayment_fallsOnTheLastDayOfTheSeedMonth() throws {
        let context = try makeTestContext()
        let account = makeAccount(in: context)

        let cases: [(today: Date?, lastDay: Int)] = [
            (noon(2026, 2, 10), 28), (noon(2028, 2, 29), 29), (noon(2026, 4, 30), 30), (noon(2026, 10, 1), 31),
        ]
        for (maybeToday, lastDay) in cases {
            let today = try #require(maybeToday)
            let result = DevSeedScheduledPayments.create(
                account: account, subcategoryLookup: [:], today: today, includeEndOfMonthPayment: true, in: context
            )
            let payment = try #require(result.payments.first { $0.name == DevSeedScheduledPayments.endOfMonthName })
            let dates = ScheduledPaymentDateCalculator.paymentDatesInMonth(
                params: payment.dateCalculatorParams, month: today, calendar: calendar
            )
            #expect(dates.map { calendar.component(.day, from: $0) } == [lastDay])
            #expect(calendar.isDate(payment.nextDueDate, equalTo: today, toGranularity: .month))
        }
    }

    /// Fuera de `minimal` el fixture sigue siendo el de siempre: `realista` y los demás perfiles no lo ven.
    @Test func endOfMonthPayment_isOffByDefault() throws {
        let context = try makeTestContext()
        let account = makeAccount(in: context)

        let result = DevSeedScheduledPayments.create(account: account, subcategoryLookup: [:], in: context)
        #expect(result.payments.count == 8)
        #expect(!result.payments.contains { $0.name == DevSeedScheduledPayments.endOfMonthName })
    }

    // MARK: - `-uitest-scheduled-seed-day`

    @Test func seedDate_clampsToTheMonthAndLandsAtNoon() throws {
        let feb = try #require(noon(2026, 2, 10))
        let last = try #require(UITestHooks.seedDate(dayOfCurrentMonth: 31, now: feb, calendar: calendar))
        let parts = calendar.dateComponents([.year, .month, .day, .hour], from: last)
        #expect(parts.year == 2026 && parts.month == 2 && parts.day == 28 && parts.hour == 12)

        let first = try #require(UITestHooks.seedDate(dayOfCurrentMonth: 0, now: feb, calendar: calendar))
        #expect(calendar.component(.day, from: first) == 1)
        #expect(calendar.isDate(first, equalTo: feb, toGranularity: .month))
    }
}
