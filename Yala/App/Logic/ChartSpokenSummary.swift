//
//  ChartSpokenSummary.swift
//  Yala
//
//  Lo que VoiceOver dice de cada gráfica (decisión 26 de la revisión 2.3, V1, 9-nov): la conclusión con sus cifras, no un
//  recuento. Hasta ese día la línea de saldo decía «7 puntos», la comparación «Periodo actual vs anterior, 7 puntos», la
//  tarta «7 categorías» y las barras de la semana «Ju, 2,314». La frase sale de los mismos datos que pinta la gráfica.
//  La descripción de gráficas de iOS (V2, rotor «Describir gráfica» y el sonido) está en `ChartAccessibilityDescriptor`.
//

import Foundation

/// Cómo se dice un monto en una gráfica: con la moneda y los decimales de la persona, o «Monto oculto» con «Ocultar
/// montos» puesto (`AmountPrivacy`). Es un valor y no una función para que el descriptor de iOS pueda guardarlo.
struct ChartAmountFormat: Equatable {
    let decimals: Int
    let identifier: String
    let hidden: Bool

    func spoken(_ value: Double) -> String {
        AmountPrivacy.spoken(
            CurrencyFormattingHelper.currency(
                value, decimals: decimals, identifier: identifier, forceSign: false, isEstimate: false
            ),
            hidden: hidden
        )
    }
}

extension AppPreferences {
    /// Leído desde el `body`, registra la dependencia con los decimales y el formato de moneda, como `currency(_:)`.
    func chartAmountFormat(currencyCode: String, hidden: Bool) -> ChartAmountFormat {
        ChartAmountFormat(decimals: decimalPlaces, identifier: currencyIdentifier(for: currencyCode), hidden: hidden)
    }
}

enum ChartSpokenSummary {

    // MARK: - Fechas

    /// Una fecha de la gráfica, dicha según cómo agrupa: «7 de noviembre», «noviembre de 2025», «2025».
    static func dateText(
        _ date: Date, grouping: TrendGrouping, locale: Locale = AppLocale.current, calendar: Calendar = .current
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate(template(for: grouping, spansYears: false))
        return formatter.string(from: date)
    }

    /// El tramo de la gráfica: «1–7 de noviembre», «nov. de 2025 – oct. de 2026».
    static func rangeText(
        from start: Date, to end: Date, grouping: TrendGrouping,
        locale: Locale = AppLocale.current, calendar: Calendar = .current
    ) -> String {
        let formatter = DateIntervalFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        let spansYears = calendar.component(.year, from: start) != calendar.component(.year, from: end)
        formatter.dateTemplate = template(for: grouping, spansYears: spansYears)
        return formatter.string(from: start, to: end)
    }

    private static func template(for grouping: TrendGrouping, spansYears: Bool) -> String {
        switch grouping {
        case .day, .week: return spansYears ? "dMMMMy" : "dMMMM"
        case .month: return "MMMMy"
        case .year: return "y"
        }
    }

    // MARK: - Línea (tendencia)

    /// «1–7 de noviembre: bajó de S/ 76,100 a S/ 73,357. El punto más bajo: S/ 73,357, 7 de noviembre.»
    /// Sube → dice el punto más alto; baja → el más bajo; igual → ninguno.
    static func trend(
        points: [(date: Date, value: Double)], grouping: TrendGrouping, format: ChartAmountFormat,
        locale: Locale = AppLocale.current, calendar: Calendar = .current
    ) -> String {
        let sorted = points.sorted { $0.date < $1.date }
        guard let first = sorted.first, let last = sorted.last else { return L10n.Accessibility.noData }
        let lastDate = dateText(last.date, grouping: grouping, locale: locale, calendar: calendar)
        guard sorted.count > 1 else {
            return L10n.Accessibility.Chart.single(lastDate, format.spoken(last.value))
        }
        let range = rangeText(from: first.date, to: last.date, grouping: grouping, locale: locale, calendar: calendar)
        let from = format.spoken(first.value)
        let to = format.spoken(last.value)
        // Lo que se pinta igual se dice igual: la dirección sale de los montos ya redondeados a lo que se ve.
        let shownFirst = rounded(first.value, decimals: format.decimals)
        let shownLast = rounded(last.value, decimals: format.decimals)
        if shownFirst == shownLast {
            return L10n.Accessibility.Chart.trendFlat(range, to)
        }
        let rose = shownLast > shownFirst
        let movement = rose
            ? L10n.Accessibility.Chart.trendRose(range, from, to)
            : L10n.Accessibility.Chart.trendFell(range, from, to)
        let extreme = rose
            ? sorted.max { $0.value < $1.value }
            : sorted.min { $0.value < $1.value }
        guard let extreme else { return movement }
        let when = dateText(extreme.date, grouping: grouping, locale: locale, calendar: calendar)
        let amount = format.spoken(extreme.value)
        let extremeSentence = rose
            ? L10n.Accessibility.Chart.highest(amount, when)
            : L10n.Accessibility.Chart.lowest(amount, when)
        return "\(movement) \(extremeSentence)"
    }

    // MARK: - Comparación con el período anterior

    /// «Ahora S/ 1,200: S/ 300 más que el periodo anterior en el mismo punto, S/ 900.»
    static func comparison(current: Double?, previous: Double?, format: ChartAmountFormat) -> String {
        guard let current else { return L10n.Accessibility.noData }
        let now = format.spoken(current)
        guard let previous else { return L10n.Accessibility.Chart.comparisonNoPrevious(now) }
        let difference = rounded(current, decimals: format.decimals) - rounded(previous, decimals: format.decimals)
        if difference == 0 { return L10n.Accessibility.Chart.comparisonSame(now) }
        let gap = format.spoken(abs(difference))
        let before = format.spoken(previous)
        return difference > 0
            ? L10n.Accessibility.Chart.comparisonMore(now, gap, before)
            : L10n.Accessibility.Chart.comparisonLess(now, gap, before)
    }

    // MARK: - Partes de un total (tarta, necesidades)

    /// «Total S/ 3,507: Hogar 63 %, Alimentación 15 %, Entretenimiento 7 % y el resto 15 %.» Las tres mayores y, si hay
    /// más, lo que queda junto: con veinte categorías la frase no se haría eterna.
    static func parts(
        _ items: [(name: String, amount: Double)], format: ChartAmountFormat, shown: Int = 3,
        locale: Locale = AppLocale.current
    ) -> String {
        let positive = items.filter { $0.amount > 0 }.sorted { $0.amount > $1.amount }
        let total = positive.reduce(0) { $0 + $1.amount }
        guard total > 0 else { return L10n.Accessibility.noData }
        let percent = percentFormatter(locale: locale)
        func share(_ amount: Double) -> String {
            percent.string(from: NSNumber(value: amount / total)) ?? ""
        }
        var phrases = positive.prefix(shown).map { "\($0.name) \(share($0.amount))" }
        let rest = positive.dropFirst(shown).reduce(0) { $0 + $1.amount }
        if rest > 0 { phrases.append(L10n.Accessibility.Chart.rest(share(rest))) }
        let joiner = ListFormatter()
        joiner.locale = locale
        let list = joiner.string(from: phrases) ?? phrases.joined(separator: ", ")
        return L10n.Accessibility.Chart.parts(format.spoken(total), list)
    }

    // MARK: - Entradas y salidas

    /// «Ingresos S/ 5,000, Gastos S/ 3,500. Te queda S/ 1,500.» Con solo uno de los dos lados a la vista no se resta.
    static func cashFlow(
        income: String, expense: String, net: Double?, isClosed: Bool, format: ChartAmountFormat
    ) -> String {
        let totals = L10n.Accessibility.cashFlowSummary(income: income, expense: expense)
        guard let net else { return totals }
        let label = isClosed ? L10n.Panel.Hero.leftPast : L10n.Panel.Hero.leftNow
        return L10n.Accessibility.Chart.cashFlowNet(totals, label, format.spoken(net))
    }

    // MARK: - Día de la semana

    /// «Día de más gasto: jueves, S/ 2,314 de media. Día de menos gasto: miércoles, S/ 18.»
    static func weekday(
        _ items: [(name: String, average: Double)], format: ChartAmountFormat
    ) -> String {
        let spending = items.filter { $0.average > 0 }
        guard let top = spending.max(by: { $0.average < $1.average }) else { return L10n.Accessibility.noData }
        let topSentence = L10n.Accessibility.Chart.weekdayTop(top.name, format.spoken(top.average))
        guard spending.count > 1, let low = spending.min(by: { $0.average < $1.average }) else { return topSentence }
        return "\(topSentence) \(L10n.Accessibility.Chart.weekdayLow(low.name, format.spoken(low.average)))"
    }

    // MARK: - Ayudas

    private static func rounded(_ value: Double, decimals: Int) -> Double {
        let factor = pow(10, Double(max(0, decimals)))
        return (value * factor).rounded() / factor
    }

    private static func percentFormatter(locale: Locale) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.locale = locale
        formatter.maximumFractionDigits = 0
        return formatter
    }
}
