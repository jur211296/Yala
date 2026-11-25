//
//  PanelHeroFigureLogic.swift
//  Yala
//
//  Qué cifras enseña el hero del Panel y cómo se llaman.
//
//  Desde el 2026-11-16 (encargo «el saldo en grande, tu dinero en chico») el hero tiene dos cifras, las dos de HOY y sin
//  seguir al período:
//  - La GRANDE es «Tu saldo hoy»: todas las cuentas que suman en un saldo, tarjetas incluidas, con su signo. Si las
//    tarjetas pesan más que el resto sale con menos delante: nunca «Debes hoy» (BRAND-VOICE §8).
//  - La CHICA, debajo, es «Tu dinero hoy»: lo mismo sin las cuentas que no cuentan como dinero para usar (por defecto, las
//    tarjetas de crédito). La calcula `PanelMoneyScopeLogic`, y solo se enseña si alguna cuenta queda fuera.
//  La línea del mes («Te queda» y las flechas de ingresos y gastos) salió del hero: lo cuenta Flujo de caja.
//  En «Solo gastos» el hero no cambia de forma: la cifra grande es el gasto del período («Gastos de noviembre»).
//

import Foundation

/// Qué cuenta la cifra grande en «Solo gastos» (el gasto del período) y de qué lado habla un rótulo.
enum PanelHeroFigure: Equatable {
    case balance
    case expense
    case income
}

enum PanelHeroFigureLogic {

    /// Si el hero del Panel ya puede salir. Fuera de «Solo gastos» la cifra grande es el saldo de hoy, que no sale del pase
    /// por tramos del hero: basta con que el saldo se haya calculado. Antes esperaba a ese pase, y con guardados seguidos (una
    /// semilla, un import grande) cada guardado lo cortaba y volvía a empezar: el Panel enseñaba todo menos el saldo hasta
    /// 46 s después de parar (barrido de la build 8, iPhone 14). En «Solo gastos» la cifra es el gasto del período, que sí
    /// sale de ese pase, y sigue esperándolo.
    static func showsHero(hasHeroData: Bool, isExpensesOnlyMode: Bool, hasCalculatedBalance: Bool) -> Bool {
        if hasHeroData { return true }
        return !isExpensesOnlyMode && hasCalculatedBalance
    }

    /// El dato del mes mientras el pase del hero no ha terminado. `HeroMonthView` no lo pinta: solo lo recibe.
    static let pendingMonthData = HeroMonthData(state: .neutral, income: 0, expense: 0, daysRemaining: 0, daysElapsed: 0)

    /// Mes al que pone nombre el rótulo, o `nil` si el período no es un mes de calendario.
    static func namedMonth(
        for period: DetailPeriod,
        now: Date = .now,
        calendar: Calendar = userConfiguredCalendar()
    ) -> Date? {
        switch period {
        case .thisMonth:
            return now
        case .lastMonth:
            return calendar.date(byAdding: .month, value: -1, to: now)
        default:
            return nil
        }
    }

    /// La cifra grande: el saldo tal cual, con su signo. «Tu saldo hoy −S/ 500» dice la verdad sin un rótulo de deuda.
    static func bigFigureValue(totalBalance: Double) -> Double {
        totalBalance
    }

    /// El rótulo de la cifra en «Solo gastos» («Gastos de noviembre»). Sin el período cuando no es un mes (la píldora de
    /// al lado ya lo dice).
    static func label(
        figure: PanelHeroFigure,
        period: DetailPeriod,
        now: Date = .now,
        calendar: Calendar = userConfiguredCalendar()
    ) -> String {
        let month = namedMonth(for: period, now: now, calendar: calendar)
        switch figure {
        case .balance:
            return L10n.Panel.Hero.haveToday
        case .expense:
            return PanelHeroMonthLine.expense(month: month).text
        case .income:
            return PanelHeroMonthLine.income(month: month).text
        }
    }

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = AppLocale.current
        formatter.setLocalizedDateFormatFromTemplate("LLLL")
        return formatter
    }()

    /// El nombre del mes en el idioma de la app, en la forma que va en medio de una frase. La forma independiente
    /// (`LLLL`) lo da en mayúscula en español («Octubre», medido en el simulador), así que en los idiomas que escriben
    /// los meses en minúscula se baja; en alemán o inglés se queda como viene.
    static func monthName(_ date: Date) -> String {
        let locale = AppLocale.current
        monthFormatter.locale = locale
        monthFormatter.setLocalizedDateFormatFromTemplate("LLLL")
        let name = monthFormatter.string(from: date)
        return lowercasesMonthNames(locale) ? name.lowercased(with: locale) : name
    }

    /// Idiomas que escriben los meses en minúscula dentro de una frase.
    static func lowercasesMonthNames(_ locale: Locale) -> Bool {
        ["es", "fr", "it", "pt", "nl", "pl"].contains(locale.language.languageCode?.identifier ?? "")
    }
}

/// El rótulo de un lado del período («Gastos de noviembre», «Ingresos de noviembre»). El texto se resuelve aparte para
/// que los tests comparen casos.
enum PanelHeroMonthLine: Equatable {
    /// Gastos: «Gastos de noviembre» (o «del período» si no es un mes).
    case expense(month: Date?)
    /// Ingresos: «Ingresos de noviembre».
    case income(month: Date?)

    var text: String {
        switch self {
        case .expense(let month):
            guard let month else { return StatsHeroCaption.expensePeriod.text(isClosed: false) }
            return L10n.Panel.Hero.expensesOfMonth(PanelHeroFigureLogic.monthName(month))
        case .income(let month):
            guard let month else { return StatsHeroCaption.incomePeriod.text(isClosed: false) }
            return L10n.Panel.Hero.incomeOfMonth(PanelHeroFigureLogic.monthName(month))
        }
    }
}

/// Si un período ya terminó, para decir sus cifras en pasado («Te quedó», «Tenías al cierre») y no en presente.
/// Cerrados: el mes y el año pasados, y un rango propio que acabó antes de hoy (también el que dejan las flechas del
/// período al ir hacia atrás). Lo demás llega hasta hoy.
enum PeriodTenseLogic {
    static func isClosed(
        period: DetailPeriod,
        customRange: DateInterval?,
        now: Date = .now,
        calendar: Calendar = userConfiguredCalendar()
    ) -> Bool {
        switch period {
        case .lastMonth, .lastYear:
            return true
        case .custom:
            guard let customRange else { return false }
            return customRange.end < calendar.startOfDay(for: now)
        case .thisWeek, .last7Days, .last30Days, .thisMonth, .thisYear, .allTime:
            return false
        }
    }
}
