//
//  PanelBalanceFigureCurveParityTests.swift
//  YalaTests
//
//  Ticket `panel-balance-chart-contradicts-its-own-figure`. En el Panel, el widget Saldo decía «+179,062» y
//  dibujaba una curva que acababa en ~201K. Medido el 2026-10-16 con las dos semillas: la brecha era SOLO de
//  divisa. La cifra es el saldo vivo (la cuenta en dólares al tipo de cambio de hoy) y la curva sumaba cada fila
//  al tipo de su fecha: con `ficha-mx-vida`, 15.279 USD valían 279.606 MXN a 18,30 y 282.662 sumados fila a fila;
//  con `realista`, lo mismo en soles. Ninguna fila tenía fecha futura.
//
//  Desde ese día (decisión de Jürgen: «cada día a su tipo de cambio») cada punto vale el saldo NATIVO de ese día
//  por la tasa de ESE día, y el de hoy con la regla del saldo vivo (`BalanceValuation`): la curva acaba en la cifra
//  por construcción. Esta suite lo fija con las dos semillas reales —sus tasas cambian cada día, así que distinguen
//  las tres reglas— en los periodos del selector, por los mismos caminos que recorren el Panel y Estadísticas. El
//  valor esperado de cada punto se calcula aparte, convirtiendo fecha a fecha con `convertChecked`.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

#if DEBUG

@Suite("Panel · Saldo: la cifra y la curva cuentan lo mismo", .serialized)
@MainActor
struct PanelBalanceFigureCurveParityTests {

    private struct Corpus {
        let accounts: [Account]
        let transactions: [TransactionItem]
        let preferred: String
        let converter: CurrencyConverter
    }

    /// Siembra la semilla en el store de test y deja las cuentas que suman y sus filas, como las filtra el Panel
    /// sin filtros puestos (`computeEligibleAccounts` + `balanceTransactions`).
    ///
    /// Con `movingTheRateOf`, sube un 10 % la tasa de la divisa preferida en la fila de ese día. La semilla genera las
    /// tasas con un paseo aleatorio anclado a hoy y redondeado a dos decimales, así que la tasa de un día pasado
    /// coincide a veces con la de hoy, y cuál coincide depende del día del mes en que corre el test (ticket
    /// `panel-balance-curve-parity-test-depends-on-the-clock`). Con la fila movida, ese día no vale lo mismo a su tasa
    /// que a la de hoy, corra cuando corra.
    private func corpus(_ profile: DevSeedProfile, movingTheRateOf day: Date? = nil) async throws -> Corpus {
        let context = try makeTestContext()
        await DevSeedService().seed(in: context, profile: profile)
        let preferred = profile == .fichaMXVida ? "MXN" : "PEN"
        if let day {
            // Las filas van por fecha local de calendario (`DevSeedExchangeRates`), y el converter lee la del día local
            // de cada punto (`BalanceValuation.rateDay`): es la misma clave.
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let key = formatter.string(from: day)
            let row = try #require(
                try context.fetch(FetchDescriptor<ExchangeRate>(predicate: #Predicate { $0.dateKey == key })).first,
                "la semilla \(profile.rawValue) no tiene tasa para \(key)"
            )
            var rates = row.decodedRates()
            let rate = try #require(rates[preferred], "la fila \(key) no trae \(preferred)")
            rates[preferred] = rate * 1.1
            row.rates = try DevSeedExchangeRates.encodeScale8StringFaceBlob(rates)
            try context.save()
        }
        let converter = CurrencyConverter()
        converter.setContext(context)
        let accounts = try context.fetch(FetchDescriptor<Account>()).filter { !$0.excludeFromStatistics }
        let ids = Set(accounts.map(\.persistentModelID))
        let transactions = try context.fetch(FetchDescriptor<TransactionItem>()).filter {
            guard let account = $0.account else { return false }
            return ids.contains(account.persistentModelID)
        }
        // La semilla tiene que ser multimoneda, o este test no distinguiría nada.
        #expect(Set(transactions.map(\.currencyCode)).count >= 2, "la semilla \(profile.rawValue) no mezcla divisas")
        return Corpus(accounts: accounts, transactions: transactions, preferred: preferred, converter: converter)
    }

    private func interval(_ period: DetailPeriod, _ c: Corpus, now: Date = .now) -> DateInterval {
        let base = period.dateInterval(now: now)
        guard period == .allTime, let first = c.transactions.map(\.date).min() else { return base }
        return DateInterval(start: first, end: base.end)
    }

    private func trend(_ period: DetailPeriod, _ c: Corpus, now: Date = .now) -> (
        result: TrendDataProcessor.TrendProcessingResult, figure: LiveBalanceCalculator.LiveAnchorInfo?
    ) {
        let interval = interval(period, c, now: now)
        let override = LiveBalanceCalculator.liveBalanceOverride(
            for: .balance, interval: interval, accounts: c.accounts, transactions: c.transactions,
            preferredCurrencyCode: c.preferred, converter: c.converter
        )
        let result = TrendDataProcessor.processTrendData(
            transactions: c.transactions, accounts: c.accounts, metric: .balance, period: period,
            grouping: period.chartGrouping, interval: interval, currencyCode: c.preferred,
            liveBalanceOverride: override, converter: c.converter
        )
        return (result, override)
    }

    private func close(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 0.01 }

    @Test(arguments: [DevSeedProfile.fichaMXVida, .realista])
    func curveEndsAtTheFigure_inEveryPeriodThatCoversToday(_ profile: DevSeedProfile) async throws {
        let c = try await corpus(profile)
        let saldoVivo = LiveBalanceCalculator.liveBalance(
            accounts: c.accounts, transactions: c.transactions, preferredCurrencyCode: c.preferred,
            converter: c.converter
        )
        for period in [DetailPeriod.thisMonth, .thisWeek, .last30Days, .thisYear, .allTime] {
            let (result, figure) = trend(period, c)
            let figureValue = try #require(figure?.value, "\(period) cubre hoy y tiene que llevar la cifra viva")
            let lastRaw = try #require(result.rawPoints.last?.value)
            let lastDrawn = try #require(result.points.last?.value)
            #expect(close(figureValue, saldoVivo), "\(profile.rawValue) \(period): cifra \(figureValue) ≠ saldo vivo \(saldoVivo)")
            #expect(close(result.finalBalance, figureValue))
            #expect(close(lastRaw, figureValue), "\(profile.rawValue) \(period): la curva acaba en \(lastRaw) y la cifra dice \(figureValue)")
            #expect(close(lastDrawn, figureValue), "\(profile.rawValue) \(period): la línea dibujada acaba en \(lastDrawn)")
        }
    }

    /// El saldo nativo de las filas con fecha ≤ `instant`, valorado aparte con `convertChecked` a mediodía de ese día.
    private func expectedValue(_ c: Corpus, closingAt instant: Date) -> Double {
        var native: [String: Decimal] = [:]
        for tx in c.transactions where tx.date <= instant {
            native[tx.currencyCode, default: 0] += Decimal(tx.amount)
        }
        let noon = BalanceValuation.rateDay(of: instant, calendar: .current)
        var total: Decimal = 0
        for (code, amount) in native {
            total += code == c.preferred
                ? amount
                : amount * c.converter.convertChecked(1, from: code, to: c.preferred, on: noon).amount
        }
        return (total as NSDecimalNumber).doubleValue
    }

    /// Cada punto de «Este mes» y de «Últimos 30 días» que no es hoy vale el saldo de ese día por la tasa de ese día.
    ///
    /// No depende del reloj: lee la hora una vez; «Últimos 30 días» tiene días pasados también los días 1 a 3 del
    /// mes, cuando «Este mes» no llega a tres; y el control final se mide en ayer, con su tasa movida a propósito
    /// (ver `corpus`), en vez de fiarse de que la semilla no repita la tasa de hoy.
    @Test(arguments: [DevSeedProfile.fichaMXVida, .realista])
    func everyPastPoint_isThatDaysBalanceAtThatDaysRate(_ profile: DevSeedProfile) async throws {
        let calendar = Calendar.current
        let now = Date.now
        let startOfToday = calendar.startOfDay(for: now)
        let yesterday = try #require(calendar.date(byAdding: .day, value: -1, to: startOfToday))
        let c = try await corpus(profile, movingTheRateOf: yesterday)
        // El último segundo del día que empieza en `day`: el comienzo del día siguiente, menos uno.
        let endOfDay = { (day: Date) -> Date? in calendar.date(byAdding: .day, value: 1, to: day)?.addingTimeInterval(-1) }
        var yesterdaysPoint: Double?
        for period in [DetailPeriod.thisMonth, .last30Days] {
            let (result, _) = trend(period, c, now: now)
            let past = result.rawPoints.filter { $0.date < startOfToday }
            if period == .last30Days {
                try #require(past.count >= 3, "\(period) tiene que tener días pasados con datos para que esto mida algo")
            }
            var wrong: [String] = []
            for point in past {
                let closing = try #require(endOfDay(point.date))
                let expected = expectedValue(c, closingAt: closing)
                if !close(point.value, expected) { wrong.append("\(point.date): \(point.value) ≠ \(expected)") }
                if period == .last30Days, calendar.isDate(point.date, inSameDayAs: yesterday) { yesterdaysPoint = point.value }
            }
            #expect(wrong.isEmpty, "\(profile.rawValue) \(period): \(wrong.prefix(5))")
        }
        // Y la regla se distingue de «todo al tipo de hoy»: ayer, con su tasa movida, saldría otro número.
        let yesterdayValue = try #require(yesterdaysPoint, "\(profile.rawValue): «Últimos 30 días» no trae el punto de ayer")
        let endOfYesterday = try #require(endOfDay(yesterday))
        let atTodaysRate = LiveBalanceCalculator.liveBalance(
            accounts: c.accounts,
            transactions: c.transactions.filter { $0.date <= endOfYesterday },
            preferredCurrencyCode: c.preferred, converter: c.converter
        )
        #expect(!close(yesterdayValue, atTodaysRate), "\(profile.rawValue): el punto de ayer no distingue la tasa de su día de la de hoy")
    }

    /// Un periodo cerrado no lleva cifra viva: la cifra es el último punto, y vale el saldo al CIERRE del periodo con
    /// la tasa del cierre (no la de su último movimiento ni la de hoy).
    @Test(arguments: [DevSeedProfile.fichaMXVida, .realista])
    func closedPeriod_figureIsTheBalanceAtTheClose(_ profile: DevSeedProfile) async throws {
        let c = try await corpus(profile)
        let (result, figure) = trend(.lastMonth, c)
        #expect(figure == nil)
        let lastRaw = try #require(result.rawPoints.last?.value)
        #expect(close(result.finalBalance, lastRaw))
        let end = DetailPeriod.lastMonth.dateInterval().end
        let expected = expectedValue(c, closingAt: end)
        #expect(close(lastRaw, expected), "\(profile.rawValue) mes pasado: curva \(lastRaw), saldo al cierre \(expected)")
        let kpi = BalanceKPICalculator.value(
            transactions: c.transactions, accounts: c.accounts, interval: DetailPeriod.lastMonth.dateInterval(),
            period: .lastMonth, currencyCode: c.preferred, converter: c.converter
        )
        #expect(close(kpi, expected), "\(profile.rawValue): el hero de Estadísticas › Mes pasado \(kpi) ≠ \(expected)")
    }

    /// El rendimiento: la curva de «Todo el tiempo» lee las tasas de cada día en bloque. Con `realista` son dos años de
    /// días; medido para que una regresión a una consulta por día se vea.
    @Test func allTime_curve_staysFast() async throws {
        let c = try await corpus(.realista)
        let clock = ContinuousClock()
        let elapsed = clock.measure { _ = trend(.allTime, c) }
        // Medido el 2026-10-16: 37 ms en el simulador. Una consulta por día lo multiplicaría.
        #expect(elapsed < .milliseconds(300), "la curva de Todo el tiempo tardó \(elapsed)")
        print("PERF allTime realista: \(elapsed)")
    }

    /// La vista por cuenta de Estadísticas › Tendencias suma lo mismo que la agregada: es lo que el usuario
    /// compara al cambiar de vista, y la cuenta en dólares es justo la que se separaba.
    @Test(arguments: [DevSeedProfile.fichaMXVida, .realista])
    func perAccountCurves_addUpToTheAggregatedOne(_ profile: DevSeedProfile) async throws {
        let c = try await corpus(profile)
        let interval = interval(.thisMonth, c)
        let calendar = Calendar.current
        var days: [Date] = []
        var day = calendar.startOfDay(for: interval.start)
        while day < interval.end {
            days.append(day)
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        var sum = 0.0
        for account in c.accounts {
            let txs = c.transactions.filter { $0.account?.persistentModelID == account.persistentModelID }
            let buckets = StatisticsViewModel.accountBuckets(
                metric: .balance, accountTransactions: txs, bucketDates: days, intervalStart: interval.start,
                grouping: .day, calendar: calendar, currencyCode: c.preferred, adjustment: .none,
                converter: c.converter
            )
            sum += buckets.max { $0.key < $1.key }?.value ?? 0
        }
        let (result, _) = trend(.thisMonth, c)
        let aggregated = try #require(result.rawPoints.last?.value)
        #expect(close(sum, aggregated), "\(profile.rawValue): por cuenta \(sum) ≠ agregada \(aggregated)")
    }
}

#endif
