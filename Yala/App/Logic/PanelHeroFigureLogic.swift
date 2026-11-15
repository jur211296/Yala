//
//  PanelHeroFigureLogic.swift
//  Yala
//
//  Qué cifras enseña el hero del Panel y cómo se llaman.
//
//  Desde la decisión 8 de la revisión 2.3 (9-nov-2026, opción C) el hero tiene dos cifras con un nombre cada una, el
//  mismo en toda la app:
//  - La GRANDE es lo que hay en las cuentas: «Tienes hoy» (o «Debes hoy» en rojo). No sigue al período: antes era el
//    «Balance de noviembre» (lo que entró menos lo que salió) y se leía como «lo que tengo».
//  - La LÍNEA del mes, debajo, es lo que entró menos lo que salió: «Te queda» en un período en curso, «Te quedó» en uno
//    cerrado. Período y píldoras mueven solo esta línea: con una píldora puesta dice lo que filtra («Gastos de
//    noviembre»), con las palabras de Estadísticas.
//  - En «Solo gastos» el hero no cambia de forma: la cifra grande es el gasto del período («Gastos de noviembre»).
//

import Foundation

enum PanelHeroFigure: Equatable {
    case balance
    case expense
    case income

    /// La cifra que cuenta cada caso. El balance puede ser negativo: la línea «Entró − salió» de debajo tiene que
    /// cuadrar con él, y «Disponible» se quedaba en 0 cuando salía más de lo que entraba.
    func value(income: Double, expense: Double) -> Double {
        switch self {
        case .balance: return income - expense
        case .expense: return expense
        case .income: return income
        }
    }
}

enum PanelHeroFigureLogic {

    /// La píldora puesta decide la cifra. `natures` es el filtro global de naturaleza; con las dos o ninguna, balance.
    static func figure(natures: Set<TransactionNature>) -> PanelHeroFigure {
        if natures == [.expense] { return .expense }
        if natures == [.income] { return .income }
        return .balance
    }

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

    /// Cómo se llama la cifra grande: lo que hay en las cuentas, o lo que se debe si el saldo está en rojo.
    /// «Debes» empieza donde la cifra redondeada a céntimos ya no es cero, para no decir «Debes hoy S/ 0.00».
    static func bigFigureCaption(totalBalance: Double) -> PanelHeroBigCaption {
        totalBalance <= -0.005 ? .oweToday : .haveToday
    }

    /// La cifra grande va sin signo: el rótulo ya dice si es deuda.
    static func bigFigureValue(totalBalance: Double) -> Double {
        abs(totalBalance)
    }

    /// Qué dice la línea del mes. El neto va en presente en un período en curso y en pasado en uno cerrado; el mes
    /// pasado lleva su nombre. Con una píldora puesta, el lado que filtra con el nombre de su mes.
    static func monthLine(
        figure: PanelHeroFigure,
        period: DetailPeriod,
        customRange: DateInterval?,
        now: Date = .now,
        calendar: Calendar = userConfiguredCalendar()
    ) -> PanelHeroMonthLine {
        let month = namedMonth(for: period, now: now, calendar: calendar)
        switch figure {
        case .expense: return .expense(month: month)
        case .income: return .income(month: month)
        case .balance:
            guard PeriodTenseLogic.isClosed(period: period, customRange: customRange, now: now, calendar: calendar) else {
                return .leftNow
            }
            if period == .lastMonth, let month { return .leftInMonth(month) }
            return .leftPast
        }
    }

    /// El rótulo del lado que filtra una píldora, o de la cifra en «Solo gastos». Sin el período cuando no es un mes
    /// (la píldora de al lado ya lo dice).
    static func label(
        figure: PanelHeroFigure,
        period: DetailPeriod,
        now: Date = .now,
        calendar: Calendar = userConfiguredCalendar()
    ) -> String {
        let month = namedMonth(for: period, now: now, calendar: calendar)
        switch figure {
        case .balance:
            return PanelHeroMonthLine.leftNow.text
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

/// El nombre de la cifra grande del Panel (decisión 8 de 2.3).
enum PanelHeroBigCaption: Equatable {
    case haveToday
    case oweToday

    var text: String {
        switch self {
        case .haveToday: return L10n.Panel.Hero.haveToday
        case .oweToday: return L10n.Panel.Hero.oweToday
        }
    }
}

/// El rótulo de la línea del mes del Panel. El texto se resuelve aparte para que los tests comparen casos.
enum PanelHeroMonthLine: Equatable {
    /// Lo que entró menos lo que salió, en un período en curso: «Te queda».
    case leftNow
    /// Lo mismo en un período cerrado: «Te quedó».
    case leftPast
    /// El mes pasado, con su nombre: «En octubre te quedó».
    case leftInMonth(Date)
    /// Con la píldora de gastos: «Gastos de noviembre» (o «del período» si no es un mes).
    case expense(month: Date?)
    /// Con la píldora de ingresos: «Ingresos de noviembre».
    case income(month: Date?)

    var text: String {
        switch self {
        case .leftNow: return L10n.Panel.Hero.leftNow
        case .leftPast: return L10n.Panel.Hero.leftPast
        case .leftInMonth(let month): return L10n.Panel.Hero.leftInMonth(PanelHeroFigureLogic.monthName(month))
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
