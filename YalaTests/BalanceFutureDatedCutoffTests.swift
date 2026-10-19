//
//  BalanceFutureDatedCutoffTests.swift
//  YalaTests
//
//  El saldo de hoy deja fuera los movimientos con fecha futura hasta que llega su fecha (decisión A de Jürgen,
//  2026-10-18, ticket `balance-figure-counts-future-dated-rows-the-curve-never-draws`). Antes la cifra los sumaba y
//  la curva, que acaba hoy, no: el Panel decía una cosa y dibujaba otra.
//
//  Cada caso lleva un movimiento de MAÑANA: sin el corte, el número que se mira sale con él dentro.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
struct BalanceFutureDatedCutoffTests {

    // MARK: - Fixtures

    private let calendar = userConfiguredCalendar()
    /// «Ahora» fijo a media tarde de hoy, leído UNA vez: hoy, mañana y la medianoche no se mueven a mitad de un caso.
    /// Es hoy y no una fecha fija porque la valoración de la curva (`BalanceValuation`) topa en `Date.now`.
    private let now: Date = {
        let cal = userConfiguredCalendar()
        return cal.date(bySettingHour: 15, minute: 0, second: 0, of: Date()) ?? Date()
    }()
    private var startOfToday: Date { calendar.startOfDay(for: now) }
    private var startOfTomorrow: Date { calendar.date(byAdding: .day, value: 1, to: startOfToday)! }

    private func account(_ code: String = "PEN") -> Account {
        Account(name: "Cuenta", currencyCode: code, colorHex: "#6366F1", iconName: "creditcard", type: "bank")
    }

    private func tx(_ amount: Double, _ date: Date, _ account: Account, preferred: Double? = nil) -> TransactionItem {
        TransactionItem(
            date: date, amount: amount, currencyCode: account.currencyCode, account: account,
            amountInPreferredCurrency: preferred ?? amount, preferredCurrencyCode: "PEN"
        )
    }

    // MARK: - El corte

    /// El borde es el inicio de mañana: el último segundo de hoy cuenta, la medianoche de mañana no.
    @Test func cutoff_endsAtTheStartOfTomorrow() {
        let cutoff = LiveBalanceCalculator.TodayCutoff(asOf: now, calendar: calendar)
        #expect(cutoff.counts(startOfToday))
        #expect(cutoff.counts(startOfTomorrow.addingTimeInterval(-1)))
        #expect(!cutoff.counts(startOfTomorrow))
        #expect(!cutoff.counts(startOfTomorrow.addingTimeInterval(86_400 * 5)))
    }

    /// Un gasto de hoy a las 23:00 cuenta aunque «ahora» sean las 15:00: el corte es por día, no por instante.
    @Test func cutoff_isByDay_notByInstant() {
        let cutoff = LiveBalanceCalculator.TodayCutoff(asOf: now, calendar: calendar)
        let tonight = calendar.date(bySettingHour: 23, minute: 0, second: 0, of: now)!
        #expect(cutoff.counts(tonight))
    }

    // MARK: - Saldo vivo (Panel, «¿Cuánto tienes hoy?», widget)

    @Test func liveBalance_leavesOutTomorrowsMovement() {
        let acc = account()
        let rows = [tx(1000, startOfToday, acc), tx(-200, startOfTomorrow, acc)]
        let balance = LiveBalanceCalculator.liveBalance(
            accounts: [acc], transactions: rows, preferredCurrencyCode: "PEN", asOf: now,
            converter: MockCurrencyConverter()
        )
        #expect(balance == 1000)
    }

    /// Cuando llega su fecha, entra: el mismo movimiento, mirado mañana.
    @Test func liveBalance_countsItOnceItsDayArrives() {
        let acc = account()
        let rows = [tx(1000, startOfToday, acc), tx(-200, startOfTomorrow, acc)]
        let tomorrowAfternoon = startOfTomorrow.addingTimeInterval(15 * 3600)
        let balance = LiveBalanceCalculator.liveBalance(
            accounts: [acc], transactions: rows, preferredCurrencyCode: "PEN", asOf: tomorrowAfternoon,
            converter: MockCurrencyConverter()
        )
        #expect(balance == 800)
    }

    /// La hoja «¿Cuánto tienes hoy?» y el punto de hoy de la curva salen de `liveBalanceOverride`.
    @Test func liveAnchor_leavesOutTomorrowsMovement_inEveryCurrency() throws {
        let pen = account("PEN")
        let usd = account("USD")
        let rows = [
            tx(1000, startOfToday, pen),
            tx(100, startOfToday, usd, preferred: 380),
            tx(-50, startOfTomorrow, usd, preferred: -190),
        ]
        var converter = MockCurrencyConverter()
        converter.fixedRate = 4
        let anchor = try #require(
            LiveBalanceCalculator.liveBalanceOverride(
                for: .balance, interval: DateInterval(start: startOfToday, end: startOfTomorrow),
                accounts: [pen, usd], transactions: rows, preferredCurrencyCode: "PEN", asOf: now,
                converter: converter
            )
        )
        #expect(anchor.value == 1400)
        #expect(anchor.nativeBalances["USD"] == 100)
    }

    // MARK: - P&L cambiario: recorre las mismas filas que el saldo

    /// Sin el corte en el P&L, el gasto de mañana consumía lotes que el saldo no restaba, los lotes vivos dejaban de
    /// cuadrar con el saldo en dólares y la divisa desaparecía de la tarjeta en silencio.
    @Test func fxPnL_keepsTheCurrency_withAFutureMovement() throws {
        let usd = account("USD")
        let rows = [tx(1000, startOfToday, usd, preferred: 3500), tx(-400, startOfTomorrow, usd, preferred: -1400)]
        var converter = MockCurrencyConverter()
        converter.fixedRate = Decimal(string: "3.8")!
        let breakdown = LiveBalanceCalculator.liveBalanceBreakdown(
            accounts: [usd], transactions: rows, preferredCurrencyCode: "PEN", asOf: now, converter: converter
        )
        #expect(breakdown.nativeBalances["USD"] == 1000)
        let summary = try #require(FXPnLLogic.summary(transactions: rows, breakdown: breakdown, converter: converter))
        let row = try #require(summary.rows.first)
        #expect(row.nativeBalance == 1000)
        #expect(abs(row.averageEntryRate - Decimal(string: "3.5")!) < Decimal(string: "0.0001")!)
    }

    // MARK: - Saldo por cuenta (tarjetas, detalle, lista, formulario, widget)

    @Test func accountBalance_leavesOutTomorrowsMovement() {
        let acc = account()
        let rows = [tx(1000, startOfToday, acc), tx(-200, startOfTomorrow, acc)]
        #expect(AccountBalanceCalculator.currentBalance(for: acc, allTransactions: rows, asOf: now) == 1000)
        let batch = AccountBalanceCalculator.batchCalculateBalances(accounts: [acc], transactions: rows, asOf: now)
        #expect(batch[acc.persistentModelID] == 1000)
    }

    /// El formulario corrige contra el saldo de hoy: el saldo de partida no se desplaza por un movimiento de mañana.
    /// Sin el corte en `existingInitialBalance`, el gasto futuro restaba ahí sin haber sumado en `currentBalance`.
    @Test func accountForm_initialBalance_ignoresTomorrowsMovement() {
        let acc = account()
        let initial = tx(1000, calendar.date(byAdding: .day, value: -30, to: startOfToday)!, acc)
        initial.balanceAdjustmentType = InitialBalanceService.typeInitialBalance
        let rows = [initial, tx(-100, startOfToday, acc), tx(-200, startOfTomorrow, acc)]
        let form = AccountFormViewModel(accountToEdit: acc, existingNames: [], allTransactions: rows)
        #expect(form.currentBalance == 900)
        #expect(form.existingInitialBalance == 1000)
    }

    // MARK: - Curva por cuenta de Estadísticas

    /// Antes el bucle de días incluía mañana y el movimiento de mañana salía como un punto por encima del saldo.
    @Test func perAccountCurve_endsTodayAtTheBalance() {
        let acc = account()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday)!
        let rows = [tx(1000, yesterday, acc), tx(-100, startOfToday, acc), tx(-300, startOfTomorrow, acc)]
        let buckets = StatisticsViewModel.accountBuckets(
            metric: .balance,
            accountTransactions: rows,
            bucketDates: [yesterday, startOfToday, startOfTomorrow],
            intervalStart: yesterday,
            grouping: .day,
            calendar: calendar,
            currencyCode: "PEN",
            adjustment: .none,
            asOf: now,
            converter: MockCurrencyConverter()
        )
        #expect(buckets[startOfTomorrow] == nil)
        #expect(buckets[startOfToday] == 900)
        #expect(buckets[yesterday] == 1000)
    }

    /// Con agrupación por mes, el movimiento de mañana cae en el mismo bucket que hoy (salvo el último día del mes):
    /// ahí solo lo deja fuera el filtro de movimientos, no el de buckets.
    @Test func perAccountCurve_byMonth_leavesOutTomorrowsMovement() throws {
        guard calendar.isDate(startOfTomorrow, equalTo: startOfToday, toGranularity: .month) else { return }
        let acc = account()
        let monthStart = try #require(calendar.date(from: calendar.dateComponents([.year, .month], from: now)))
        let rows = [tx(1000, startOfToday, acc), tx(-300, startOfTomorrow, acc)]
        let buckets = StatisticsViewModel.accountBuckets(
            metric: .balance, accountTransactions: rows, bucketDates: [monthStart], intervalStart: monthStart,
            grouping: .month, calendar: calendar, currencyCode: "PEN", adjustment: .none, asOf: now,
            converter: MockCurrencyConverter()
        )
        #expect(buckets[monthStart] == 1000)
    }

    // MARK: - Widget de inicio: cifra, curva y saldo del período cuadran

    /// La cifra del widget, el punto de hoy de su curva y el saldo de «este mes» dejan fuera lo de mañana; el punto de
    /// ayer sigue siendo el saldo de ayer.
    @Test func widget_figureCurveAndPeriodBalance_agree() throws {
        let acc = account()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday)!
        let rows = [tx(1000, yesterday, acc), tx(-100, startOfToday, acc), tx(-300, startOfTomorrow, acc)]
        let total = LiveBalanceCalculator.liveBalance(
            accounts: [acc], transactions: rows, preferredCurrencyCode: "PEN", converter: MockCurrencyConverter()
        )
        #expect(total == 900)
        let trend = WidgetDataCache.buildTrendData(
            transactions: rows, totalBalance: total, currencyCode: "PEN", converter: MockCurrencyConverter()
        )
        let points = trend.dailyPoints
        #expect(points.last?.balance == 900)
        #expect(points.dropLast().last?.balance == 1000)
        let summary = WidgetDataCache.buildPeriodSummary(
            transactions: rows, periodStart: yesterday, periodEnd: startOfTomorrow, currencyCode: "PEN",
            allTransactionsForBalance: rows, converter: MockCurrencyConverter()
        )
        #expect(summary.periodBalance == 900)
    }

    // MARK: - Widget: la foto se rehace al cambiar de día

    @Test func widgetPhoto_isRebuilt_onlyWhenItIsFromAnotherDay() {
        let cal = Calendar.current
        #expect(!WidgetDataCache.needsDayRefresh(lastBuiltAt: nil, now: now, calendar: cal))
        #expect(!WidgetDataCache.needsDayRefresh(lastBuiltAt: startOfToday, now: now, calendar: cal))
        #expect(WidgetDataCache.needsDayRefresh(lastBuiltAt: startOfToday.addingTimeInterval(-1), now: now, calendar: cal))
    }

    /// El cableado que ningún caso de lógica ve: la foto apunta cuándo se hizo detrás de la puerta del borrado, y la
    /// vuelta a primer plano y el cambio de día la rehacen.
    @Test func widgetDayRefresh_isWired() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let cache = try String(contentsOf: root.appendingPathComponent("Yala/Services/WidgetDataCache.swift"), encoding: .utf8)
        let boot = try String(contentsOf: root.appendingPathComponent("Yala/App/AppBootstrapper.swift"), encoding: .utf8)
        let update = try #require(cache.range(of: "static func updateCache(context: ModelContext) {"))
        let body = String(cache[update.upperBound...].prefix(600))
        let gate = try #require(body.range(of: "guard !isWipeArmed else"))
        let stamp = try #require(body.range(of: "lastBuiltAt = Date.now"))
        #expect(gate.upperBound < stamp.lowerBound)
        let active = try #require(boot.range(of: "func handleBecameActive(context: ModelContext) {"))
        #expect(boot[active.upperBound...].prefix(2500).contains("WidgetDataCache.refreshIfBuiltOnAnotherDay(context: context)"))
        #expect(boot.contains("forName: .NSCalendarDayChanged"))
        #expect(boot.contains("observeDayChangeForWidgets()"))
    }
}
