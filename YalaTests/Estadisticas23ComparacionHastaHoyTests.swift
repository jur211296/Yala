//
//  Estadisticas23ComparacionHastaHoyTests.swift
//  YalaTests
//
//  Decisión 29 de la revisión 2.3 (A, 9-nov): todas las pestañas de Estadísticas comparan con el período anterior
//  HASTA HOY, como Resumen. Hasta ese día Resumen cortaba el anterior en el día equivalente a hoy, y Distribución y
//  Tendencias en el día equivalente al ÚLTIMO DÍA CON MOVIMIENTOS: con el último gasto del mes el día 5 y hoy 12,
//  Distribución comparaba contra el 1–5 de octubre y Resumen contra el 1–12. Y Tendencias no decía contra qué comparaba.
//
//  La regla de «hasta hoy» es la de Resumen (`DateAlignmentHelper.alignedPreviousInterval(asOf:)`); el Panel sigue con
//  la suya (cortar en el último día con datos), y por eso el corte por hoy es un parámetro aparte.
//

import Foundation
import Testing
@testable import Yala

@Suite("Decisión 29 de 2.3 · Estadísticas compara hasta hoy en todas las pestañas")
struct Estadisticas23ComparacionHastaHoyTests {

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Lima") ?? .gmt
        calendar.firstWeekday = 2
        return calendar
    }()

    private static func day(_ month: Int, _ day: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour)) ?? .distantPast
    }

    /// Hoy, 12 de noviembre a las 15:00. «Este mes» va del 1 al 12 (cerrado a las 23:59:59) y el anterior es octubre.
    private static let now = Self.day(11, 12, hour: 15)
    private static let thisMonth = DateInterval(start: Self.day(11, 1), end: Self.day(11, 12, hour: 23).addingTimeInterval(59 * 60 + 59))
    private static let october = DateInterval(start: Self.day(10, 1), end: Self.day(11, 1).addingTimeInterval(-1))

    // MARK: - Movimientos (Distribución y el «Entradas y salidas» de Tendencias)

    @Test func lasSumasDelAnterior_llegan_hastaElDiaEquivalenteAHoy_noAlUltimoMovimiento() {
        let previous = [Self.day(10, 3, hour: 9), Self.day(10, 8, hour: 12), Self.day(10, 12, hour: 20), Self.day(10, 13), Self.day(10, 20)]
        let cut = DateAlignmentHelper.previousItemsUntilToday(
            previous, currentInterval: Self.thisMonth, previousInterval: Self.october,
            period: .thisMonth, comparisonMode: .month, asOf: Self.now, calendar: Self.calendar
        ) { $0 }
        #expect(cut == [Self.day(10, 3, hour: 9), Self.day(10, 8, hour: 12), Self.day(10, 12, hour: 20)],
                "El anterior tiene que llegar al 12 de octubre entero y no pasar al 13.")

        // Control: la regla de antes cortaba en el último movimiento del mes (el día 5) y dejaba fuera el 8 y el 12.
        let old = DateAlignmentHelper.alignedPreviousItems(
            previous, currentDates: [Self.day(11, 5, hour: 10)], currentInterval: Self.thisMonth,
            previousInterval: Self.october, period: .thisMonth, comparisonMode: .month, calendar: Self.calendar
        ) { $0 }
        #expect(old == [Self.day(10, 3, hour: 9)])
    }

    @Test func lasSumasDelAnterior_cortanIgualQueResumen() {
        let previous = (1...31).map { Self.day(10, $0, hour: 13) }
        let cut = DateAlignmentHelper.previousItemsUntilToday(
            previous, currentInterval: Self.thisMonth, previousInterval: Self.october,
            period: .thisMonth, comparisonMode: .month, asOf: Self.now, calendar: Self.calendar
        ) { $0 }
        let resumen = DateAlignmentHelper.alignedPreviousInterval(
            currentInterval: Self.thisMonth, previousInterval: Self.october, asOf: Self.now,
            period: .thisMonth, comparisonMode: .month, calendar: Self.calendar
        )
        #expect(cut == previous.filter { resumen.contains($0) })
        #expect(cut.count == 12)
    }

    @Test func sinMovimientosEsteMes_tambienCortaEnHoy() {
        // Con la regla de antes, sin movimientos no había referencia y se comparaba con octubre ENTERO.
        let previous = [Self.day(10, 2), Self.day(10, 25)]
        let cut = DateAlignmentHelper.previousItemsUntilToday(
            previous, currentInterval: Self.thisMonth, previousInterval: Self.october,
            period: .thisMonth, comparisonMode: .month, asOf: Self.now, calendar: Self.calendar
        ) { $0 }
        #expect(cut == [Self.day(10, 2)])
    }

    @Test func unPeriodoCerrado_comparaEntero() {
        // «Mes pasado» (octubre) contra septiembre: los dos completos, aunque el último gasto de octubre fuera el día 20.
        let septiembre = DateInterval(start: Self.day(9, 1), end: Self.day(10, 1).addingTimeInterval(-1))
        let previous = [Self.day(9, 3), Self.day(9, 29, hour: 18)]
        let cut = DateAlignmentHelper.previousItemsUntilToday(
            previous, currentInterval: Self.october, previousInterval: septiembre,
            period: .lastMonth, comparisonMode: .month, asOf: Self.now, calendar: Self.calendar
        ) { $0 }
        #expect(cut == previous)
    }

    // MARK: - Curva acumulada (la cifra y la comparación de la tarjeta de Tendencias)

    private static func cumulative(_ month: Int, days: ClosedRange<Int>) -> [BarPoint] {
        days.map { BarPoint(date: Self.day(month, $0), value: Double($0) * 10) }
    }

    @Test func laCifraDelAnterior_esLaDelDiaEquivalenteAHoy() {
        let previous = Self.cumulative(10, days: 1...31)
        let current = Self.cumulative(11, days: 1...5)
        let total = DateAlignmentHelper.alignedPreviousTotal(
            previousPoints: previous, currentPoints: current, currentInterval: Self.thisMonth,
            previousInterval: Self.october, period: .thisMonth, comparisonMode: .month,
            untilToday: Self.now, calendar: Self.calendar
        )
        #expect(total == 120, "La cifra del anterior tiene que ser la del 12 de octubre.")

        // Control: sin el corte por hoy, el último dato del mes (día 5) más un día de margen: el 6 de octubre.
        let old = DateAlignmentHelper.alignedPreviousTotal(
            previousPoints: previous, currentPoints: current, currentInterval: Self.thisMonth,
            previousInterval: Self.october, period: .thisMonth, comparisonMode: .month, calendar: Self.calendar
        )
        #expect(old == 60)
    }

    @Test func laCurvaDelAnterior_cabeEnElEjeHastaHoy() {
        let previous = Self.cumulative(10, days: 1...31)
        let current = Self.cumulative(11, days: 3...5)
        let domain = DateAlignmentHelper.currentDataDomain(
            currentPoints: current, currentInterval: Self.thisMonth, untilToday: Self.now, calendar: Self.calendar
        )
        let clipped = DateAlignmentHelper.clippedPreviousPoints(
            previousPoints: previous, currentPoints: current, currentInterval: Self.thisMonth,
            previousInterval: Self.october, period: .thisMonth, comparisonMode: .month,
            untilToday: Self.now, calendar: Self.calendar
        )
        #expect(clipped.count == 12)
        #expect(clipped.allSatisfy { domain.contains($0.date) }, "Un punto del anterior quedaría fuera del eje.")
    }

    @Test func elPanel_siguePorElUltimoDiaConDatos() {
        // Sin `untilToday` nada cambia: el chip «vs 20 oct» de la gráfica de saldo del Panel lee esta rama.
        let previous = Self.cumulative(10, days: 1...31)
        let current = Self.cumulative(11, days: 1...5)
        let reference = DateAlignmentHelper.alignedPreviousReference(
            previousPoints: previous, currentPoints: current, currentInterval: Self.thisMonth,
            previousInterval: Self.october, period: .thisMonth, comparisonMode: .month, calendar: Self.calendar
        )
        #expect(reference?.date == Self.day(10, 6))
    }

    // MARK: - Cableado (source-scan)

    private static func code(_ relativePath: String, file: StaticString = #filePath) throws -> String {
        let root = URL(fileURLWithPath: "\(file)").deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appending(path: relativePath), encoding: .utf8)
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.hasPrefix("//") }
            .joined(separator: "\n")
    }

    @Test func tendencias_llevaElSelector_yCortaHastaHoy() throws {
        let trends = try Self.code("Yala/App/Views/Statistics/TrendsTabView.swift")
        #expect(trends.contains("ComparisonModeSelector("), "Tendencias tiene que decir contra qué compara.")
        #expect(trends.contains("DateAlignmentHelper.previousItemsUntilToday("))
        #expect(!trends.contains("DateAlignmentHelper.alignedPreviousItems("))
        #expect(trends.contains("untilToday: .now"))
        let chart = try Self.code("Yala/App/Views/Statistics/PeriodComparisonChartView.swift")
        #expect(chart.contains("untilToday: untilToday"), "La curva tiene que cortar donde corta la cifra.")
    }

    @Test func distribucion_cortaHastaHoy_yLaFraseLoDice() throws {
        let distribution = try Self.code("Yala/App/Views/Statistics/CategoriesTabView.swift")
        #expect(distribution.contains("DateAlignmentHelper.previousItemsUntilToday("))
        #expect(!distribution.contains("DistributionPreviousPeriodCalculator.alignedPrevious("))
        #expect(!distribution.contains("dataEnd:"), "La frase tiene que decir «hasta hoy», como Resumen.")
    }
}
