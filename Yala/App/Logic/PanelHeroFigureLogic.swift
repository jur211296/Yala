//
//  PanelHeroFigureLogic.swift
//  Yala
//
//  Qué cifra enseña el hero del Panel y cómo se llama (UX 2.2 · L3-1, L3-2 y L3-3).
//
//  - Sin filtro de naturaleza, la cifra es el BALANCE del período: lo que entró menos lo que salió. Se llamaba
//    «Disponible» y se leía como «lo que tengo»; el primer día salía S/ 0 junto a «Tienes S/ 1.800».
//  - Con una píldora puesta (solo gastos o solo ingresos), la cifra cuenta lo mismo que filtra: antes el filtro
//    cambiaba el resto del Panel y la cifra grande seguía diciendo el balance.
//  - Los meses llevan su nombre («Balance de octubre»); los demás períodos dicen «del período», con las mismas
//    palabras que Estadísticas, para que el número no cambie de nombre al tocarlo.
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

    /// El rótulo del hero, sin el período cuando no es un mes (la píldora de al lado ya lo dice).
    static func label(
        figure: PanelHeroFigure,
        period: DetailPeriod,
        now: Date = .now,
        calendar: Calendar = userConfiguredCalendar()
    ) -> String {
        guard let month = namedMonth(for: period, now: now, calendar: calendar) else {
            switch figure {
            case .balance: return StatsHeroCaption.netPeriod.text
            case .expense: return StatsHeroCaption.expensePeriod.text
            case .income: return StatsHeroCaption.incomePeriod.text
            }
        }
        let name = monthName(month)
        switch figure {
        case .balance: return L10n.Panel.Hero.balanceOfMonth(name)
        case .expense: return L10n.Panel.Hero.expensesOfMonth(name)
        case .income: return L10n.Panel.Hero.incomeOfMonth(name)
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
