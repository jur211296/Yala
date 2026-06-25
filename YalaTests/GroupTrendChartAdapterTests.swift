//
//  GroupTrendChartAdapterTests.swift
//  YalaTests
//
//  Pure-logic del adaptador que convierte la tendencia mensual de un grupo en
//  los inputs de TrendChartView (points / yDomain / interval). Sin contexto.
//

import Foundation
import Testing

@testable import Yala

struct GroupTrendChartAdapterTests {

    /// Primer día del mes indicado (calendario gregoriano), como produce el ViewModel.
    private func month(_ year: Int, _ month: Int) -> Date {
        var c = DateComponents()
        c.year = year
        c.month = month
        c.day = 1
        return Calendar(identifier: .gregorian).date(from: c)!
    }

    @Test func returnsNil_whenFewerThanTwoMonths() {
        #expect(GroupTrendChartAdapter.makeInput(from: []) == nil)
        #expect(GroupTrendChartAdapter.makeInput(
            from: [GroupMonthlyTrend(month: month(2025, 1), totalSpent: 100)]) == nil)
    }

    @Test func mapsMonthsToBarPoints_inOrder() {
        let trend = [
            GroupMonthlyTrend(month: month(2025, 1), totalSpent: 100),
            GroupMonthlyTrend(month: month(2025, 2), totalSpent: 200),
            GroupMonthlyTrend(month: month(2025, 3), totalSpent: 150),
        ]
        let input = GroupTrendChartAdapter.makeInput(from: trend)
        #expect(input?.points.map(\.value) == [100, 200, 150])
        #expect(input?.points.map(\.date) == [month(2025, 1), month(2025, 2), month(2025, 3)])
    }

    @Test func yDomain_usesTenPercentPadding() {
        let trend = [
            GroupMonthlyTrend(month: month(2025, 1), totalSpent: 100),
            GroupMonthlyTrend(month: month(2025, 2), totalSpent: 200),
        ]
        // padding = (200 - 100) * 0.1 = 10 → 90...210
        #expect(GroupTrendChartAdapter.makeInput(from: trend)?.yDomain == 90.0...210.0)
    }

    @Test func yDomain_handlesDegenerateEqualValues() {
        let trend = [
            GroupMonthlyTrend(month: month(2025, 1), totalSpent: 500),
            GroupMonthlyTrend(month: month(2025, 2), totalSpent: 500),
        ]
        let input = GroupTrendChartAdapter.makeInput(from: trend)
        // pad = max(500 * 0.1, 1) = 50 → 450...550 (rango válido, no degenerado)
        #expect(input?.yDomain == 450.0...550.0)
        if let domain = input?.yDomain {
            #expect(domain.upperBound > domain.lowerBound)
        }
    }

    @Test func interval_spansFirstToLastMonth() {
        let trend = [
            GroupMonthlyTrend(month: month(2025, 1), totalSpent: 100),
            GroupMonthlyTrend(month: month(2025, 2), totalSpent: 200),
            GroupMonthlyTrend(month: month(2025, 3), totalSpent: 150),
        ]
        let input = GroupTrendChartAdapter.makeInput(from: trend)
        #expect(input?.interval.start == month(2025, 1))
        #expect(input?.interval.end == month(2025, 3))
    }

    // MARK: - smartLabelDates

    @Test func smartLabels_returnsAll_whenFewMonths() {
        let points = (1...4).map { BarPoint(date: month(2025, $0), value: Double($0 * 100)) }
        let labels = GroupTrendChartAdapter.smartLabelDates(points: points, maxLabels: 6)
        #expect(labels == Set(points.map(\.date)))
    }

    @Test func smartLabels_subsets_whenManyMonths() {
        // 12 meses, máx 6 → subconjunto, nunca los 12.
        let points = (1...12).map { BarPoint(date: month(2025, $0), value: Double($0 * 100)) }
        let labels = GroupTrendChartAdapter.smartLabelDates(points: points, maxLabels: 6)
        #expect(labels.count < points.count)
        #expect(labels.count <= 7) // ~maxLabels + el último forzado
        // siempre el primero y el último (más reciente)
        #expect(labels.contains(points.first!.date))
        #expect(labels.contains(points.last!.date))
    }

    @Test func smartLabels_empty_whenNoPoints() {
        #expect(GroupTrendChartAdapter.smartLabelDates(points: [], maxLabels: 6).isEmpty)
    }
}
