//
//  TrendsPreferredCurrencyTests.swift
//  YalaTests
//
//  Ticket `trends-aggregators-sum-stored-amounts-from-other-preferred-currencies`: tras el PR #438 la
//  vista agregada de Tendencias reconvertía las filas guardadas con otra divisa principal, pero las
//  curvas por cuenta, el histórico y las curvas de saldo seguían sumando su
//  `amountInPreferredCurrency` tal cual. Al pasar de una vista a otra, el mismo período daba otro número.
//
//  Todas resuelven ahora cada fila con `CashFlowCalculator.resolvedAmount`. Cada superficie lleva las
//  dos direcciones, como `StatsAggregatorsPreferredCurrencyTests`:
//  - **mezcla**: una fila en soles y otra guardada cuando la principal era USD ⇒ la de USD se
//    reconvierte;
//  - **una sola divisa**: todo guardado en la principal ⇒ el converter no interviene (tasa absurda).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Tendencias por cuenta, histórico y saldos · divisas principales mezcladas", .serialized)
struct TrendsPreferredCurrencyTests {

    /// 1 USD = 3,7 PEN en el doble.
    private let tasaUSD: Decimal = 3.7
    /// Tasa que ninguna fila debería usar en el caso de una sola divisa.
    private let tasaAbsurda: Decimal = 1_000

    private let calendar = Calendar.current

    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: 12)) ?? Date()
    }

    /// Abril de 2026: un período CERRADO (no cubre hoy), así que el saldo sale de la curva y no del
    /// saldo vivo.
    private var abril: DateInterval {
        let startOfApril = calendar.startOfDay(for: day(2026, 4, 1))
        let end = calendar.date(byAdding: DateComponents(month: 1, second: -1), to: startOfApril) ?? startOfApril
        return DateInterval(start: startOfApril, end: end)
    }

    /// Los días de abril, como los arma `calculatePerAccountTrend` con agrupación por día.
    private var diasDeAbril: [Date] {
        (0..<30).compactMap { calendar.date(byAdding: .day, value: $0, to: abril.start) }
    }

    private let cuenta = Account(
        name: "Principal", currencyCode: "PEN", colorHex: "#000000", iconName: "creditcard", type: "bank"
    )
    private let comida = YalaCategory(name: "Comida", colorHex: "#FF0000", isIncome: false)
    private let sueldo = YalaCategory(name: "Sueldo", colorHex: "#00FF00", isIncome: true)

    private func tx(
        nativo: Double, divisa: String, guardado: Double, guardadaEn: String,
        category: YalaCategory, date: Date
    ) -> TransactionItem {
        TransactionItem(
            date: date, amount: nativo, currencyCode: divisa, note: "",
            category: category, account: cuenta,
            amountInPreferredCurrency: guardado, preferredCurrencyCode: guardadaEn
        )
    }

    /// Principal PEN: un gasto y un ingreso en soles, y otro par guardado cuando la principal era USD
    /// y sin recalcular. Gasto: 100 + 50 × 3,7 = 285 (el viejo: 150). Ingreso: 1.000 + 200 × 3,7 =
    /// 1.740 (el viejo: 1.200). Saldo: 1.740 − 285 = 1.455 (el viejo: 1.050).
    private func mezcla(_ date: Date) -> [TransactionItem] {
        [
            tx(nativo: -100, divisa: "PEN", guardado: -100, guardadaEn: "PEN", category: comida, date: date),
            tx(nativo: 1_000, divisa: "PEN", guardado: 1_000, guardadaEn: "PEN", category: sueldo, date: date),
            tx(nativo: -50, divisa: "USD", guardado: -50, guardadaEn: "USD", category: comida, date: date),
            tx(nativo: 200, divisa: "USD", guardado: 200, guardadaEn: "USD", category: sueldo, date: date),
        ]
    }

    /// Las mismas filas de USD, ya recalculadas a soles.
    private func unaSolaDivisa(_ date: Date) -> [TransactionItem] {
        [
            tx(nativo: -100, divisa: "PEN", guardado: -100, guardadaEn: "PEN", category: comida, date: date),
            tx(nativo: 1_000, divisa: "PEN", guardado: 1_000, guardadaEn: "PEN", category: sueldo, date: date),
            tx(nativo: -50, divisa: "USD", guardado: -185, guardadaEn: "PEN", category: comida, date: date),
            tx(nativo: 200, divisa: "USD", guardado: 740, guardadaEn: "PEN", category: sueldo, date: date),
        ]
    }

    /// Un juego en marzo (ANTES del período: entra al saldo de arranque) y otro en abril (dentro).
    /// Cubre las dos ramas del saldo acumulado. Saldo correcto: 2 × 1.455 = 2.910 (el viejo: 2.100).
    private func marzoYAbril(_ filas: (Date) -> [TransactionItem]) -> [TransactionItem] {
        filas(day(2026, 3, 10)) + filas(day(2026, 4, 10))
    }

    private func cerca(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 0.001 }

    // MARK: - Curva de saldo agregada (Tendencias, comparativa y tarjeta del Panel)

    private func saldoAgregado(_ txs: [TransactionItem], tasa: Decimal) -> TrendDataProcessor.TrendProcessingResult {
        TrendDataProcessor.processTrendData(
            transactions: txs, accounts: [cuenta], metric: .balance, period: .lastMonth,
            grouping: .day, interval: abril, currencyCode: "PEN",
            converter: MockCurrencyConverter(fixedRate: tasa)
        )
    }

    @Test("Saldo agregado: la curva reconvierte las filas guardadas en otra divisa, antes y dentro del período")
    func balanceCurve_mixedPreferredCurrencies_convertsBeforeAccumulating() throws {
        let r = saldoAgregado(marzoYAbril(mezcla), tasa: tasaUSD)
        let fin = try #require(r.rawPoints.last?.value)
        #expect(cerca(fin, 2_910), "saldo al cierre: \(fin)")
        #expect(cerca(r.finalBalance, 2_910), "finalBalance: \(r.finalBalance)")
    }

    @Test("Saldo agregado: con todo en la principal, la curva lee el monto guardado")
    func balanceCurve_singlePreferredCurrency_readsStoredAmounts() throws {
        let r = saldoAgregado(marzoYAbril(unaSolaDivisa), tasa: tasaAbsurda)
        let fin = try #require(r.rawPoints.last?.value)
        #expect(cerca(fin, 2_910), "saldo al cierre: \(fin)")
    }

    // MARK: - KPI de saldo de un período cerrado

    /// El KPI de período cerrado es el último punto de esa curva; tiene que reconvertir con el
    /// converter que recibe, no con el compartido.
    @Test("KPI de saldo (período cerrado): reconvierte con el converter que recibe")
    func balanceKPI_closedPeriod_mixedPreferredCurrencies_converts() {
        let r = BalanceKPICalculator.result(
            transactions: marzoYAbril(mezcla), accounts: [cuenta], interval: abril, period: .lastMonth,
            currencyCode: "PEN", converter: MockCurrencyConverter(fixedRate: tasaUSD)
        )
        #expect(r.hasDataInPeriod)
        #expect(cerca(r.value, 2_910), "KPI de saldo: \(r.value)")
    }

    // MARK: - Curvas por cuenta (Estadísticas › Tendencias, vista por cuenta)

    private func porCuenta(
        _ metrica: TrendMetric, _ txs: [TransactionItem], tasa: Decimal
    ) -> [Date: Double] {
        StatisticsViewModel.accountBuckets(
            metric: metrica, accountTransactions: txs, bucketDates: diasDeAbril,
            intervalStart: abril.start, grouping: .day, calendar: calendar,
            currencyCode: "PEN", adjustment: .none, converter: MockCurrencyConverter(fixedRate: tasa)
        )
    }

    private func ultimo(_ buckets: [Date: Double]) -> Double? {
        buckets.max { $0.key < $1.key }?.value
    }

    private func suma(_ buckets: [Date: Double]) -> Double {
        buckets.values.reduce(0, +)
    }

    @Test("Por cuenta: ingreso, gasto y saldo reconvierten las filas guardadas en otra divisa")
    func accountCurves_mixedPreferredCurrencies_convertBeforeSumming() throws {
        let ingreso = porCuenta(.income, mezcla(day(2026, 4, 10)), tasa: tasaUSD)
        #expect(cerca(suma(ingreso), 1_740), "ingreso: \(suma(ingreso))")
        let gasto = porCuenta(.expense, mezcla(day(2026, 4, 10)), tasa: tasaUSD)
        #expect(cerca(suma(gasto), 285), "gasto: \(suma(gasto))")
        let saldo = try #require(ultimo(porCuenta(.balance, marzoYAbril(mezcla), tasa: tasaUSD)))
        #expect(cerca(saldo, 2_910), "saldo al cierre: \(saldo)")
    }

    @Test("Por cuenta: con todo en la principal, leen el monto guardado")
    func accountCurves_singlePreferredCurrency_readStoredAmounts() throws {
        let ingreso = porCuenta(.income, unaSolaDivisa(day(2026, 4, 10)), tasa: tasaAbsurda)
        #expect(cerca(suma(ingreso), 1_740), "ingreso: \(suma(ingreso))")
        let gasto = porCuenta(.expense, unaSolaDivisa(day(2026, 4, 10)), tasa: tasaAbsurda)
        #expect(cerca(suma(gasto), 285), "gasto: \(suma(gasto))")
        let saldo = try #require(ultimo(porCuenta(.balance, marzoYAbril(unaSolaDivisa), tasa: tasaAbsurda)))
        #expect(cerca(saldo, 2_910), "saldo al cierre: \(saldo)")
    }

    /// La vista por cuenta y la agregada, sobre las mismas filas de una sola cuenta, dan el mismo
    /// número: es lo que el usuario compara al cambiar de vista.
    @Test("Por cuenta y agregada coinciden con divisas mezcladas")
    func accountCurves_matchAggregatedView() throws {
        let agregada = saldoAgregado(marzoYAbril(mezcla), tasa: tasaUSD)
        let porCuentaFin = try #require(ultimo(porCuenta(.balance, marzoYAbril(mezcla), tasa: tasaUSD)))
        #expect(cerca(porCuentaFin, agregada.finalBalance), "por cuenta \(porCuentaFin) ≠ agregada \(agregada.finalBalance)")
    }

    // MARK: - Histórico (tarjeta de observaciones de Tendencias)

    private func historico(_ txs: [TransactionItem], tasa: Decimal) -> (income: Double, expense: Double) {
        let entries = StatisticsViewModel.historyEntries(
            filtered: txs, currencyCode: "PEN", adjustment: .none,
            converter: MockCurrencyConverter(fixedRate: tasa)
        )
        return entries.reduce(into: (income: 0.0, expense: 0.0)) { acc, e in
            if e.isIncome { acc.income += e.amount } else { acc.expense += e.amount }
        }
    }

    @Test("Histórico: reconvierte las filas guardadas en otra divisa, como el total del período")
    func history_mixedPreferredCurrencies_convertsBeforeSumming() {
        let h = historico(mezcla(day(2026, 4, 10)), tasa: tasaUSD)
        #expect(cerca(h.income, 1_740), "ingreso: \(h.income)")
        #expect(cerca(h.expense, 285), "gasto: \(h.expense)")
        let kpi = StatisticsViewModel.periodTotals(
            filtered: mezcla(day(2026, 4, 10)), currencyCode: "PEN", adjustment: .none,
            converter: MockCurrencyConverter(fixedRate: tasaUSD)
        )
        #expect(cerca(h.income, kpi.income) && cerca(h.expense, kpi.expense))
    }

    @Test("Histórico: con todo en la principal, lee el monto guardado")
    func history_singlePreferredCurrency_readsStoredAmounts() {
        let h = historico(unaSolaDivisa(day(2026, 4, 10)), tasa: tasaAbsurda)
        #expect(cerca(h.income, 1_740), "ingreso: \(h.income)")
        #expect(cerca(h.expense, 285), "gasto: \(h.expense)")
    }
}
