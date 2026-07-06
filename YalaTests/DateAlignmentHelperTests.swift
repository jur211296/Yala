//
//  DateAlignmentHelperTests.swift
//  YalaTests
//
//  Tests puros para la alineación temporal de la comparación de períodos
//  (MTD-vs-MTD, ticket p20-15). Sin ModelContext; `calendar` determinista.
//

import Foundation
import Testing

@testable import Yala

struct DateAlignmentHelperTests {

    // MARK: - Fixtures

    /// Gregoriano en zona sin DST (Lima, UTC-5) para fechas deterministas.
    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Lima")!
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d))!
    }

    /// Réplica INDEPENDIENTE del pipeline de `PeriodComparisonChartView`
    /// (`dataXDomain` + `clippedPreviousPoints`) para el guard de coherencia:
    /// el KPI del período anterior debe ser exactamente el último punto VISIBLE
    /// de la curva anterior.
    private func manualClippedLastValue(
        previous: [BarPoint],
        current: [BarPoint],
        currentInterval: DateInterval,
        previousInterval: DateInterval,
        period: DetailPeriod,
        mode: ComparisonMode
    ) -> Double? {
        let fPrev = previous.filter { $0.value != 0 }
        guard !fPrev.isEmpty else { return nil }
        let fCurrent = current.filter { $0.value != 0 }
        let domain: ClosedRange<Date>
        if let f = fCurrent.first?.date, let l = fCurrent.last?.date {
            let lower = cal.date(byAdding: .day, value: -1, to: f) ?? f
            let upper = cal.date(byAdding: .day, value: 1, to: l) ?? l
            domain = lower...upper
        } else {
            domain = currentInterval.start...currentInterval.end
        }
        let clipped = fPrev.compactMap { p -> BarPoint? in
            let adj = DateAlignmentHelper.adjustDateToCurrent(
                p.date,
                currentInterval: currentInterval,
                previousInterval: previousInterval,
                period: period,
                comparisonMode: mode,
                calendar: cal
            )
            guard adj >= domain.lowerBound && adj <= domain.upperBound else { return nil }
            return BarPoint(date: adj, value: p.value)
        }.sorted { $0.date < $1.date }
        return clipped.last?.value
    }

    // MARK: - Caso central: thisMonth en curso trunca (MTD), no usa fin de mes

    @Test("thisMonth en curso: usa el día equivalente del actual, no el fin del mes anterior")
    func alignedPreviousTotal_thisMonthInProgress_truncaAlDiaEquivalente() {
        // Actual: julio con datos solo hasta el día 4 (mes en curso).
        let currentInterval = DateInterval(start: date(2026, 7, 1), end: date(2026, 8, 1))
        let previousInterval = DateInterval(start: date(2026, 6, 1), end: date(2026, 7, 1))

        let current = [
            BarPoint(date: date(2026, 7, 1), value: 17_000),
            BarPoint(date: date(2026, 7, 2), value: 17_200),
            BarPoint(date: date(2026, 7, 3), value: 17_400),
            BarPoint(date: date(2026, 7, 4), value: 17_520),
        ]
        // Anterior: junio completo. Balance ALTO temprano y BAJO al final
        // (el escenario del bug: fin-de-mes ≠ día-equivalente).
        var previous: [BarPoint] = []
        for d in 1...30 {
            let v: Double
            switch d {
            case 1: v = 23_000
            case 2: v = 23_500
            case 3: v = 23_800
            case 4: v = 24_122
            case 5: v = 24_000
            default: v = 12_000  // fin de mes muy por debajo
            }
            previous.append(BarPoint(date: date(2026, 6, d), value: v))
        }

        let result = DateAlignmentHelper.alignedPreviousTotal(
            previousPoints: previous,
            currentPoints: current,
            currentInterval: currentInterval,
            previousInterval: previousInterval,
            period: .thisMonth,
            comparisonMode: .month,
            calendar: cal
        )

        // dataXDomain = [jul1-1d … jul4+1d] = [jun30 … jul5]; jun N → jul N.
        // Último punto visible = jun5 (→ jul5), NO jun30 (fin de mes = el bug).
        #expect(result == 24_000)
        #expect(result != previous.last?.value)  // ≠ fin de junio (12_000)
    }

    // MARK: - Guard de coherencia: KPI == último punto visible de la curva

    @Test("Coherencia con la curva — modo mes (dayOfMonth)")
    func alignedPreviousTotal_equalsClippedCurve_month() {
        let currentInterval = DateInterval(start: date(2026, 7, 1), end: date(2026, 8, 1))
        let previousInterval = DateInterval(start: date(2026, 6, 1), end: date(2026, 7, 1))
        let current = (1...4).map { BarPoint(date: date(2026, 7, $0), value: Double(17_000 + $0 * 100)) }
        let previous = (1...30).map { BarPoint(date: date(2026, 6, $0), value: Double(20_000 - $0 * 200)) }

        let result = DateAlignmentHelper.alignedPreviousTotal(
            previousPoints: previous, currentPoints: current,
            currentInterval: currentInterval, previousInterval: previousInterval,
            period: .thisMonth, comparisonMode: .month, calendar: cal
        )
        let expected = manualClippedLastValue(
            previous: previous, current: current,
            currentInterval: currentInterval, previousInterval: previousInterval,
            period: .thisMonth, mode: .month
        )
        #expect(result == expected)
    }

    @Test("Coherencia con la curva — modo año (calendarYear)")
    func alignedPreviousTotal_equalsClippedCurve_year() {
        let currentInterval = DateInterval(start: date(2026, 7, 1), end: date(2026, 8, 1))
        let previousInterval = DateInterval(start: date(2025, 7, 1), end: date(2025, 8, 1))
        let current = (1...4).map { BarPoint(date: date(2026, 7, $0), value: Double(17_000 + $0 * 100)) }
        let previous = (1...31).map { BarPoint(date: date(2025, 7, $0), value: Double(15_000 + $0 * 50)) }

        let result = DateAlignmentHelper.alignedPreviousTotal(
            previousPoints: previous, currentPoints: current,
            currentInterval: currentInterval, previousInterval: previousInterval,
            period: .thisMonth, comparisonMode: .year, calendar: cal
        )
        let expected = manualClippedLastValue(
            previous: previous, current: current,
            currentInterval: currentInterval, previousInterval: previousInterval,
            period: .thisMonth, mode: .year
        )
        #expect(result == expected)
        // A-1 también trunca: NO devuelve el fin de julio 2025.
        #expect(result != previous.last?.value)
    }

    @Test("Coherencia con la curva — semana (dayOfWeek)")
    func alignedPreviousTotal_equalsClippedCurve_week() {
        // Semana actual arranca lunes 6-jul-2026; semana anterior lunes 29-jun.
        let currentInterval = DateInterval(start: date(2026, 7, 6), end: date(2026, 7, 13))
        let previousInterval = DateInterval(start: date(2026, 6, 29), end: date(2026, 7, 6))
        let current = (6...9).map { BarPoint(date: date(2026, 7, $0), value: Double(1_000 + $0)) }
        let previous = (29...30).map { BarPoint(date: date(2026, 6, $0), value: Double(500 + $0)) }
            + (1...5).map { BarPoint(date: date(2026, 7, $0), value: Double(600 + $0)) }

        let result = DateAlignmentHelper.alignedPreviousTotal(
            previousPoints: previous, currentPoints: current,
            currentInterval: currentInterval, previousInterval: previousInterval,
            period: .thisWeek, comparisonMode: .month, calendar: cal
        )
        let expected = manualClippedLastValue(
            previous: previous, current: current,
            currentInterval: currentInterval, previousInterval: previousInterval,
            period: .thisWeek, mode: .month
        )
        #expect(result == expected)
    }

    // MARK: - Períodos cerrados: sin colapsar al inicio del anterior

    @Test("lastMonth cerrado: resultado en la zona final del anterior, no el inicio")
    func alignedPreviousTotal_lastMonthClosed_noColapsaAlInicio() {
        // Actual = junio completo (cerrado); anterior = mayo completo.
        let currentInterval = DateInterval(start: date(2026, 6, 1), end: date(2026, 7, 1))
        let previousInterval = DateInterval(start: date(2026, 5, 1), end: date(2026, 6, 1))
        let current = (1...30).map { BarPoint(date: date(2026, 6, $0), value: Double(8_000 + $0)) }
        // Mayo: inicio bajo (5_000), final estable alto (9_000).
        let previous = (1...31).map { BarPoint(date: date(2026, 5, $0), value: $0 <= 3 ? 5_000.0 : 9_000.0) }

        let result = DateAlignmentHelper.alignedPreviousTotal(
            previousPoints: previous, currentPoints: current,
            currentInterval: currentInterval, previousInterval: previousInterval,
            period: .lastMonth, comparisonMode: .month, calendar: cal
        )
        let expected = manualClippedLastValue(
            previous: previous, current: current,
            currentInterval: currentInterval, previousInterval: previousInterval,
            period: .lastMonth, mode: .month
        )
        #expect(result == expected)
        // Coincide con la curva y NO colapsa al valor del inicio de mayo.
        #expect(result == 9_000)
    }

    // MARK: - Bordes

    @Test("Período anterior vacío → nil")
    func alignedPreviousTotal_previousEmpty_nil() {
        let currentInterval = DateInterval(start: date(2026, 7, 1), end: date(2026, 8, 1))
        let previousInterval = DateInterval(start: date(2026, 6, 1), end: date(2026, 7, 1))
        let current = (1...4).map { BarPoint(date: date(2026, 7, $0), value: 100) }

        let result = DateAlignmentHelper.alignedPreviousTotal(
            previousPoints: [], currentPoints: current,
            currentInterval: currentInterval, previousInterval: previousInterval,
            period: .thisMonth, comparisonMode: .month, calendar: cal
        )
        #expect(result == nil)
    }

    @Test("Período anterior todo ceros → nil")
    func alignedPreviousTotal_previousAllZeros_nil() {
        let currentInterval = DateInterval(start: date(2026, 7, 1), end: date(2026, 8, 1))
        let previousInterval = DateInterval(start: date(2026, 6, 1), end: date(2026, 7, 1))
        let current = (1...4).map { BarPoint(date: date(2026, 7, $0), value: 100) }
        let previous = (1...30).map { BarPoint(date: date(2026, 6, $0), value: 0) }

        let result = DateAlignmentHelper.alignedPreviousTotal(
            previousPoints: previous, currentPoints: current,
            currentInterval: currentInterval, previousInterval: previousInterval,
            period: .thisMonth, comparisonMode: .month, calendar: cal
        )
        #expect(result == nil)
    }

    // MARK: - Edge case de calendario (mes de distinta longitud)

    @Test("dayOfMonth con día inexistente en el mes destino: no crashea (comportamiento heredado)")
    func adjustDateToCurrent_dayOfMonth_dayOverflow_noCrash() {
        // Anterior enero día 31 → febrero (28 días en 2026). Foundation NORMALIZA
        // por rollover (`Calendar.date(from:)` no devuelve nil sino feb31→mar3),
        // por lo que la rama de fallback del código queda inofensiva pero muerta.
        // Comportamiento HEREDADO de PeriodComparisonChartView — el fix NO lo
        // altera (cambiarlo movería la curva, fuera de scope de p20-15). Deuda
        // preexistente documentada: un punto día-31 del anterior se mapea fuera
        // del mes destino y la curva lo clippea (caso muy borde).
        let currentInterval = DateInterval(start: date(2026, 2, 1), end: date(2026, 3, 1))
        let previousInterval = DateInterval(start: date(2026, 1, 1), end: date(2026, 2, 1))

        let adjusted = DateAlignmentHelper.adjustDateToCurrent(
            date(2026, 1, 31),
            currentInterval: currentInterval,
            previousInterval: previousInterval,
            period: .thisMonth,
            comparisonMode: .month,
            calendar: cal
        )
        // No crashea y devuelve una fecha válida (fin-feb / inicio-mar por rollover).
        #expect(adjusted > date(2026, 2, 27))
        #expect(adjusted < date(2026, 3, 5))
    }
}
