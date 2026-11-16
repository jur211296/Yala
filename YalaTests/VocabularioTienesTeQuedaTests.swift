//
//  VocabularioTienesTeQuedaTests.swift
//  YalaTests
//
//  Decisión 8 de la revisión 2.3 (9-nov-2026, opción C): un solo vocabulario para el dinero en toda la app.
//  «Tienes» / «Saldo» es lo que hay en las cuentas; «Te queda» es lo que entró menos lo que salió; «Balance» y
//  «Disponible» desaparecen. Un caso por punto del encargo:
//  1. El hero del Panel: la cifra grande es «Tienes hoy» y no sigue al período; la línea del mes es «Te queda».
//  2. Estadísticas: sus tres nombres casi iguales pasan a las mismas palabras, en pasado con un período cerrado.
//  3. Los widgets dejan de decir «Disponible».
//

import Foundation
import Testing

@testable import Yala

@Suite("Vocabulario «Tienes hoy» / «Te queda» (decisión 8 de 2.3)")
struct VocabularioTienesTeQuedaTests {

    // MARK: - Fixtures

    /// Un 20 de noviembre a mediodía en Lima: lejos de los bordes de mes y de día.
    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Lima") ?? .gmt
        return calendar
    }()
    private static let now: Date = {
        let components = DateComponents(year: 2026, month: 11, day: 20, hour: 12)
        return calendar.date(from: components) ?? .distantPast
    }()

    private static func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .distantPast
    }

    private static func repoFile(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    /// Las parejas clave → valor de un catálogo `.strings`.
    private static func catalog(_ path: String) throws -> [String: String] {
        let text = try repoFile(path)
        var entries: [String: String] = [:]
        let pattern = try NSRegularExpression(pattern: #"^"([^"]+)"\s*=\s*"((?:[^"\\]|\\.)*)";"#, options: .anchorsMatchLines)
        let range = NSRange(text.startIndex..., in: text)
        for match in pattern.matches(in: text, range: range) {
            guard let key = Range(match.range(at: 1), in: text), let value = Range(match.range(at: 2), in: text) else { continue }
            entries[String(text[key])] = String(text[value])
        }
        return entries
    }

    private static let languages = [
        "es", "es-419", "es-AR", "es-ES", "en", "en-GB", "de", "fr", "it", "ja", "nl", "pl", "pt-BR", "pt-PT", "pt", "zh-Hans",
    ]

    // MARK: - 1. Panel

    @Test("La cifra grande es lo que hay en las cuentas: «Tienes hoy», o «Debes hoy» sin signo")
    func panelBigFigure_isTheAccountsBalance() {
        #expect(PanelHeroFigureLogic.bigFigureCaption(totalBalance: 64_690.04) == .haveToday)
        #expect(PanelHeroFigureLogic.bigFigureCaption(totalBalance: 0) == .haveToday)
        #expect(PanelHeroFigureLogic.bigFigureCaption(totalBalance: -1_284.30) == .oweToday)
        // Un saldo que se pinta «0.00» no es una deuda.
        #expect(PanelHeroFigureLogic.bigFigureCaption(totalBalance: -0.004) == .haveToday)
        #expect(PanelHeroFigureLogic.bigFigureValue(totalBalance: -1_284.30) == 1_284.30)
        #expect(PanelHeroFigureLogic.bigFigureValue(totalBalance: 64_690.04) == 64_690.04)
    }

    @Test("La línea del mes: «Te queda» en curso, «Te quedó» cerrado, el mes pasado con su nombre")
    func panelMonthLine_followsThePeriodTense() {
        let now = Self.now, calendar = Self.calendar
        func line(_ figure: PanelHeroFigure, _ period: DetailPeriod, _ range: DateInterval? = nil) -> PanelHeroMonthLine {
            PanelHeroFigureLogic.monthLine(figure: figure, period: period, customRange: range, now: now, calendar: calendar)
        }

        #expect(line(.balance, .thisMonth) == .leftNow)
        #expect(line(.balance, .thisWeek) == .leftNow)
        #expect(line(.balance, .thisYear) == .leftNow)
        #expect(line(.balance, .allTime) == .leftNow)
        #expect(line(.balance, .lastYear) == .leftPast)
        let october = calendar.date(byAdding: .month, value: -1, to: now) ?? now
        #expect(line(.balance, .lastMonth) == .leftInMonth(october))

        // Un rango que acabó antes de hoy (lo que dejan las flechas hacia atrás) va en pasado; uno que llega a hoy, no.
        let september = DateInterval(start: Self.day(2026, 9, 1), end: Self.day(2026, 9, 30))
        #expect(line(.balance, .custom, september) == .leftPast)
        let untilToday = DateInterval(start: Self.day(2026, 11, 1), end: Self.day(2026, 11, 20))
        #expect(line(.balance, .custom, untilToday) == .leftNow)

        // Las píldoras mueven solo la línea: dice el lado que filtran.
        #expect(line(.expense, .thisMonth) == .expense(month: now))
        #expect(line(.income, .thisMonth) == .income(month: now))
        #expect(line(.expense, .thisYear) == .expense(month: nil))
    }

    @Test("El hero del Panel pinta el saldo en la cifra grande y el neto en la línea, no «Balance de <mes>»")
    func panelHero_wiresBothFigures() throws {
        let hero = try Self.repoFile("Yala/App/Views/Panel/HeroMonthView.swift")
        #expect(hero.contains("value: PanelHeroFigureLogic.bigFigureValue(totalBalance: totalBalance ?? 0),"),
                "La cifra grande del Panel ya no es el saldo de las cuentas.")
        #expect(hero.contains("PanelHeroFigureLogic.bigFigureCaption(totalBalance: totalBalance ?? 0).text"),
                "El rótulo de la cifra grande no es «Tienes hoy» / «Debes hoy».")
        #expect(hero.contains("PanelHeroFigureLogic.monthLine(figure: figure, period: selectedPeriod, customRange: customDateRange)"),
                "La línea del mes no sigue a la píldora y al período.")
        #expect(hero.contains("\"panel_hero_month_line\""))
        #expect(!hero.contains("balanceOfMonth"), "El hero vuelve a decir «Balance de <mes>».")
        // «Solo gastos» conserva «Gastos de <mes>»: antes decía «Gastado».
        #expect(hero.contains("PanelHeroFigureLogic.label(figure: .expense, period: selectedPeriod)"))
        #expect(!hero.contains("L10n.Panel.spent"))
    }

    @Test("Los textos del Panel en español dicen «Tienes hoy» y «Te queda», nunca «te sobra»")
    func panelCopy_spanish() throws {
        let es = try Self.catalog("Yala/Resources/es.lproj/Localizable.strings")
        #expect(es["panel.hero.haveToday"] == "Tienes hoy")
        #expect(es["panel.hero.oweToday"] == "Debes hoy")
        #expect(es["panel.hero.leftNow"] == "Te queda")
        #expect(es["panel.hero.leftPast"] == "Te quedó")
        #expect(es["panel.hero.leftInMonth"] == "En %@ te quedó")
        for (key, value) in es where key.hasPrefix("panel.hero.") {
            #expect(!value.lowercased().contains("sobr"), "\(key) dice «sobra/sobró»: la decisión pide «te queda».")
            #expect(!value.contains("Balance"), "\(key) vuelve a decir «Balance».")
        }
        #expect(es["panel.hero.balanceOfMonth"] == nil)
    }

    @Test("Los textos nuevos existen en los 16 idiomas")
    func newKeys_inAllSixteenLanguages() throws {
        let keys = [
            "panel.hero.haveToday", "panel.hero.oweToday", "panel.hero.leftNow", "panel.hero.leftPast",
            "panel.hero.leftInMonth", "stats.hero.captionAccountsBalanceClosed",
        ]
        for language in Self.languages {
            let entries = try Self.catalog("Yala/Resources/\(language).lproj/Localizable.strings")
            for key in keys {
                let value = entries[key] ?? ""
                #expect(!value.isEmpty, "Falta \(key) en \(language).")
            }
            #expect(entries["panel.hero.leftInMonth"]?.contains("%@") == true, "leftInMonth sin el mes en \(language).")
        }
    }

    // MARK: - 2. Estadísticas

    @Test("Período cerrado: el mes y el año pasados, y un rango que acabó antes de hoy")
    func periodTense() {
        let now = Self.now, calendar = Self.calendar
        func closed(_ period: DetailPeriod, _ range: DateInterval? = nil) -> Bool {
            PeriodTenseLogic.isClosed(period: period, customRange: range, now: now, calendar: calendar)
        }
        #expect(closed(.lastMonth))
        #expect(closed(.lastYear))
        for open in [DetailPeriod.thisWeek, .last7Days, .last30Days, .thisMonth, .thisYear, .allTime] {
            #expect(!closed(open), "\(open) llega hasta hoy: va en presente.")
        }
        #expect(closed(.custom, DateInterval(start: Self.day(2026, 9, 1), end: Self.day(2026, 9, 30))))
        #expect(!closed(.custom, DateInterval(start: Self.day(2026, 11, 1), end: Self.day(2026, 11, 30))))
        #expect(!closed(.custom, nil))
    }

    @Test("Estadísticas usa las palabras del Panel: «Te queda / Te quedó» y «Tienes hoy / Tenías al cierre»")
    func statisticsCaptions_useThePanelWords() {
        #expect(StatsHeroCaption.netPeriod.text(isClosed: false) == L10n.Panel.Hero.leftNow)
        #expect(StatsHeroCaption.netPeriod.text(isClosed: true) == L10n.Panel.Hero.leftPast)
        #expect(StatsHeroCaption.accountsBalance.text(isClosed: false) == L10n.Panel.Hero.haveToday)
        #expect(StatsHeroCaption.accountsBalance.text(isClosed: true) == L10n.Stats.Hero.captionAccountsBalanceClosed)
        // Los lados sueltos no cambian de nombre con el tiempo.
        #expect(StatsHeroCaption.expensePeriod.text(isClosed: true) == StatsHeroCaption.expensePeriod.text(isClosed: false))
        // El sobrante del flujo de Distribución, igual.
        #expect(SankeyFlowCalculator.leftoverLabel(periodIsClosed: false) == L10n.Panel.Hero.leftNow)
        #expect(SankeyFlowCalculator.leftoverLabel(periodIsClosed: true) == L10n.Panel.Hero.leftPast)
    }

    @Test("Las cuatro pestañas pasan el tiempo del período al rótulo")
    func statisticsTabs_passTheTense() throws {
        for tab in ["CategoriesTabView", "TrendsTabView", "InsightsTabView", "RecordsTabView"] {
            let src = try Self.repoFile("Yala/App/Views/Statistics/\(tab).swift")
            #expect(src.contains(".text(isClosed: PeriodTenseLogic.isClosed(period: sessionState.selectedPeriod, customRange: sessionState.customDateRange))"),
                    "\(tab) pinta el rótulo sin saber si el período terminó.")
        }
        let viewModel = try Self.repoFile("Yala/App/ViewModels/StatisticsViewModel.swift")
        #expect(viewModel.contains("periodIsClosed: PeriodTenseLogic.isClosed(period: detailPeriod, customRange: customDateRange)"))
    }

    @Test("En español Estadísticas ya no dice «Balance» ni «Saldo de cuentas»")
    func statisticsCopy_spanish() throws {
        for language in ["es", "es-419", "es-AR", "es-ES"] {
            let entries = try Self.catalog("Yala/Resources/\(language).lproj/Localizable.strings")
            #expect(entries["stats.hero.captionNetPeriod"] == nil)
            #expect(entries["stats.hero.captionAccountsBalance"] == nil)
            #expect(entries["statistics.sankey.available"] == nil)
            // El botón de la gráfica de saldo decía «Saldo» en pantalla y «Balance» a VoiceOver.
            #expect(entries["accessibility.metricBalance"] == entries["trendType.balance"])
            #expect(entries["accessibility.metricBalance"] == "Saldo")
            #expect(entries["stats.trends.heroStable"]?.contains("balance") == false)
        }
    }

    // MARK: - 3. Widgets

    @Test("Los widgets dicen «Saldo», no «Disponible»")
    func widgets_sayBalanceNotAvailable() throws {
        for file in [
            "YalaWidgets/Widgets/BalanceWidget.swift", "YalaWidgets/Widgets/AccessoryWidgets.swift",
            "YalaWidgets/Widgets/MonthSummaryWidget.swift", "YalaWidgets/Widgets/MonthSummaryPortraitView.swift",
        ] {
            let src = try Self.repoFile(file)
            #expect(!src.contains("widget.ui.available"), "\(file) vuelve a pintar «Disponible».")
            #expect(src.contains("\"widget.ui.balance\""), "\(file) no pinta «Saldo».")
        }
        for language in Self.languages {
            let entries = try Self.catalog("YalaWidgets/Resources/\(language).lproj/Localizable.strings")
            #expect(entries["widget.ui.available"] == nil, "Sigue la clave de «Disponible» en \(language).")
            // El nombre del widget en la galería y al configurarlo es el mismo que el de dentro.
            let name = entries["widget.ui.balance"]
            #expect(name != nil && !(name ?? "").isEmpty)
            #expect(entries["widget.gallery.balance"] == name, "La galería y el widget no se llaman igual en \(language).")
            #expect(entries["widget.gallery.accessoryBalance"] == name)
            #expect(entries["widget.intent.balance.title"] == name)
            #expect(entries["widget.intent.accessoryBalance.title"] == name)
        }
        let es = try Self.catalog("YalaWidgets/Resources/es.lproj/Localizable.strings")
        #expect(es["widget.ui.balance"] == "Saldo")
        for (key, value) in es {
            #expect(!value.contains("Disponible") && !value.contains("disponible"), "\(key) dice «disponible».")
            #expect(!value.contains("balance"), "\(key) dice «balance».")
        }
    }
}
