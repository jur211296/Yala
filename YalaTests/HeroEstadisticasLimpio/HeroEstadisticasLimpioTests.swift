//
//  HeroEstadisticasLimpioTests.swift
//  YalaTests
//
//  Hero de Estadísticas limpio (decisión de Jürgen del 20-nov-2026):
//  1. Todas las pestañas enseñan «Tu dinero hoy», la misma cifra que el Panel; «Tu dinero al cierre» con un período
//     cerrado. Desaparece «Te queda» (ingresos − gastos) del hero, del Sankey y de la voz.
//  2. El hero solo lleva la cifra con su rótulo y, debajo, ingresos y gastos con sus flechas: sin «Ingresos»/«Gastos»
//     escritos ni la línea de abajo.
//  3. Un solo hero para las cuatro pestañas (Distribución igual que el resto).
//
//  El fixture lleva siempre una tarjeta de crédito: sin ella «Tu dinero hoy» y el saldo de todas las cuentas coinciden y
//  la cifra vieja de Distribución pasaría por la nueva.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

// MARK: - Rótulo por pestaña y estado

@MainActor
@Suite("Hero limpio · rótulo por pestaña y estado")
struct HeroEstadisticasLimpioCaptionTests {

    @Test("Sin filtros de un lado, las cuatro pestañas dicen «Tu dinero hoy»")
    func everyTab_saysMoneyToday() {
        #expect(StatsHeroCaptionLogic.insights(expensesOnly: false) == .moneyToday)
        #expect(StatsHeroCaptionLogic.trends(metric: .balance) == .moneyToday)
        #expect(StatsHeroCaptionLogic.distribution(isBalanceMode: true, natures: []) == .moneyToday)
        #expect(StatsHeroCaptionLogic.records(natures: [], expensesOnly: false) == .moneyToday)
        #expect(StatsHeroCaptionLogic.records(natures: [.income, .expense], expensesOnly: false) == .moneyToday)
    }

    @Test("Los estados de un lado no cambian: chip, métrica, filtro de Distribución y «Solo gastos»")
    func oneSidedStates_stayAsTheyWere() {
        #expect(StatsHeroCaptionLogic.trends(metric: .income) == .incomePeriod)
        #expect(StatsHeroCaptionLogic.trends(metric: .expense) == .expensePeriod)
        #expect(StatsHeroCaptionLogic.records(natures: [.income], expensesOnly: false) == .incomePeriod)
        #expect(StatsHeroCaptionLogic.records(natures: [.expense], expensesOnly: false) == .expensePeriod)
        // Distribución fuera de su modo saldo (filtro de categoría o «Solo gastos») sigue a la tarta.
        #expect(StatsHeroCaptionLogic.distribution(isBalanceMode: false, natures: []) == .expensePeriod)
        #expect(StatsHeroCaptionLogic.distribution(isBalanceMode: false, natures: [.income]) == .incomePeriod)
        #expect(StatsHeroCaptionLogic.distribution(isBalanceMode: false, natures: [.income, .expense]) == .totalPeriod)
        // «Solo gastos»: el gasto, en Resumen y en Registros.
        #expect(StatsHeroCaptionLogic.insights(expensesOnly: true) == .expensePeriod)
        #expect(StatsHeroCaptionLogic.records(natures: [], expensesOnly: true) == .expensePeriod)
    }

    @Test("Abierto «Tu dinero hoy» (el rótulo del Panel); cerrado «Tu dinero al cierre»")
    func moneyToday_textFollowsTheTense() {
        #expect(StatsHeroCaption.moneyToday.text(isClosed: false) == L10n.SaldoPanel.moneyToday)
        #expect(StatsHeroCaption.moneyToday.text(isClosed: true) == HeroEstadisticasText.moneyAtClose)
        #expect(HeroEstadisticasText.moneyAtClose != L10n.SaldoPanel.moneyToday)
        #expect(!HeroEstadisticasText.moneyAtClose.hasPrefix("heroEstadisticas."))
    }

    @Test("Ningún rótulo dice «Te queda»")
    func noCaption_saysLeftOver() {
        for caption in StatsHeroCaption.allCases {
            for isClosed in [false, true] {
                let text = caption.text(isClosed: isClosed).lowercased()
                #expect(!text.contains("te qued"), "\(caption) dice «\(text)»")
            }
        }
    }

    @Test("La hoja del «?» explica «Tu dinero hoy» y su ejemplo cuadra")
    func infoSheet_explainsMoneyToday() throws {
        #expect(HeroClaroLogic.topic(for: .moneyToday) == .moneyToday)
        let rows = HeroClaroLogic.example(for: .moneyToday)
        let result = try #require(rows.last)
        #expect(result.label == .moneyToday && result.isResult)
        #expect(result.value == rows.dropLast().map(\.value).reduce(0, +))
    }

    /// Distribución con el chip «Gastos»: la cifra grande (suma de la tarta) y la flecha de gastos dicen lo mismo, así que
    /// llevan la misma marca. Con importes distintos no se presta: la proporción sería de otro número.
    @Test("La cifra de un lado lleva la marca de su flecha solo si es el mismo importe")
    func sideMark_followsTheArrowOnlyWhenEqual() {
        let marked = StatsHeroFlow(income: 500, expense: 1_200, incomeIsApproximate: false, expenseIsApproximate: true)
        #expect(StatsMoneyTodayLogic.sideMark(caption: .expensePeriod, shown: 1_200, flow: marked))
        #expect(!StatsMoneyTodayLogic.sideMark(caption: .expensePeriod, shown: 1_150, flow: marked),
                "Importe distinto (una devolución, «Sin categoría»): la marca de la flecha no es la de lo mostrado.")
        #expect(!StatsMoneyTodayLogic.sideMark(caption: .incomePeriod, shown: 500, flow: marked),
                "El lado de ingresos no hereda la marca del de gastos.")
        #expect(!StatsMoneyTodayLogic.sideMark(caption: .totalPeriod, shown: 1_700, flow: marked))
        #expect(!StatsMoneyTodayLogic.sideMark(caption: .expensePeriod, shown: 1_200, flow: nil))
    }

    @Test("Sankey y resumen en voz dicen «Diferencia», no «Te queda»")
    func sankeyAndVoice_sayDifference() {
        #expect(SankeyFlowCalculator.leftoverLabel(periodIsClosed: false) == HeroEstadisticasText.difference)
        #expect(SankeyFlowCalculator.leftoverLabel(periodIsClosed: true) == HeroEstadisticasText.difference)
        let spoken = ChartSpokenSummary.cashFlow(
            income: "S/ 5,000", expense: "S/ 3,500", net: 1_500, isClosed: true,
            format: ChartAmountFormat(decimals: 0, identifier: "S/", hidden: false)
        )
        #expect(spoken.contains(HeroEstadisticasText.difference))
        #expect(!spoken.lowercased().contains("te qued"))
    }
}

// MARK: - La cifra es la del Panel

@MainActor
@Suite("Hero limpio · la cifra es la del Panel", .serialized)
struct HeroEstadisticasLimpioFigureTests {

    private func account(_ name: String, _ type: AccountType) -> Account {
        Account(
            name: name, currencyCode: "PEN", colorHex: "#6366F1", iconName: "creditcard",
            type: type.rawValue, excludeFromStatistics: false
        )
    }

    /// Fechas fijas y en el pasado: el corte de «hoy» del Panel (que no se puede inyectar) las cuenta siempre.
    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Lima") ?? .gmt
        return calendar
    }()
    private static func day(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)) ?? .distantPast
    }
    private static let pastDay = day(2025, 6, 15)

    private func movement(_ amount: Double, _ account: Account, on date: Date) -> TransactionItem {
        TransactionItem(
            date: date, amount: amount, currencyCode: "PEN", note: "",
            account: account, tags: [],
            amountInPreferredCurrency: amount, preferredCurrencyCode: "PEN"
        )
    }

    /// «Tu dinero hoy» como lo calcula el Panel: las cuentas del saldo grande de `PanelViewModel` y, de ellas, las que
    /// cuentan como dinero (`PanelHeroSection.computeMoney`).
    private func panelMoney(_ accounts: [Account], _ movements: [TransactionItem], overrides: String = "") -> Double {
        let panel = PanelViewModel()
        let total = panel.displayedBalanceInDefaultCurrency(
            accounts: accounts, transactions: movements, defaultCurrencyCode: "PEN"
        )
        let money = PanelMoneyScopeLogic.moneyBreakdown(
            accounts: accounts, totalAccountIDs: total.eligibleAccountIDs,
            overrides: PanelMoneyScopeLogic.decode(overrides),
            transactions: movements, preferredCurrencyCode: "PEN", converter: MockCurrencyConverter()
        )
        return (money.convertedTotal as NSDecimalNumber).doubleValue
    }

    private func statsMoney(
        _ accounts: [Account], _ movements: [TransactionItem], overrides: String = "", asOf: Date = .now
    ) -> Double {
        let session = SessionState.shared
        return StatsMoneyTodayLogic.figure(
            accounts: accounts, transactions: movements, currencyCode: "PEN", includeGroups: true,
            selectedAccountIDs: session.selectedAccountIDs, excludedAccountIDs: session.excludedAccountIDs,
            overrides: overrides, asOf: asOf, converter: MockCurrencyConverter()
        ).value
    }

    private func withAccountFilter(selected: Set<PersistentIdentifier>, _ body: () throws -> Void) rethrows {
        let session = SessionState.shared
        let saved = (session.selectedAccountIDs, session.excludedAccountIDs)
        session.excludedAccountIDs = []
        session.selectedAccountIDs = selected
        defer {
            session.selectedAccountIDs = saved.0
            session.excludedAccountIDs = saved.1
        }
        try body()
    }

    @Test("Sin filtros: la misma cifra que el Panel, sin la tarjeta (no el saldo de todas las cuentas)")
    func noFilters_matchesThePanel() throws {
        let savings = account("Ahorros", .savings)
        let cash = account("Efectivo", .cash)
        let card = account("Visa", .creditCard)
        let yesterday = Self.pastDay
        let movements = [movement(1_000, savings, on: yesterday), movement(150, cash, on: yesterday),
                         movement(-300, card, on: yesterday)]
        withAccountFilter(selected: []) {
            let stats = statsMoney([savings, cash, card], movements)
            #expect(stats == panelMoney([savings, cash, card], movements))
            #expect(stats == 1_150, "Contó la tarjeta: es el saldo de todas las cuentas, no «Tu dinero hoy».")
        }
    }

    @Test("Con una cuenta elegida en los filtros, sigue a la del Panel")
    func accountFilter_matchesThePanel() throws {
        let savings = account("Ahorros", .savings)
        let cash = account("Efectivo", .cash)
        let card = account("Visa", .creditCard)
        let yesterday = Self.pastDay
        let movements = [movement(1_000, savings, on: yesterday), movement(150, cash, on: yesterday),
                         movement(-300, card, on: yesterday)]
        withAccountFilter(selected: [savings.persistentModelID]) {
            #expect(statsMoney([savings, cash, card], movements) == panelMoney([savings, cash, card], movements))
            #expect(statsMoney([savings, cash, card], movements) == 1_000)
        }
    }

    @Test("Con la tarjeta encendida en «Tu dinero hoy», la cuenta igual que el Panel")
    func cardTurnedOn_matchesThePanel() throws {
        let savings = account("Ahorros", .savings)
        let card = account("Visa", .creditCard)
        let yesterday = Self.pastDay
        let movements = [movement(1_000, savings, on: yesterday), movement(-300, card, on: yesterday)]
        let overrides = PanelMoneyScopeLogic.encode([card.shortcutID: true])
        withAccountFilter(selected: []) {
            #expect(statsMoney([savings, card], movements, overrides: overrides)
                    == panelMoney([savings, card], movements, overrides: overrides))
            #expect(statsMoney([savings, card], movements, overrides: overrides) == 700)
        }
    }

    @Test("Período cerrado: «Tu dinero al cierre» no cuenta lo que pasó después del cierre")
    func closedPeriod_countsUntilItsClose() throws {
        let savings = account("Ahorros", .savings)
        // Marzo de 2025, cerrado; y un movimiento de abril, después del cierre.
        let march = DateInterval(start: Self.day(2025, 3, 1, hour: 0), end: Self.day(2025, 4, 1, hour: 0).addingTimeInterval(-1))
        let movements = [movement(1_000, savings, on: Self.day(2025, 3, 20)), movement(500, savings, on: Self.day(2025, 4, 5))]
        withAccountFilter(selected: []) {
            let atClose = statsMoney([savings], movements, asOf: StatsMoneyTodayLogic.asOf(isClosed: true, interval: march))
            #expect(atClose == 1_000)
            #expect(statsMoney([savings], movements) == 1_500)
        }
    }

    @Test("El corte: hoy con un período en curso; el fin del período con uno cerrado")
    func asOf_followsTheTense() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let past = DateInterval(start: now.addingTimeInterval(-86_400 * 40), end: now.addingTimeInterval(-86_400 * 10))
        #expect(StatsMoneyTodayLogic.asOf(isClosed: false, interval: past, now: now) == now)
        #expect(StatsMoneyTodayLogic.asOf(isClosed: true, interval: past, now: now) == past.end)
        #expect(StatsMoneyTodayLogic.asOf(isClosed: true, interval: nil, now: now) == now)
    }
}

// MARK: - El hero limpio, en el código

@Suite("Hero limpio · cableado (source-scan)")
struct HeroEstadisticasLimpioWiringTests {

    private static func code(_ relative: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let raw = try String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
        // Solo código: un comentario que nombre la pieza no cuenta.
        return raw.split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> Substring in
                guard let range = line.range(of: "//") else { return line }
                return line[..<range.lowerBound]
            }
            .joined(separator: "\n")
    }

    static let tabs = [
        "Yala/App/Views/Statistics/InsightsTabView.swift",
        "Yala/App/Views/Statistics/TrendsTabView.swift",
        "Yala/App/Views/Statistics/CategoriesTabView.swift",
        "Yala/App/Views/Statistics/RecordsTabView.swift",
    ]

    /// Un solo hero para las cuatro: Distribución, sin el suyo propio.
    @Test(arguments: tabs)
    func everyTab_mountsTheSharedHero(_ path: String) throws {
        let code = try Self.code(path)
        #expect(code.contains("StatsHeroView("), "\(path) no monta el hero compartido.")
        #expect(!code.contains("HeroClaroHeader {"), "\(path) vuelve a montar su propio hero.")
        #expect(!code.contains("SummaryHeaderStack("), "\(path) vuelve a montar su propio hero.")
        #expect(!code.contains("HeroFlowAmountCaption"), "\(path) vuelve a escribir «Ingresos»/«Gastos».")
        #expect(!code.contains("motivational"), "\(path) vuelve a la línea «X registros · Sigue así».")
        #expect(!code.contains("heroSubtitle"), "\(path) vuelve a la línea «X categorías».")
        #expect(!code.contains("heroVariationSubtitle"), "\(path) vuelve a la frase de la variación.")
    }

    /// El hero: rótulo con su «?», cifra e ingresos y gastos con sus flechas. Nada más.
    @Test func sharedHero_isClean() throws {
        let code = try Self.code("Yala/App/Views/Statistics/StatsHeroView.swift")
        #expect(code.contains("arrow.up.right") && code.contains("arrow.down.right"))
        #expect(code.contains("StatsMoneyTodayLogic.figure("))
        #expect(!code.contains("Text(L10n.CashFlow.income)") && !code.contains("Text(L10n.CashFlow.expense)"))
        #expect(!code.contains("HeroFlowAmountCaption"))
        #expect(!code.contains("Text(subtitle)"))
    }

    /// «Tu dinero hoy» de Estadísticas sale de las mismas piezas que el del Panel, no de otro cálculo.
    @Test func moneyFigure_usesThePanelPieces() throws {
        let code = try Self.code("Yala/App/Logic/StatsMoneyTodayLogic.swift")
        #expect(code.contains("PanelTotalAccountsLogic.accountsForTotal("))
        #expect(code.contains("LiveBalanceCalculator.liveBalanceBreakdown("))
        #expect(code.contains("PanelMoneyScopeLogic.moneyBreakdown("))
        #expect(code.contains("totalAccountIDs: total.eligibleAccountIDs"))
    }

    private static let locales = [
        "es-419", "es", "es-ES", "es-AR", "en", "en-GB", "de", "fr", "it", "ja", "nl", "pl", "pt-BR", "pt", "pt-PT", "zh-Hans",
    ]

    private static func table(_ name: String, _ locale: String) throws -> [String: String] {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let url = root.appendingPathComponent("Yala/Resources/\(locale).lproj/\(name).strings")
        return try #require(NSDictionary(contentsOf: url) as? [String: String])
    }

    /// Los textos nuevos, en su tabla y en los 16 idiomas.
    @Test(arguments: locales)
    func newStrings_inEveryLanguage(_ locale: String) throws {
        let reference = try Self.table("HeroEstadisticas", "es-419")
        let here = try Self.table("HeroEstadisticas", locale)
        #expect(reference.count == 6)
        #expect(Set(here.keys) == Set(reference.keys), "\(locale) no tiene las mismas claves que es-419.")
        for (key, value) in here { #expect(!value.isEmpty && value != key, "\(locale): \(key)") }
    }

    /// Las claves que dejaron de usarse se retiraron de los 16 idiomas.
    @Test(arguments: locales)
    func retiredKeys_areGone(_ locale: String) throws {
        let strings = try Self.table("Localizable", locale)
        let retired = [
            // `panel.hero.leftNow` / `leftPast` se quedan: los lee Yala web (`webapp/test/lote4.test.ts`).
            "stats.hero.captionAccountsBalanceClosed",
            "stats.insights.motivationalOne", "stats.insights.motivationalMany %d",
            "stats.records.motivationalOne", "stats.records.motivationalMany %d",
            "stats.trends.heroOnset", "stats.trends.heroStable", "stats.trends.heroVarUp %d %@", "stats.trends.heroVarDown %d %@",
            "stats.distribution.heroSubtitle1 %d", "stats.distribution.heroSubtitle2 %d %d",
            "stats.distribution.heroSubtitle3 %d %d %d",
            "heroClaro.net.title", "heroClaro.net.body", "heroClaro.net.notBalance",
            "heroClaro.balance.title", "heroClaro.balance.body", "heroClaro.balance.closedNote",
        ]
        for key in retired { #expect(strings[key] == nil, "\(locale) conserva \(key)") }
    }
}
