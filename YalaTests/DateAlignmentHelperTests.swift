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

    // MARK: - alignedPreviousInterval (MTD) — hero de Estadísticas (D2 p20-15)

    @Test("thisMonth+month en curso: trunca el previo al día equivalente")
    func alignedPreviousInterval_thisMonthMidMonth_trunca() {
        // Hoy día 6 de julio (endOfToday = jul 7).
        let currentInterval = DateInterval(start: date(2026, 7, 1), end: date(2026, 7, 7))
        let previousInterval = DateInterval(start: date(2026, 6, 1), end: date(2026, 7, 1))

        let result = DateAlignmentHelper.alignedPreviousInterval(
            currentInterval: currentInterval,
            previousInterval: previousInterval,
            asOf: date(2026, 7, 6),
            period: .thisMonth,
            comparisonMode: .month,
            calendar: cal
        )

        #expect(result.start == date(2026, 6, 1))
        #expect(result.end == date(2026, 6, 7))          // FIN del día equivalente (jun 6 completo)
        #expect(result.end != previousInterval.end)      // ≠ fin de junio (jul 1)
        // Simetría MTD: una TX de la TARDE del día equivalente entra (como su gemela
        // actual jul 6 14:00); el día siguiente ya NO.
        #expect(result.contains(date(2026, 6, 6).addingTimeInterval(14 * 3600)))
        #expect(!result.contains(date(2026, 6, 7).addingTimeInterval(60)))
    }

    @Test("thisMonth+month, mes destino más corto (mar 31 → feb): clamp = mes completo")
    func alignedPreviousInterval_edgeMesCorto_clampMesCompleto() {
        // Hoy 31 de marzo; previo = febrero (28 días en 2026). day=31 rueda a mar 3,
        // el clamp lo capa a previousInterval.end → febrero completo.
        let currentInterval = DateInterval(start: date(2026, 3, 1), end: date(2026, 4, 1))
        let previousInterval = DateInterval(start: date(2026, 2, 1), end: date(2026, 3, 1))

        let result = DateAlignmentHelper.alignedPreviousInterval(
            currentInterval: currentInterval,
            previousInterval: previousInterval,
            asOf: date(2026, 3, 31),
            period: .thisMonth,
            comparisonMode: .month,
            calendar: cal
        )

        #expect(result == previousInterval)             // febrero completo, sin colapsar
    }

    @Test("thisMonth+month, último día del mes: previo completo (no trunca)")
    func alignedPreviousInterval_ultimoDiaDelMes_previoCompleto() {
        // Hoy 31 de julio; previo = junio (30 días). day=31 rueda a jul 1 = prev.end.
        let currentInterval = DateInterval(start: date(2026, 7, 1), end: date(2026, 8, 1))
        let previousInterval = DateInterval(start: date(2026, 6, 1), end: date(2026, 7, 1))

        let result = DateAlignmentHelper.alignedPreviousInterval(
            currentInterval: currentInterval,
            previousInterval: previousInterval,
            asOf: date(2026, 7, 31),
            period: .thisMonth,
            comparisonMode: .month,
            calendar: cal
        )

        #expect(result == previousInterval)             // junio completo
    }

    @Test("thisMonth+year mode: no-op (solo se alinea modo mes)")
    func alignedPreviousInterval_thisMonthYearMode_noOp() {
        let currentInterval = DateInterval(start: date(2026, 7, 1), end: date(2026, 7, 7))
        let previousInterval = DateInterval(start: date(2025, 7, 1), end: date(2025, 8, 1))

        let result = DateAlignmentHelper.alignedPreviousInterval(
            currentInterval: currentInterval,
            previousInterval: previousInterval,
            asOf: date(2026, 7, 6),
            period: .thisMonth,
            comparisonMode: .year,
            calendar: cal
        )

        #expect(result == previousInterval)             // modo año ya es simétrico
    }

    @Test("thisWeek+month: no-op (ventana trailing ya simétrica)")
    func alignedPreviousInterval_thisWeek_noOp() {
        let currentInterval = DateInterval(start: date(2026, 7, 6), end: date(2026, 7, 9))
        let previousInterval = DateInterval(start: date(2026, 7, 3), end: date(2026, 7, 6))

        let result = DateAlignmentHelper.alignedPreviousInterval(
            currentInterval: currentInterval,
            previousInterval: previousInterval,
            asOf: date(2026, 7, 8),
            period: .thisWeek,
            comparisonMode: .month,
            calendar: cal
        )

        #expect(result == previousInterval)
    }

    @Test("thisYear+year: no-op (previo ya YTD del año anterior)")
    func alignedPreviousInterval_thisYear_noOp() {
        let currentInterval = DateInterval(start: date(2026, 1, 1), end: date(2026, 7, 7))
        let previousInterval = DateInterval(start: date(2025, 1, 1), end: date(2025, 7, 7))

        let result = DateAlignmentHelper.alignedPreviousInterval(
            currentInterval: currentInterval,
            previousInterval: previousInterval,
            asOf: date(2026, 7, 6),
            period: .thisYear,
            comparisonMode: .year,
            calendar: cal
        )

        #expect(result == previousInterval)
    }

    @Test("lastMonth+month cerrado: no-op")
    func alignedPreviousInterval_lastMonthClosed_noOp() {
        let currentInterval = DateInterval(start: date(2026, 6, 1), end: date(2026, 7, 1))
        let previousInterval = DateInterval(start: date(2026, 5, 1), end: date(2026, 6, 1))

        let result = DateAlignmentHelper.alignedPreviousInterval(
            currentInterval: currentInterval,
            previousInterval: previousInterval,
            asOf: date(2026, 7, 6),
            period: .lastMonth,
            comparisonMode: .month,
            calendar: cal
        )

        #expect(result == previousInterval)
    }

    @Test("last7Days: no-op (ventana rodante completa)")
    func alignedPreviousInterval_last7Days_noOp() {
        let currentInterval = DateInterval(start: date(2026, 6, 30), end: date(2026, 7, 7))
        let previousInterval = DateInterval(start: date(2026, 6, 23), end: date(2026, 6, 30))

        let result = DateAlignmentHelper.alignedPreviousInterval(
            currentInterval: currentInterval,
            previousInterval: previousInterval,
            asOf: date(2026, 7, 6),
            period: .last7Days,
            comparisonMode: .month,
            calendar: cal
        )

        #expect(result == previousInterval)
    }

    @Test("allTime: no-op (preserva la variación 0)")
    func alignedPreviousInterval_allTime_noOp() {
        // Para allTime, PreviousPeriodHelper devuelve el MISMO intervalo actual.
        let currentInterval = DateInterval(start: date(2016, 7, 7), end: date(2026, 7, 7))
        let previousInterval = currentInterval

        let result = DateAlignmentHelper.alignedPreviousInterval(
            currentInterval: currentInterval,
            previousInterval: previousInterval,
            asOf: date(2026, 7, 6),
            period: .allTime,
            comparisonMode: .year,
            calendar: cal
        )

        #expect(result == previousInterval)
    }

    @Test("asOf con hora: el end se normaliza a medianoche del día equivalente")
    func alignedPreviousInterval_asOfConHora_endAMedianoche() {
        let currentInterval = DateInterval(start: date(2026, 7, 1), end: date(2026, 7, 7))
        let previousInterval = DateInterval(start: date(2026, 6, 1), end: date(2026, 7, 1))
        // 6 de julio a las 14:30 — no debe arrastrar la hora al end.
        let asOfConHora = date(2026, 7, 6).addingTimeInterval(14 * 3600 + 30 * 60)

        let result = DateAlignmentHelper.alignedPreviousInterval(
            currentInterval: currentInterval,
            previousInterval: previousInterval,
            asOf: asOfConHora,
            period: .thisMonth,
            comparisonMode: .month,
            calendar: cal
        )

        // FIN del día equivalente (jun 6 completo); la hora 14:30 del asOf NO se arrastra.
        #expect(result.end == date(2026, 6, 7))
    }

    @Test("thisMonth+month, día 1: previo de 1 día completo (no colapsa a ancho cero)")
    func alignedPreviousInterval_diaUno_noColapsa() {
        let currentInterval = DateInterval(start: date(2026, 7, 1), end: date(2026, 7, 2))
        let previousInterval = DateInterval(start: date(2026, 6, 1), end: date(2026, 7, 1))

        let result = DateAlignmentHelper.alignedPreviousInterval(
            currentInterval: currentInterval,
            previousInterval: previousInterval,
            asOf: date(2026, 7, 1),
            period: .thisMonth,
            comparisonMode: .month,
            calendar: cal
        )

        #expect(result.end == date(2026, 6, 2))          // jun 1 completo, no [jun1, jun1]
        #expect(result.duration > 0)
        #expect(result.contains(date(2026, 6, 1).addingTimeInterval(12 * 3600)))  // jun 1 tarde entra
    }

    @Test("thisMonth+month, mid-month exacto (may 15, sin rollover): trunca a [abr1, abr16)")
    func alignedPreviousInterval_midMonthExacto_sinRollover() {
        let currentInterval = DateInterval(start: date(2026, 5, 1), end: date(2026, 5, 16))
        let previousInterval = DateInterval(start: date(2026, 4, 1), end: date(2026, 5, 1))

        let result = DateAlignmentHelper.alignedPreviousInterval(
            currentInterval: currentInterval,
            previousInterval: previousInterval,
            asOf: date(2026, 5, 15),
            period: .thisMonth,
            comparisonMode: .month,
            calendar: cal
        )

        #expect(result.start == date(2026, 4, 1))
        #expect(result.end == date(2026, 4, 16))         // abr 15 completo
        #expect(result.contains(date(2026, 4, 15).addingTimeInterval(20 * 3600)))  // abr 15 noche entra
    }

    @Test("thisMonth+month, febrero bisiesto (mar 29 2024 → feb 29): previo = febrero completo")
    func alignedPreviousInterval_febBisiesto_dia29() {
        let currentInterval = DateInterval(start: date(2024, 3, 1), end: date(2024, 4, 1))
        let previousInterval = DateInterval(start: date(2024, 2, 1), end: date(2024, 3, 1))

        let result = DateAlignmentHelper.alignedPreviousInterval(
            currentInterval: currentInterval,
            previousInterval: previousInterval,
            asOf: date(2024, 3, 29),
            period: .thisMonth,
            comparisonMode: .month,
            calendar: cal
        )

        // mar 29 → feb 29 (existe en 2024) → +1 día = mar 1 = prev.end → febrero completo.
        #expect(result == previousInterval)
    }

    // MARK: - alignedPreviousItems / aggregatePreviousNeedsAlignment (sumas agregadas del Panel, p20-15 fase 2)

    @Test("aggregatePreviousNeedsAlignment: thisMonth, thisWeek (mes) y thisYear; cerrados no")
    func aggregatePreviousNeedsAlignment_parcialesEnCurso() {
        #expect(DateAlignmentHelper.aggregatePreviousNeedsAlignment(period: .thisMonth, comparisonMode: .month))
        #expect(DateAlignmentHelper.aggregatePreviousNeedsAlignment(period: .thisWeek, comparisonMode: .month))
        #expect(DateAlignmentHelper.aggregatePreviousNeedsAlignment(period: .thisYear, comparisonMode: .year))
        #expect(DateAlignmentHelper.aggregatePreviousNeedsAlignment(period: .thisYear, comparisonMode: .month))
        // thisMonth en modo año = A-1 (mismo mes año pasado, ya recortado por sameIntervalPreviousYear)
        #expect(!DateAlignmentHelper.aggregatePreviousNeedsAlignment(period: .thisMonth, comparisonMode: .year))
        #expect(!DateAlignmentHelper.aggregatePreviousNeedsAlignment(period: .thisWeek, comparisonMode: .year))
        for p: DetailPeriod in [.lastMonth, .lastYear, .last7Days, .last30Days, .allTime, .custom] {
            #expect(!DateAlignmentHelper.aggregatePreviousNeedsAlignment(period: p, comparisonMode: .month))
        }
    }

    @Test("alignedPreviousItems thisMonth: trunca el previo al día equivalente (corte por día, no timestamp)")
    func alignedPreviousItems_thisMonth_truncaAlDiaEquivalente() {
        let currentInterval = DateInterval(start: date(2026, 7, 1), end: date(2026, 8, 1))
        let previousInterval = DateInterval(start: date(2026, 6, 1), end: date(2026, 7, 1))
        // Actual con datos hasta el día 6 (mes en curso), a medianoche (corte más estricto).
        let currentDates = (1...6).map { date(2026, 7, $0) }
        // Previo: junio completo, con hora TARDÍA (23:00) — no debe sobre-truncar
        // (adjustDateToCurrent normaliza a medianoche → el corte es por día).
        let previous = (1...30).map { date(2026, 6, $0).addingTimeInterval(23 * 3600) }

        let result = DateAlignmentHelper.alignedPreviousItems(
            previous,
            currentDates: currentDates,
            currentInterval: currentInterval,
            previousInterval: previousInterval,
            period: .thisMonth,
            comparisonMode: .month,
            calendar: cal
        ) { $0 }

        // Conserva Jun 1..6 (día ≤ 6, incl. día 6 a las 23:00 = borde), descarta Jun 7..30.
        #expect(result.count == 6)
        #expect(result.allSatisfy { cal.component(.day, from: $0) <= 6 })
        #expect(result.contains { cal.component(.day, from: $0) == 6 })  // día borde INCLUIDO
        #expect(!result.contains { cal.component(.day, from: $0) == 7 })
    }

    @Test("alignedPreviousItems thisWeek: recorta la semana calendario anterior al mismo weekday")
    func alignedPreviousItems_thisWeek_truncaAlWeekdayEquivalente() {
        // Semana actual lun 6-jul → jue 9-jul (datos lun-mié).
        // Previo = semana calendario anterior lun 29-jun → lun 6-jul.
        let currentInterval = DateInterval(start: date(2026, 7, 6), end: date(2026, 7, 9))
        let previousInterval = DateInterval(start: date(2026, 6, 29), end: date(2026, 7, 6))
        let currentDates = [date(2026, 7, 6), date(2026, 7, 7), date(2026, 7, 8)]
        let previous = (0...6).map { cal.date(byAdding: .day, value: $0, to: date(2026, 6, 29))! }

        let result = DateAlignmentHelper.alignedPreviousItems(
            previous,
            currentDates: currentDates,
            currentInterval: currentInterval,
            previousInterval: previousInterval,
            period: .thisWeek,
            comparisonMode: .month,
            calendar: cal
        ) { $0 }

        // Conserva lun-mié de la semana anterior (29, 30 jun, 1 jul). Descarta jue-dom.
        #expect(result.count == 3)
        #expect(result.contains(date(2026, 6, 29)))
        #expect(result.contains(date(2026, 6, 30)))
        #expect(result.contains(date(2026, 7, 1)))
        #expect(!result.contains(date(2026, 7, 2)))
    }

    @Test("alignedPreviousItems: períodos cerrados/rodantes → previo intacto (no-op)")
    func alignedPreviousItems_periodosSimetricos_noOp() {
        let previous = (1...31).map { date(2026, 5, $0) }
        let currentDates = (1...30).map { date(2026, 6, $0) }
        let currentInterval = DateInterval(start: date(2026, 6, 1), end: date(2026, 7, 1))
        let previousInterval = DateInterval(start: date(2026, 5, 1), end: date(2026, 6, 1))

        // .lastMonth (cerrado) → intacto.
        let closedResult = DateAlignmentHelper.alignedPreviousItems(
            previous, currentDates: currentDates,
            currentInterval: currentInterval, previousInterval: previousInterval,
            period: .lastMonth, comparisonMode: .month, calendar: cal
        ) { $0 }
        #expect(closedResult.count == previous.count)

        // .last30Days (rodante, igual duración) → intacto.
        let rollingResult = DateAlignmentHelper.alignedPreviousItems(
            previous, currentDates: currentDates,
            currentInterval: currentInterval, previousInterval: previousInterval,
            period: .last30Days, comparisonMode: .month, calendar: cal
        ) { $0 }
        #expect(rollingResult.count == previous.count)
    }

    @Test("alignedPreviousItems: actual sin datos → previo intacto")
    func alignedPreviousItems_actualVacio_noOp() {
        let previous = (1...30).map { date(2026, 6, $0) }
        let result = DateAlignmentHelper.alignedPreviousItems(
            previous, currentDates: [],
            currentInterval: DateInterval(start: date(2026, 7, 1), end: date(2026, 8, 1)),
            previousInterval: DateInterval(start: date(2026, 6, 1), end: date(2026, 7, 1)),
            period: .thisMonth, comparisonMode: .month, calendar: cal
        ) { $0 }
        #expect(result.count == previous.count)
    }

    @Test("alignedPreviousItems thisMonth: previo más corto (feb) no se sobre-trunca")
    func alignedPreviousItems_thisMonth_previoMasCorto_conservaTodo() {
        // Actual marzo con datos hasta el día 30; previo febrero (28 días en 2026).
        let currentInterval = DateInterval(start: date(2026, 3, 1), end: date(2026, 4, 1))
        let previousInterval = DateInterval(start: date(2026, 2, 1), end: date(2026, 3, 1))
        let currentDates = (1...30).map { date(2026, 3, $0) }
        let previous = (1...28).map { date(2026, 2, $0) }
        let result = DateAlignmentHelper.alignedPreviousItems(
            previous, currentDates: currentDates,
            currentInterval: currentInterval, previousInterval: previousInterval,
            period: .thisMonth, comparisonMode: .month, calendar: cal
        ) { $0 }
        // Todos los días de febrero (≤ 28 < 30) se conservan (sin over-trunca por rollover).
        #expect(result.count == 28)
    }

    @Test("cash flow thisMonth: 14 días vs 31 se recorta a 14 (clase del bug de Tendencias)")
    func alignedPreviousItems_cashFlowThisMonth_14vs31() {
        let currentInterval = DateInterval(start: date(2026, 8, 1), end: date(2026, 8, 15))
        let previousInterval = DateInterval(start: date(2026, 7, 1), end: date(2026, 8, 1))
        let currentDates = (1...14).map { date(2026, 8, $0) }
        // Julio completo: 1..31. Sin recorte el «vs» usa 31 días.
        let previous = (1...31).map { date(2026, 7, $0) }

        let aligned = DateAlignmentHelper.alignedPreviousItems(
            previous, currentDates: currentDates,
            currentInterval: currentInterval, previousInterval: previousInterval,
            period: .thisMonth, comparisonMode: .month, calendar: cal
        ) { $0 }
        #expect(aligned.count == 14)
        #expect(aligned.allSatisfy { cal.component(.month, from: $0) == 7 && cal.component(.day, from: $0) <= 14 })

        // Mutación: si el gate no aplica (lastMonth), se quedan los 31.
        let unaligned = DateAlignmentHelper.alignedPreviousItems(
            previous, currentDates: currentDates,
            currentInterval: currentInterval, previousInterval: previousInterval,
            period: .lastMonth, comparisonMode: .month, calendar: cal
        ) { $0 }
        #expect(unaligned.count == 31)
    }

    @Test("alignedPreviousItems thisYear: recorta YTD del año pasado al último día con datos")
    func alignedPreviousItems_thisYear_truncaAlDiaEquivalente() {
        let currentInterval = DateInterval(start: date(2026, 1, 1), end: date(2026, 8, 15))
        let previousInterval = DateInterval(start: date(2025, 1, 1), end: date(2025, 8, 15))
        let currentDates = [date(2026, 8, 14)]
        let previous = [date(2025, 8, 10), date(2025, 8, 14), date(2025, 8, 20)]

        let result = DateAlignmentHelper.alignedPreviousItems(
            previous, currentDates: currentDates,
            currentInterval: currentInterval, previousInterval: previousInterval,
            period: .thisYear, comparisonMode: .year, calendar: cal
        ) { $0 }
        #expect(result.contains(date(2025, 8, 10)))
        #expect(result.contains(date(2025, 8, 14)))
        #expect(!result.contains(date(2025, 8, 20)))
    }

}
