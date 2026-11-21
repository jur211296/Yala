//
//  VocabularioTienesTeQuedaTests.swift
//  YalaTests
//
//  Decisión 8 de la revisión 2.3 (9-nov-2026, opción C): un solo vocabulario para el dinero en toda la app.
//  «Tienes» / «Saldo» es lo que hay en las cuentas; «Te queda» es lo que entró menos lo que salió; «Balance» y
//  «Disponible» desaparecen. Un caso por punto del encargo:
//  1. El hero del Panel (desde el 2026-11-16): la cifra grande es «Tu saldo hoy», con su signo y sin «Debes hoy»
//     (BRAND-VOICE §8); debajo, «Tu dinero hoy». La línea del mes («Te queda») salió del hero.
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

    @Test("La cifra grande es «Tu saldo hoy» con su signo: nunca un rótulo de deuda")
    func panelBigFigure_isTheAccountsBalance() {
        #expect(PanelHeroFigureLogic.bigFigureValue(totalBalance: 64_690.04) == 64_690.04)
        #expect(PanelHeroFigureLogic.bigFigureValue(totalBalance: -1_284.30) == -1_284.30)
        #expect(PanelHeroFigureLogic.label(figure: .balance, period: .thisMonth) == L10n.Panel.Hero.haveToday)
    }

    @Test("En «Solo gastos» el rótulo dice el lado y el mes; sin mes, el período")
    func panelExpensesOnlyLabel() {
        let now = Self.now, calendar = Self.calendar
        #expect(PanelHeroFigureLogic.label(figure: .expense, period: .thisMonth, now: now, calendar: calendar)
                == PanelHeroMonthLine.expense(month: now).text)
        #expect(PanelHeroFigureLogic.label(figure: .expense, period: .thisYear, now: now, calendar: calendar)
                == PanelHeroMonthLine.expense(month: nil).text)
    }

    @Test("El hero del Panel pinta el saldo con su signo y «Tu dinero hoy» debajo; ya no la línea del mes")
    func panelHero_wiresBothFigures() throws {
        let hero = try Self.repoFile("Yala/App/Views/Panel/HeroMonthView.swift")
        #expect(hero.contains("value: PanelHeroFigureLogic.bigFigureValue(totalBalance: totalBalance ?? 0),"),
                "La cifra grande del Panel ya no es el saldo de las cuentas.")
        #expect(hero.contains("return L10n.Panel.Hero.haveToday"), "El rótulo de la cifra grande no es «Tu saldo hoy».")
        #expect(!hero.contains("oweToday"), "El hero vuelve a decir «Debes hoy» (BRAND-VOICE §8).")
        #expect(hero.contains("Text(L10n.SaldoPanel.moneyToday)"), "Falta «Tu dinero hoy» bajo la cifra grande.")
        #expect(hero.contains("\"panel_hero_money_line\""))
        #expect(!hero.contains("panel_hero_month_line"), "La línea del mes volvió al hero: ya la cuenta Flujo de caja.")
        #expect(!hero.contains("leftNow"), "El hero vuelve a decir «Te queda».")
        #expect(!hero.contains("balanceOfMonth"), "El hero vuelve a decir «Balance de <mes>».")
        // «Solo gastos» conserva «Gastos de <mes>»: antes decía «Gastado».
        #expect(hero.contains("PanelHeroFigureLogic.label(figure: .expense, period: selectedPeriod)"))
        #expect(!hero.contains("L10n.Panel.spent"))
    }

    @Test("Los textos del Panel en español: «Tu saldo hoy» y «Tu dinero hoy», sin «Debes», «Disponible» ni «liquidez»")
    func panelCopy_spanish() throws {
        for language in ["es", "es-419", "es-AR", "es-ES"] {
            let entries = try Self.catalog("Yala/Resources/\(language).lproj/Localizable.strings")
            #expect(entries["panel.hero.haveToday"] == "Tu saldo hoy", "\(language)")
            #expect(entries["panel.saldo.moneyToday"] == "Tu dinero hoy", "\(language)")
            for (key, value) in entries where key.hasPrefix("panel.saldo.") || key == "panel.hero.haveToday" {
                #expect(!value.contains("Debes") && !value.contains("debes"), "\(key) dice «debes» (§8).")
                #expect(!value.lowercased().contains("disponible"), "\(key) dice «disponible».")
                #expect(!value.lowercased().contains("liquidez"), "\(key) usa jerga (§2.2).")
                #expect(!value.contains("Balance"), "\(key) dice «Balance» (§2.2).")
            }
        }
        let es = try Self.catalog("Yala/Resources/es.lproj/Localizable.strings")
        // «Te queda / Te quedó» salió de la app el 20-nov-2026 (hero de Estadísticas, Sankey y voz), pero Yala web los
        // sigue enseñando y lee estas claves de aquí (`webapp/test/lote4.test.ts`): se quedan.
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
            "panel.hero.leftInMonth",
            "panel.saldo.moneyToday", "panel.saldo.infoButton", "panel.saldo.info.title", "panel.saldo.info.balanceBody",
            "panel.saldo.info.moneyBody", "panel.saldo.info.exampleTitle", "panel.saldo.info.exampleSavings",
            "panel.saldo.info.exampleCard", "panel.saldo.info.exampleNote", "panel.saldo.info.chooseAccounts",
            "panel.saldo.info.chooseHint", "panel.saldo.accounts.title", "panel.saldo.countsToggle", "panel.saldo.countsHint",
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

    @Test("Estadísticas usa la palabra del Panel: «Tu dinero hoy», y «Tu dinero al cierre» con un período cerrado")
    func statisticsCaptions_useThePanelWords() {
        #expect(StatsHeroCaption.moneyToday.text(isClosed: false) == L10n.SaldoPanel.moneyToday)
        #expect(StatsHeroCaption.moneyToday.text(isClosed: true) == HeroEstadisticasText.moneyAtClose)
        // Los lados sueltos no cambian de nombre con el tiempo.
        #expect(StatsHeroCaption.expensePeriod.text(isClosed: true) == StatsHeroCaption.expensePeriod.text(isClosed: false))
        // El sobrante del flujo de Distribución es «Diferencia», en curso y cerrado (20-nov-2026).
        #expect(SankeyFlowCalculator.leftoverLabel(periodIsClosed: false) == HeroEstadisticasText.difference)
        #expect(SankeyFlowCalculator.leftoverLabel(periodIsClosed: true) == HeroEstadisticasText.difference)
    }

    @Test("Las cuatro pestañas pasan el tiempo del período al rótulo")
    func statisticsTabs_passTheTense() throws {
        for tab in ["CategoriesTabView", "TrendsTabView", "InsightsTabView", "RecordsTabView"] {
            let src = try Self.repoFile("Yala/App/Views/Statistics/\(tab).swift")
            #expect(src.contains("StatsHeroView("), "\(tab) no monta el hero compartido.")
        }
        let hero = try Self.repoFile("Yala/App/Views/Statistics/StatsHeroView.swift")
        #expect(hero.contains("PeriodTenseLogic.isClosed(period: sessionState.selectedPeriod, customRange: sessionState.customDateRange)"),
                "El hero pinta el rótulo sin saber si el período terminó.")
        #expect(hero.contains("caption.text(isClosed: isClosed)"))
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
            #expect(entries["stats.trends.heroStable"] == nil)
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
