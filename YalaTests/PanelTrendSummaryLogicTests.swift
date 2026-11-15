//
//  PanelTrendSummaryLogicTests.swift
//  YalaTests
//
//  Decisión 11 de la revisión 2.3 (PN-4): la gráfica de saldo del Panel dice contra qué compara.
//   • El chip nombra la fecha REAL del período anterior, del mismo recorte que su % (`alignedPreviousReference`).
//   • Debajo, de dónde partió el saldo y dónde está, con su % (`PanelTrendSummaryLogic.startEnd`).
//   • El globo habla en «S/» y «Promedio», y el eje largo pone el año con cuatro cifras («nov 2024», no «nov 24»).
//   • El eje no arranca en cero, pero deja margen también alrededor del saldo de hoy.
//

import Foundation
import Testing

@testable import Yala

@MainActor
struct PanelTrendSummaryLogicTests {

    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Lima")!
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d))!
    }

    // MARK: - Chip: contra qué fecha compara

    @Test("El chip compara con el día equivalente del mes anterior, y lo dice con su fecha real")
    func previousReference_isTheRealDateOfTheComparedPoint() {
        let currentInterval = DateInterval(start: date(2026, 11, 1), end: date(2026, 12, 1))
        let previousInterval = DateInterval(start: date(2026, 10, 1), end: date(2026, 11, 1))
        let current = (1...20).map { BarPoint(date: date(2026, 11, $0), value: 68_000 - Double($0) * 100) }
        let previous = (1...31).map { BarPoint(date: date(2026, 10, $0), value: 58_000 + Double($0) * 10) }

        let reference = DateAlignmentHelper.alignedPreviousReference(
            previousPoints: previous, currentPoints: current,
            currentInterval: currentInterval, previousInterval: previousInterval,
            period: .thisMonth, comparisonMode: .month, calendar: cal
        )
        let total = DateAlignmentHelper.alignedPreviousTotal(
            previousPoints: previous, currentPoints: current,
            currentInterval: currentInterval, previousInterval: previousInterval,
            period: .thisMonth, comparisonMode: .month, calendar: cal
        )

        // Dominio del actual: 31 oct … 21 nov → el último punto anterior visible es el 21 oct.
        #expect(reference?.date == date(2026, 10, 21))
        #expect(reference?.value == total)
    }

    @Test("La fecha corta lleva el año solo si no es el de hoy")
    func shortDate_addsTheYearOnlyWhenItIsNotThisYear() {
        let locale = Locale(identifier: "es_PE")
        let today = date(2026, 11, 20)
        let sameYear = PanelTrendSummaryLogic.shortDate(date(2026, 10, 20), today: today, calendar: cal, locale: locale)
        let otherYear = PanelTrendSummaryLogic.shortDate(date(2025, 11, 20), today: today, calendar: cal, locale: locale)
        #expect(sameYear == "20 oct")
        #expect(otherYear.contains("2025"))
        #expect(!sameYear.contains("."))
    }

    // MARK: - Inicio → hoy

    @Test("Con el período cubriendo hoy, el final es el saldo de hoy y el % sale contra el inicio")
    func startEnd_usesTodaysBalanceAndTheChangeFromTheStart() {
        let points = (1...30).map { BarPoint(date: date(2026, 11, $0), value: 68_000) }
        let anchor = BarPoint(date: date(2026, 11, 20), value: 64_600)
        let summary = PanelTrendSummaryLogic.startEnd(
            rawPoints: points, liveAnchor: anchor, today: date(2026, 11, 20), calendar: cal)
        #expect(summary?.startDate == date(2026, 11, 1))
        #expect(summary?.startValue == 68_000)
        #expect(summary?.endValue == 64_600)
        #expect(summary?.endIsToday == true)
        #expect(summary.flatMap(\.variation).map { ($0 * 10).rounded() / 10 } == -5)
    }

    @Test("Un período cerrado acaba en su último punto, con su fecha")
    func startEnd_closedPeriod_endsOnItsLastPoint() {
        let points = (1...31).map { BarPoint(date: date(2026, 10, $0), value: 1_000 + Double($0)) }
        let summary = PanelTrendSummaryLogic.startEnd(
            rawPoints: points, liveAnchor: nil, today: date(2026, 11, 20), calendar: cal)
        #expect(summary?.endDate == date(2026, 10, 31))
        #expect(summary?.endIsToday == false)
    }

    @Test("Con un solo día no hay recorrido: no sale la fila (la gráfica se queda con su punto)")
    func startEnd_singleDay_isNil() {
        let points = [BarPoint(date: date(2026, 12, 1), value: 81_445)]
        let anchor = BarPoint(date: date(2026, 12, 1), value: 81_445)
        #expect(PanelTrendSummaryLogic.startEnd(
            rawPoints: points, liveAnchor: anchor, today: date(2026, 12, 1), calendar: cal) == nil)
    }

    @Test("Partiendo de 0 no hay porcentaje que valga")
    func startEnd_fromZero_hasNoVariation() {
        let points = [BarPoint(date: date(2026, 11, 1), value: 0), BarPoint(date: date(2026, 11, 2), value: 500)]
        let summary = PanelTrendSummaryLogic.startEnd(
            rawPoints: points, liveAnchor: nil, today: date(2026, 11, 2), calendar: cal)
        #expect(summary != nil)
        #expect(summary?.variation == nil)
    }

    // MARK: - Eje largo

    @MainActor
    @Test("Con varios años el eje pone el año con cuatro cifras, no «nov 24»")
    func axisLabel_multipleYears_hasAFourDigitYear() {
        let label = SmartAxisHelper.formatAxisLabel(
            for: date(2024, 11, 15), startDate: date(2024, 11, 1), endDate: date(2026, 11, 1), forceGrouping: .month)
        #expect(label.contains("2024"))
        let spanLabel = SmartAxisHelper.formatAxisLabel(
            for: date(2025, 11, 15), startDate: date(2024, 11, 1), endDate: date(2026, 11, 1))
        #expect(spanLabel.contains("2025"))
    }

    // MARK: - Margen del eje

    @Test("El saldo de hoy fuera del rango de la curva no queda pegado al borde del eje")
    func yDomain_keepsAMarginAroundTodaysBalance() {
        let now = Date()
        let start = Calendar.current.date(byAdding: .day, value: -10, to: Calendar.current.startOfDay(for: now))!
        let interval = DateInterval(start: start, end: now.addingTimeInterval(1))
        let account = Account(name: "Principal", currencyCode: "PEN", colorHex: "#6366F1", iconName: "banknote", type: "bank")
        let tx = TransactionItem(
            date: start.addingTimeInterval(3600), amount: 10_000, currencyCode: "PEN", note: nil, category: nil,
            amountInPreferredCurrency: 10_000, preferredCurrencyCode: "PEN")
        tx.account = account
        let result = TrendDataProcessor.processTrendData(
            transactions: [tx],
            accounts: [account],
            metric: .balance,
            period: .last30Days,
            grouping: .day,
            interval: interval,
            currencyCode: "PEN",
            liveBalanceOverride: .init(value: 2_000, nativeBalances: ["PEN": 2_000], amountsAreApproximate: false)
        )
        #expect(result.liveAnchor != nil)
        // Antes el dominio se ensanchaba justo hasta el saldo de hoy: el punto quedaba en el borde inferior.
        #expect(result.yDomain.lowerBound < 2_000)
    }
}
