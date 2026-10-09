//
//  ChatContextPanelParityAndMonthToDateTests.swift
//  YalaTests
//
//  Dos reglas del contexto de Yala IA (`FullFinancialContextBuilder`), tickets
//  `chat-context-treats-archived-accounts-as-excluded` y `chat-compares-with-the-month-in-progress`:
//
//  1. **Suma las mismas cuentas que el Panel.** Decide «Excluir de las estadísticas», no estar
//     archivada (`.claude/rules/session-filters.md`, «Archivar no decide la suma»).
//  2. **Trae el mes pasado hasta el mismo día** (`periods.last_month_to_date`, `total_last_month_to_date`)
//     y compara contra eso, con los bordes del mes: día 15, 31 frente a un mes de 30, febrero,
//     día 1 y la medianoche del día siguiente al equivalente.
//
//  `now` va inyectado y las fechas se construyen con `Calendar.current`, el mismo que usa el builder.
//  Sin `ModelContext`: `@Model` en memoria, como `FullFinancialContextBuilderTests`.
//

import Testing
import Foundation
@testable import Yala

@MainActor
@Suite(.serialized)
struct ChatContextPanelParityAndMonthToDateTests {

    // MARK: - Fixtures

    private let calendar = Calendar.current

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, _ min: Int = 0, _ s: Int = 0) -> Date {
        guard let date = calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min, second: s)) else {
            Issue.record("fecha inválida \(y)-\(m)-\(d)")
            return .distantPast
        }
        return date
    }

    private func account(
        _ name: String,
        excluded: Bool = false,
        archived: Bool = false,
        system: Bool = false
    ) -> Account {
        let account = Account(
            name: name,
            currencyCode: "USD",
            colorHex: "#000",
            iconName: "creditcard",
            type: "bank",
            excludeFromStatistics: excluded,
            isSystemAccount: system
        )
        account.isArchived = archived
        return account
    }

    private let food = YalaCategory(name: "Food", colorHex: "#000", isIncome: false)
    private let salary = YalaCategory(name: "Salary", colorHex: "#000", isIncome: true)

    private func tx(
        _ amount: Double,
        _ when: Date,
        _ account: Account? = nil,
        category: YalaCategory? = nil,
        subcategory: Subcategory? = nil,
        note: String? = nil
    ) -> TransactionItem {
        let tx = TransactionItem(
            date: when,
            amount: amount,
            currencyCode: "USD",
            note: note,
            category: category ?? (amount < 0 ? food : salary),
            amountInPreferredCurrency: amount
        )
        tx.preferredCurrencyCode = "USD"
        tx.account = account
        tx.subcategory = subcategory
        return tx
    }

    private func build(_ txs: [TransactionItem], accounts: [Account] = [], now: Date) -> FullFinancialContext {
        FullFinancialContextBuilder().buildFromArrays(
            transactions: txs,
            budgets: [],
            accounts: accounts,
            tags: [],
            scheduledPayments: [],
            currencyCode: "USD",
            currencyDisplay: "$",
            converter: MockCurrencyConverter(fixedRate: 1.0),
            language: "es",
            country: "US",
            includeAnomalies: false,
            now: now
        )
    }

    /// Lo que el Panel suma: `PanelViewModel.computeEligibleAccounts` (privada) sin filtro de cuentas
    /// —solo `excludeFromStatistics`— y el saldo vivo de `displayedBalanceInDefaultCurrency`. Si el
    /// Panel cambia de regla, `BalanceKPIParityTests` ya lo ve; aquí se copia como espejo declarado.
    private func panelTotal(_ accounts: [Account], _ txs: [TransactionItem]) -> Double {
        LiveBalanceCalculator.liveBalance(
            accounts: accounts.filter { !$0.excludeFromStatistics },
            transactions: txs,
            preferredCurrencyCode: "USD",
            converter: MockCurrencyConverter(fixedRate: 1.0)
        )
    }

    // MARK: - 1. Suma las mismas cuentas que el Panel

    @Test func archivedAccountIncludedAgain_sumsLikeThePanel() {
        let now = date(2026, 10, 15)
        let checking = account("Checking")
        let oldCard = account("Old card", archived: true)  // archivada, «Excluir» apagado a mano
        let txs = [
            tx(1000, date(2026, 10, 1), checking),
            tx(300, date(2026, 10, 2), oldCard),
            tx(-100, date(2026, 10, 5), checking),
            tx(-40, date(2026, 10, 6), oldCard),
        ]
        let accounts = [checking, oldCard]

        let context = build(txs, accounts: accounts, now: now)

        // Movimientos: el gasto de la archivada cuenta, como en el Panel.
        #expect(context.periods.currentMonth.expense == 140)
        #expect(context.periods.currentMonth.income == 1300)
        // Saldo: el total del chat es el del Panel, y la archivada sale en la lista de cuentas.
        #expect(context.balances.totalBalance == panelTotal(accounts, txs))
        #expect(context.balances.totalBalance == 1160)
        #expect(context.balances.accounts.map(\.name).sorted() == ["Checking", "Old card"])
        // Y no se le dice al modelo que está excluida: no lo está.
        #expect(context.metadata.excludedAccounts.isEmpty)
    }

    @Test func archivedAndExcluded_doesNotSum_andIsListedAsExcluded() {
        let now = date(2026, 10, 15)
        let checking = account("Checking")
        let savings = account("Savings", excluded: true, archived: true)
        let txs = [
            tx(1000, date(2026, 10, 1), checking),
            tx(5000, date(2026, 10, 1), savings),
            tx(-100, date(2026, 10, 5), checking),
            tx(-500, date(2026, 10, 6), savings),
        ]
        let accounts = [checking, savings]

        let context = build(txs, accounts: accounts, now: now)

        #expect(context.periods.currentMonth.expense == 100)
        #expect(context.periods.currentMonth.income == 1000)
        #expect(context.balances.totalBalance == panelTotal(accounts, txs))
        #expect(context.balances.totalBalance == 900)
        #expect(context.balances.accounts.map(\.name) == ["Checking"])
        #expect(context.metadata.excludedAccounts == ["Savings"])
    }

    /// Las cuentas sistema de Grupos que archiva la propia app no son «cuentas» para el conteo del
    /// Panel (`PanelTotalAccountsLogic.countableAccounts`) ni para el chat. Su saldo es 0.
    @Test func groupSystemAccountArchivedByTheApp_isNotListed() {
        let now = date(2026, 10, 15)
        let checking = account("Checking")
        let groups = account("Grupos USD", archived: true, system: true)
        let context = build([tx(1000, date(2026, 10, 1), checking)], accounts: [checking, groups], now: now)

        #expect(context.balances.accounts.map(\.name) == ["Checking"])
        #expect(context.metadata.excludedAccounts.isEmpty)
    }

    // MARK: - 2. El mes pasado hasta el mismo día

    /// El caso de `chat.answer` a mitad de mes que el banco contestaba mal («Yes… less»): lo que va
    /// de octubre (600) contra septiembre ENTERO (1200) parecía «gastas menos»; contra septiembre hasta
    /// el día 15 (500) es «gastas más». El contexto trae las tres cifras con su etiqueta.
    @Test func midMonth_bringsLastMonthToTheSameDay_withItsLabel() throws {
        let now = date(2026, 10, 15, 18)
        let txs = [
            tx(-600, date(2026, 10, 3)),
            tx(-200, date(2026, 9, 1, 0, 0, 0)),     // primer instante del mes pasado: dentro
            tx(-300, date(2026, 9, 15, 23, 59, 59)), // último segundo del día equivalente: dentro
            tx(-250, date(2026, 9, 16, 0, 0, 0)),    // medianoche del día siguiente (DatePicker): FUERA
            tx(-450, date(2026, 9, 28)),
        ]

        let context = build(txs, now: now)

        #expect(context.periods.currentMonth.expense == 600)
        #expect(context.periods.lastMonthToDate.expense == 500)
        #expect(context.periods.lastMonth.expense == 1200)
        #expect(context.periods.lastMonthToDate.txCount == 2)
        // 500 en 15 días: el denominador es el tramo, no el mes entero.
        #expect(context.periods.lastMonthToDate.dailyAvg == 500.0 / 15.0)

        // Lo que ve el modelo: la clave y su valor en el JSON del prompt.
        let json = context.toJSONString()
        let periods = try #require(
            (try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])?["periods"] as? [String: Any]
        )
        let toDate = try #require(periods["last_month_to_date"] as? [String: Any])
        #expect(toDate["expense"] as? Double == 500)
        #expect((periods["last_month"] as? [String: Any])?["expense"] as? Double == 1200)
    }

    @Test func dayOne_bringsTheWholeFirstDayOfLastMonth_andNotTheSecond() {
        let txs = [
            tx(-70, date(2026, 9, 1, 21)),
            tx(-30, date(2026, 9, 2, 0, 0, 0)),
            tx(-5, date(2026, 10, 1, 0, 0, 0)),
        ]

        for now in [date(2026, 10, 1, 0, 0, 0), date(2026, 10, 1, 9)] {
            let context = build(txs, now: now)
            #expect(context.periods.lastMonthToDate.expense == 70, "now=\(now)")
            #expect(context.periods.lastMonth.expense == 100, "now=\(now)")
            #expect(context.periods.currentMonth.expense == 5, "now=\(now)")
        }
    }

    /// Hoy no existe en el mes pasado: el tramo es el mes pasado entero, incluido su último segundo,
    /// y nada del mes en curso.
    @Test(arguments: [
        // (hoy, último día del mes pasado)
        (2026, 10, 31, 30),  // 31 frente a septiembre (30)
        (2026, 3, 29, 28),   // febrero no bisiesto
        (2026, 3, 30, 28),
        (2026, 3, 31, 28),
        (2028, 3, 30, 29),   // febrero bisiesto
        (2026, 12, 31, 30),  // 31 frente a noviembre (30)
    ])
    func todayMissingFromLastMonth_bringsTheWholeLastMonth(_ y: Int, _ m: Int, _ d: Int, _ lastDay: Int) {
        let lastMonth = m - 1
        let txs = [
            tx(-10, date(y, lastMonth, 1)),
            tx(-20, date(y, lastMonth, lastDay, 23, 59, 59)),
            tx(-40, date(y, m, 1, 0, 0, 0)),
        ]

        let context = build(txs, now: date(y, m, d))

        #expect(context.periods.lastMonthToDate.expense == 30)
        #expect(context.periods.lastMonth.expense == 30)
        #expect(context.periods.lastMonthToDate.txCount == 2)
    }

    /// El día equivalente sí existe en febrero bisiesto: el 29 de marzo de 2028 llega hasta el 29 de
    /// febrero; el 28, no.
    @Test func leapFebruary_dayTwentyEight_stopsBeforeTheTwentyNinth() {
        let txs = [
            tx(-10, date(2028, 2, 28, 22)),
            tx(-20, date(2028, 2, 29, 0, 0, 0)),
        ]

        #expect(build(txs, now: date(2028, 3, 28)).periods.lastMonthToDate.expense == 10)
        #expect(build(txs, now: date(2028, 3, 29)).periods.lastMonthToDate.expense == 30)
    }

    /// Las variaciones precalculadas son las que el modelo cita tal cual: tienen que comparar el mes en
    /// curso con el mes pasado hasta el mismo día, en categorías, subcategorías y comercios.
    @Test func precomputedVariations_compareAgainstLastMonthToDate() throws {
        let now = date(2026, 10, 15)
        let restaurants = Subcategory(
            name: "Restaurants", colorHex: nil, natureRawValue: SubcategoryNeed.optional.rawValue,
            iconName: "fork.knife", category: food
        )
        let txs = [
            tx(-150, date(2026, 10, 4), subcategory: restaurants, note: "Tanta"),
            tx(-100, date(2026, 9, 10), subcategory: restaurants, note: "Tanta"),
            tx(-400, date(2026, 9, 25), subcategory: restaurants, note: "Tanta"),
        ]

        let context = build(txs, now: now)

        let category = try #require(context.categories.first { $0.name == "Food" })
        #expect(category.totalCurrentMonth == 150)
        #expect(category.totalLastMonthToDate == 100)
        #expect(category.totalLastMonth == 500)
        #expect(category.variationPercentVsLastMonthToDate == 50)

        let sub = try #require(category.subcategories.first)
        #expect(sub.totalLastMonthToDate == 100)
        #expect(sub.totalLastMonth == 500)
        #expect(sub.variationPercentVsLastMonthToDate == 50)

        let merchant = try #require(context.merchantsTop20.first)
        #expect(merchant.totalLastMonthToDate == 100)
        #expect(merchant.totalLastMonth == 500)
        #expect(merchant.variationPercentVsLastMonthToDate == 50)
    }

    /// Sin gasto en el tramo del mes pasado no hay variación que dar, aunque el mes pasado entero sí
    /// tuviera: un «-60 %» contra el mes entero es justo la respuesta equivocada del banco.
    @Test func noSpendInLastMonthToDate_hasNoVariation_evenIfTheWholeMonthHad() throws {
        let now = date(2026, 10, 10)
        let txs = [
            tx(-200, date(2026, 10, 2), note: "Wong"),
            tx(-500, date(2026, 9, 20), note: "Wong"),
        ]

        let context = build(txs, now: now)

        let category = try #require(context.categories.first)
        #expect(category.totalLastMonthToDate == 0)
        #expect(category.totalLastMonth == 500)
        #expect(category.variationPercentVsLastMonthToDate == nil)
        #expect(context.merchantsTop20.first?.variationPercentVsLastMonthToDate == nil)
    }

    // MARK: - 3. El prompt nombra lo que el contexto trae

    /// El prompt del chat vive en la app (`ChatAssistantService.buildSystemPromptStatic`). Tiene que
    /// nombrar las claves EXACTAS que el contexto serializa y decir que el mes pasado entero no sirve
    /// para comparar el mes en curso. Si alguien renombra una clave, el prompt apuntaría a un campo
    /// que no existe y el modelo volvería a comparar con el mes entero.
    @Test func prompt_namesTheMonthToDateKeys_theContextSerializes() throws {
        let source = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("Yala/Services/ChatAssistantService.swift"),
            encoding: .utf8
        )
        let rule = try #require(source.split(separator: "\n").first { $0.contains("7b. MES EN CURSO:") })

        let keys = [
            FullFinancialContext.PeriodsSection.CodingKeys.lastMonthToDate.rawValue,
            FullFinancialContext.CategoryEntry.CodingKeys.totalLastMonthToDate.rawValue,
            FullFinancialContext.CategoryEntry.CodingKeys.variationPercentVsLastMonthToDate.rawValue,
            FullFinancialContext.PeriodsSection.CodingKeys.lastMonth.rawValue,
            FullFinancialContext.CategoryEntry.CodingKeys.totalLastMonth.rawValue,
        ]
        for key in keys {
            #expect(rule.contains("`\(key)`") || rule.contains("`periods.\(key)`"), "falta \(key)")
        }
        #expect(rule.contains("ENTERO"))
        // Las tres entradas con comparación precalculada usan la MISMA clave que nombra el prompt.
        #expect(FullFinancialContext.SubcategoryEntry.CodingKeys.variationPercentVsLastMonthToDate.rawValue
            == FullFinancialContext.CategoryEntry.CodingKeys.variationPercentVsLastMonthToDate.rawValue)
        #expect(FullFinancialContext.MerchantEntry.CodingKeys.variationPercentVsLastMonthToDate.rawValue
            == FullFinancialContext.CategoryEntry.CodingKeys.variationPercentVsLastMonthToDate.rawValue)
    }
}
