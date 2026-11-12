//
//  Estadisticas23GraficasVoiceOverTests.swift
//  YalaTests
//
//  Decisión 26 de la revisión 2.3 (V1 + V2, 9-nov): VoiceOver lee cada gráfica con su conclusión y sus cifras, no con un
//  recuento, y cada tipo publica la descripción de gráficas de iOS (rotor «Describir gráfica» y el sonido). Antes: la
//  línea decía «7 puntos», la comparación «Periodo actual vs anterior, 7 puntos», la tarta «7 categorías», las barras de
//  la semana «Ju, 2,314» y las necesidades «7 periodos»; solo la mini gráfica del flujo de caja tenía descripción.
//  Se valida aquí y en el árbol de accesibilidad (`Estadisticas23ComparacionVoiceOverUITests`), no a mano.
//

import Accessibility
import SwiftUI
import Foundation
import Testing
@testable import Yala

@Suite("Decisión 26 de 2.3 · VoiceOver lee las gráficas con conclusión y cifras")
struct Estadisticas23GraficasVoiceOverTests {

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Lima") ?? .gmt
        return calendar
    }()
    private static let spanish = Locale(identifier: "es_PE")
    private static let soles = ChartAmountFormat(decimals: 0, identifier: "S/", hidden: false)

    private static func day(_ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day)) ?? .distantPast
    }

    // MARK: - V1 · la frase

    @Test func laLinea_diceDeDondeADonde_yElPuntoMasBajo() {
        let values: [Double] = [76_100, 75_900, 75_800, 75_700, 73_500, 73_400, 73_357]
        let points = values.enumerated().map { (date: Self.day(11, $0.offset + 1), value: $0.element) }
        let spoken = ChartSpokenSummary.trend(
            points: points, grouping: .day, format: Self.soles, locale: Self.spanish, calendar: Self.calendar
        )
        #expect(spoken.contains("S/ 76,100"), "\(spoken)")
        #expect(spoken.contains("S/ 73,357"), "\(spoken)")
        #expect(spoken == L10n.Accessibility.Chart.trendFell(
            ChartSpokenSummary.rangeText(from: Self.day(11, 1), to: Self.day(11, 7), grouping: .day,
                                         locale: Self.spanish, calendar: Self.calendar),
            "S/ 76,100", "S/ 73,357"
        ) + " " + L10n.Accessibility.Chart.lowest(
            "S/ 73,357",
            ChartSpokenSummary.dateText(Self.day(11, 7), grouping: .day, locale: Self.spanish, calendar: Self.calendar)
        ))
        #expect(!spoken.contains(L10n.Accessibility.dataPoints(7)), "Sigue siendo un recuento: \(spoken)")
    }

    @Test func laLinea_queSube_diceElPuntoMasAlto() {
        let points = [(date: Self.day(11, 1), value: 100.0), (date: Self.day(11, 2), value: 900), (date: Self.day(11, 3), value: 500)]
        let spoken = ChartSpokenSummary.trend(
            points: points, grouping: .day, format: Self.soles, locale: Self.spanish, calendar: Self.calendar
        )
        #expect(spoken.hasSuffix(L10n.Accessibility.Chart.highest(
            "S/ 900", ChartSpokenSummary.dateText(Self.day(11, 2), grouping: .day, locale: Self.spanish, calendar: Self.calendar)
        )), "\(spoken)")
    }

    @Test func laLinea_conUnPunto_oSinDatos() {
        let one = ChartSpokenSummary.trend(
            points: [(date: Self.day(11, 4), value: 250)], grouping: .day, format: Self.soles,
            locale: Self.spanish, calendar: Self.calendar
        )
        #expect(one.contains("S/ 250"))
        #expect(ChartSpokenSummary.trend(points: [], grouping: .day, format: Self.soles) == L10n.Accessibility.noData)
    }

    @Test func laLinea_quedaIgual_cuandoLoQueSeVeEsIgual() {
        let points = [(date: Self.day(11, 1), value: 100.2), (date: Self.day(11, 2), value: 300), (date: Self.day(11, 3), value: 99.9)]
        let spoken = ChartSpokenSummary.trend(
            points: points, grouping: .day, format: Self.soles, locale: Self.spanish, calendar: Self.calendar
        )
        #expect(spoken == L10n.Accessibility.Chart.trendFlat(
            ChartSpokenSummary.rangeText(from: Self.day(11, 1), to: Self.day(11, 3), grouping: .day,
                                         locale: Self.spanish, calendar: Self.calendar),
            "S/ 100"
        ))
    }

    @Test func laComparacion_diceCuantoMasOMenos() {
        #expect(ChartSpokenSummary.comparison(current: 1_200, previous: 900, format: Self.soles)
                == L10n.Accessibility.Chart.comparisonMore("S/ 1,200", "S/ 300", "S/ 900"))
        #expect(ChartSpokenSummary.comparison(current: 600, previous: 900, format: Self.soles)
                == L10n.Accessibility.Chart.comparisonLess("S/ 600", "S/ 300", "S/ 900"))
        #expect(ChartSpokenSummary.comparison(current: 900, previous: 900.3, format: Self.soles)
                == L10n.Accessibility.Chart.comparisonSame("S/ 900"))
        #expect(ChartSpokenSummary.comparison(current: 900, previous: nil, format: Self.soles)
                == L10n.Accessibility.Chart.comparisonNoPrevious("S/ 900"))
    }

    @Test func laTarta_diceLasPartes_noElRecuento() {
        let items: [(name: String, amount: Double)] = [
            ("Hogar", 2_210), ("Alimentación", 526), ("Entretenimiento", 245),
            ("Salud", 200), ("Transporte", 180), ("Ropa", 100), ("Otros", 46),
        ]
        let spoken = ChartSpokenSummary.parts(items, format: Self.soles, locale: Self.spanish)
        #expect(spoken.hasPrefix(L10n.Accessibility.Chart.parts("S/ 3,507", "").dropLast(1)), "\(spoken)")
        #expect(spoken.contains("Hogar 63"), "\(spoken)")
        #expect(spoken.contains("Alimentación 15"), "\(spoken)")
        #expect(spoken.contains("Entretenimiento 7"), "\(spoken)")
        #expect(!spoken.contains("Salud"), "Solo las tres mayores tienen nombre: \(spoken)")
        #expect(spoken.contains(L10n.Accessibility.Chart.rest("").trimmingCharacters(in: .whitespaces)), "\(spoken)")
    }

    @Test func entradasYSalidas_diceLoQueQueda_enSuTiempo() {
        let now = ChartSpokenSummary.cashFlow(income: "S/ 5,000", expense: "S/ 3,500", net: 1_500, isClosed: false,
                                              format: Self.soles)
        #expect(now.contains(L10n.Panel.Hero.leftNow) && now.contains("S/ 1,500"), "\(now)")
        let past = ChartSpokenSummary.cashFlow(income: "S/ 5,000", expense: "S/ 3,500", net: 1_500, isClosed: true,
                                               format: Self.soles)
        #expect(past.contains(L10n.Panel.Hero.leftPast), "\(past)")
        let onlyExpenses = ChartSpokenSummary.cashFlow(income: "S/ 0", expense: "S/ 3,500", net: nil, isClosed: false,
                                                       format: Self.soles)
        #expect(onlyExpenses == L10n.Accessibility.cashFlowSummary(income: "S/ 0", expense: "S/ 3,500"))
    }

    @Test func elDiaDeLaSemana_diceElMasCaro_yElMasBarato() {
        let spoken = ChartSpokenSummary.weekday(
            [("lunes", 144), ("martes", 495), ("miércoles", 18), ("jueves", 2_314), ("viernes", 0)], format: Self.soles
        )
        #expect(spoken == L10n.Accessibility.Chart.weekdayTop("jueves", "S/ 2,314") + " "
                + L10n.Accessibility.Chart.weekdayLow("miércoles", "S/ 18"))
        #expect(ChartSpokenSummary.weekday([("lunes", 0)], format: Self.soles) == L10n.Accessibility.noData)
    }

    @Test func conMontosOcultos_noSeDiceNingunaCifra() {
        let hidden = ChartAmountFormat(decimals: 0, identifier: "S/", hidden: true)
        let spoken = ChartSpokenSummary.comparison(current: 1_200, previous: 900, format: hidden)
        #expect(!spoken.contains("1,200") && !spoken.contains("900") && !spoken.contains("300"), "\(spoken)")
        #expect(spoken.contains(L10n.Panel.amountHidden))
    }

    // MARK: - V2 · la descripción de gráficas de iOS

    @Test func laLinea_publicaEjesYPuntos() {
        let descriptor = ChartAccessibilityDescriptor(
            title: "Saldo", summary: "resumen",
            xTitle: L10n.Accessibility.Chart.axisDate, xAxis: .dates(grouping: .day),
            yTitle: L10n.Accessibility.Chart.axisAmount,
            series: [.init(name: "Saldo", isContinuous: true,
                           points: [.at(Self.day(11, 1), 76_100), .at(Self.day(11, 7), 73_357)])],
            format: Self.soles, locale: Self.spanish, calendar: Self.calendar
        ).makeChartDescriptor()
        #expect(descriptor.title == "Saldo")
        #expect(descriptor.summary == "resumen")
        #expect(descriptor.series.count == 1)
        #expect(descriptor.series.first?.dataPoints.count == 2)
        #expect(descriptor.series.first?.isContinuous == true)
        let yAxis = descriptor.yAxis
        #expect((yAxis?.range.upperBound ?? 0) >= 76_100)
        #expect(yAxis?.valueDescriptionProvider(73_357) == "S/ 73,357")
        let xAxis = descriptor.xAxis as? AXNumericDataAxisDescriptor
        #expect(xAxis != nil)
        #expect(xAxis?.valueDescriptionProvider(Self.day(11, 7).timeIntervalSinceReferenceDate)
                == ChartSpokenSummary.dateText(Self.day(11, 7), grouping: .day, locale: Self.spanish, calendar: Self.calendar))
    }

    @Test func laTarta_publicaSusCategorias() {
        let descriptor = ChartAccessibilityDescriptor(
            title: "Gastos", summary: "resumen",
            xTitle: L10n.Accessibility.Chart.axisCategory, xAxis: .categories(["Hogar", "Salud"]),
            yTitle: L10n.Accessibility.Chart.axisAmount,
            series: [.init(name: "Gastos", isContinuous: false, points: [.named("Hogar", 2_210), .named("Salud", 200)])],
            format: Self.soles
        ).makeChartDescriptor()
        let categories = descriptor.xAxis as? AXCategoricalDataAxisDescriptor
        #expect(categories?.categoryOrder == ["Hogar", "Salud"])
        #expect(descriptor.series.first?.dataPoints.count == 2)
        #expect(descriptor.series.first?.isContinuous == false)
    }

    // MARK: - Cableado (source-scan): las ocho gráficas dicen su frase y publican su descripción

    private static func code(_ relativePath: String, file: StaticString = #filePath) throws -> String {
        let root = URL(fileURLWithPath: "\(file)").deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appending(path: relativePath), encoding: .utf8)
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.hasPrefix("//") }
            .joined(separator: "\n")
    }

    static let charts: [(path: String, summary: String)] = [
        ("Yala/App/Views/Panel/TrendChartView.swift", "ChartSpokenSummary.trend("),
        ("Yala/App/Views/Statistics/PeriodComparisonChartView.swift", "ChartSpokenSummary.comparison("),
        ("Yala/App/Views/Panel/CategoriesPieWidget.swift", "ChartSpokenSummary.parts("),
        ("Yala/App/Views/Panel/SubcategoriesPieWidget.swift", "ChartSpokenSummary.parts("),
        ("Yala/App/Views/Panel/TagsPieWidget.swift", "ChartSpokenSummary.parts("),
        ("Yala/App/Views/Panel/CashFlowWidget.swift", "ChartSpokenSummary.cashFlow("),
        ("Yala/App/Views/Statistics/Components/WeekdayBarChart.swift", "ChartSpokenSummary.weekday("),
        ("Yala/App/Views/Panel/NeedTrendWidget.swift", "ChartSpokenSummary.parts("),
    ]

    @Test(arguments: charts.map(\.path))
    func cadaGrafica_diceSuFrase_yPublicaSuDescripcion(path: String) throws {
        let code = try Self.code(path)
        let summary = try #require(Self.charts.first { $0.path == path }?.summary)
        #expect(code.contains(summary), "\(path) no dice la conclusión con cifras.")
        #expect(code.contains(".accessibilityChartDescriptor("),
                "\(path) no publica la descripción de gráficas de iOS.")
        #expect(!code.contains("L10n.Accessibility.dataPoints(")
                && !code.contains("L10n.Accessibility.periodComparisonValue(")
                && !code.contains("L10n.Accessibility.periodsCount(")
                && !code.contains("L10n.Accessibility.categoriesCount(")
                && !code.contains("L10n.Accessibility.subcategoriesCount(")
                && !code.contains("L10n.Accessibility.tagsCount("),
                "\(path) sigue leyendo un recuento.")
    }
}
