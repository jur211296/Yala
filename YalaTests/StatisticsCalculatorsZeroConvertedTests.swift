//
//  StatisticsCalculatorsZeroConvertedTests.swift
//  YalaTests
//
//  Card `tablero-las-tartas-y-rankings-de-estadisticas-si-985z`, hallazgo de #461. Siete calculadores
//  suman el `amountInPreferredCurrency` guardado por su cuenta, sin pasar por
//  `CashFlowCalculator.resolvedAmount`, y su rama «misma divisa» comparaba solo la divisa: un
//  movimiento con la conversión SIN ESCRIBIR (0 con nativo distinto de 0) contaba **0**. La tarta de
//  categorías sumaba menos que el total de su misma pantalla.
//
//  Ahora preguntan `CashFlowCalculator.readsStoredAmount`, la condición de la primera rama de
//  `resolvedAmount`, y ese cero se reconvierte desde el nativo con la tasa de su día.
//
//  Escena (la de `ResolvedAmountZeroConvertedTests`; principal PEN, 1 USD = 3,7 en el doble): un gasto
//  de S/ 100 ya en soles y uno de 50 USD con el convertido a 0.
//  - Correcto: 100 + 185 = **285**.
//  - Con el bug: **100**.
//  Cada calculador lleva su control: las mismas filas con el convertido escrito (−185) dan lo mismo
//  con una tasa ABSURDA, así que el converter no se consulta cuando el guardado vale; y un movimiento
//  de una sola divisa no cambia.
//
//  Sin `ModelContext`: los `@Model` sueltos bastan, como en #461.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Calculadores de Estadísticas con el convertido a 0 · se reconvierte", .serialized)
struct StatisticsCalculatorsZeroConvertedTests {

    private let tasaUSD: Decimal = 3.7
    private let tasaAbsurda: Decimal = 1_000
    private let calendar = Calendar.current

    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: 12)) ?? Date()
    }

    private var abril: DateInterval {
        let start = calendar.startOfDay(for: day(2026, 4, 1))
        let end = calendar.date(byAdding: DateComponents(month: 1, second: -1), to: start) ?? start
        return DateInterval(start: start, end: end)
    }

    /// Viernes 10 de abril de 2026: las dos filas caen el mismo día de la semana.
    private var fecha: Date { day(2026, 4, 10) }

    private let cuenta = Account(
        name: "Principal", currencyCode: "PEN", colorHex: "#000000", iconName: "creditcard", type: "bank"
    )
    private let comida = YalaCategory(name: "Comida", colorHex: "#FF0000", isIncome: false)
    private let sueldo = YalaCategory(name: "Sueldo", colorHex: "#00FF00", isIncome: true)

    private func tx(
        nativo: Double, divisa: String, guardado: Double, category: YalaCategory? = nil, note: String = ""
    ) -> TransactionItem {
        TransactionItem(
            date: fecha, amount: nativo, currencyCode: divisa, note: note,
            category: category ?? comida, account: cuenta,
            amountInPreferredCurrency: guardado, preferredCurrencyCode: "PEN"
        )
    }

    /// El gasto en USD con el convertido sin escribir, junto a uno en soles.
    private func sinConvertir() -> [TransactionItem] {
        [
            tx(nativo: -100, divisa: "PEN", guardado: -100, note: "Mercado"),
            tx(nativo: -50, divisa: "USD", guardado: 0, note: "Hotel"),
        ]
    }

    /// Las mismas filas con el convertido escrito.
    private func convertidas() -> [TransactionItem] {
        [
            tx(nativo: -100, divisa: "PEN", guardado: -100, note: "Mercado"),
            tx(nativo: -50, divisa: "USD", guardado: -185, note: "Hotel"),
        ]
    }

    /// Una sola divisa: nada que convertir. Fija el contrato «una sola divisa no cambia», pero NO es
    /// una red: el doble devuelve el importe tal cual entre divisas iguales, así que estas filas dan lo
    /// mismo se lean o se reconviertan. La red contra reconvertir de más es `convertidas()` con la tasa
    /// absurda (lo cazó la review del 2026-10-12).
    private func monodivisa() -> [TransactionItem] {
        [
            tx(nativo: -100, divisa: "PEN", guardado: -100, note: "Mercado"),
            tx(nativo: -40, divisa: "PEN", guardado: -40, note: "Taxi"),
        ]
    }

    private func cerca(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 0.001 }

    private func conversor(_ tasa: Decimal) -> MockCurrencyConverter {
        MockCurrencyConverter(fixedRate: tasa)
    }

    // MARK: - La regla compartida

    @Test("readsStoredAmount: el 0 sin escribir no se lee; el escrito y el de otra divisa, según toca")
    func readsStoredAmount_table() {
        let pen = "PEN"
        #expect(!CashFlowCalculator.readsStoredAmount(
            tx(nativo: -50, divisa: "USD", guardado: 0), currencyCode: pen, adjustment: .none
        ), "convertido sin escribir: se reconvierte")
        #expect(CashFlowCalculator.readsStoredAmount(
            tx(nativo: -50, divisa: "USD", guardado: -185), currencyCode: pen, adjustment: .none
        ), "convertido escrito: se lee")
        #expect(CashFlowCalculator.readsStoredAmount(
            tx(nativo: 0, divisa: "USD", guardado: 0), currencyCode: pen, adjustment: .none
        ), "un importe de 0 de verdad se lee")
        #expect(!CashFlowCalculator.readsStoredAmount(
            tx(nativo: -50, divisa: "USD", guardado: -185), currencyCode: "EUR", adjustment: .none
        ), "guardado en otra divisa preferida: se reconvierte")
    }

    // MARK: - Tarta de categorías

    private func tarta(_ txs: [TransactionItem], _ tasa: Decimal) -> Double {
        TopSpendingCategoriesCalculator.calculateTopSpending(
            transactions: txs, interval: abril, currencyCode: "PEN", converter: conversor(tasa)
        ).first(where: { $0.category === comida })?.amount ?? 0
    }

    @Test("Tarta de categorías: el gasto con el convertido a 0 cuenta reconvertido")
    func topSpending_zeroConverted_reconverts() {
        let total = tarta(sinConvertir(), tasaUSD)
        #expect(cerca(total, 285), "con el bug: 100 (\(total))")
    }

    @Test("Control de la tarta: convertido escrito sin consultar la tasa; una sola divisa no cambia")
    func topSpending_controls() {
        #expect(cerca(tarta(convertidas(), tasaAbsurda), 285))
        #expect(cerca(tarta(monodivisa(), tasaAbsurda), 140))
    }

    // MARK: - Ranking de subcategorías

    private func subcategorias(_ txs: [TransactionItem], _ tasa: Decimal) -> Double {
        TopSubcategoriesCalculator.calculateTopSubcategories(
            transactions: txs, interval: abril, currencyCode: "PEN", converter: conversor(tasa)
        ).reduce(0) { $0 + $1.amount }
    }

    @Test("Ranking de subcategorías: el gasto con el convertido a 0 cuenta reconvertido")
    func topSubcategories_zeroConverted_reconverts() {
        let total = subcategorias(sinConvertir(), tasaUSD)
        #expect(cerca(total, 285), "con el bug: 100 (\(total))")
    }

    @Test("Control del ranking: convertido escrito sin consultar la tasa; una sola divisa no cambia")
    func topSubcategories_controls() {
        #expect(cerca(subcategorias(convertidas(), tasaAbsurda), 285))
        #expect(cerca(subcategorias(monodivisa(), tasaAbsurda), 140))
    }

    // MARK: - Día de la semana

    private func porDia(_ txs: [TransactionItem], _ tasa: Decimal) -> Double {
        let weekday = calendar.component(.weekday, from: fecha)
        return WeekdaySpendingCalculator.calculate(
            transactions: txs, interval: abril, currencyCode: "PEN", converter: conversor(tasa)
        ).first(where: { $0.weekday == weekday })?.total ?? 0
    }

    @Test("Día de la semana: el gasto con el convertido a 0 cuenta reconvertido")
    func weekday_zeroConverted_reconverts() {
        let total = porDia(sinConvertir(), tasaUSD)
        #expect(cerca(total, 285), "con el bug: 100 (\(total))")
    }

    @Test("Control del día de la semana: convertido escrito sin consultar la tasa; una sola divisa no cambia")
    func weekday_controls() {
        #expect(cerca(porDia(convertidas(), tasaAbsurda), 285))
        #expect(cerca(porDia(monodivisa(), tasaAbsurda), 140))
    }

    // MARK: - Real del Flujo de caja

    private func realDelMes(_ txs: [TransactionItem], _ tasa: Decimal) -> Double {
        let index = TransactionIndex(
            transactions: txs, currencyCode: "PEN", converter: conversor(tasa), calendar: calendar
        )
        let key = CashFlowProjectionCalculator.monthKey(for: fecha, calendar: calendar)
        return index.total(for: comida.persistentModelID, monthKey: key)
    }

    @Test("Flujo de caja: el real del mes reconvierte el convertido a 0")
    func cashFlowIndex_zeroConverted_reconverts() {
        let total = realDelMes(sinConvertir(), tasaUSD)
        #expect(cerca(total, 285), "con el bug: 100 (\(total))")
    }

    @Test("Control del Flujo de caja: convertido escrito sin consultar la tasa; una sola divisa no cambia")
    func cashFlowIndex_controls() {
        #expect(cerca(realDelMes(convertidas(), tasaAbsurda), 285))
        #expect(cerca(realDelMes(monodivisa(), tasaAbsurda), 140))
    }

    // MARK: - Tendencia por necesidad

    private func necesidades(_ txs: [TransactionItem], _ tasa: Decimal) -> Double {
        NeedTrendHelper.calculateTrend(
            transactions: txs, grouping: .month, interval: abril, preferredCurrency: .pen,
            converter: conversor(tasa)
        ).reduce(0) { $0 + abs($1.total) }
    }

    @Test("Tendencia por necesidad: el gasto con el convertido a 0 cuenta reconvertido")
    func needTrend_zeroConverted_reconverts() {
        let total = necesidades(sinConvertir(), tasaUSD)
        #expect(cerca(total, 285), "con el bug: 100 (\(total))")
    }

    @Test("Control de la tendencia por necesidad: convertido escrito sin consultar la tasa; una sola divisa no cambia")
    func needTrend_controls() {
        #expect(cerca(necesidades(convertidas(), tasaAbsurda), 285))
        #expect(cerca(necesidades(monodivisa(), tasaAbsurda), 140))
    }

    // MARK: - Aviso de informe

    private func informe(_ txs: [TransactionItem], _ tasa: Decimal) -> ReportTotals {
        ReportNotificationService.accumulateReportTotals(
            transactions: txs, eligibleAccountIDs: [cuenta.persistentModelID], currencyCode: "PEN",
            converter: conversor(tasa)
        )
    }

    private func double(_ d: Decimal) -> Double { NSDecimalNumber(decimal: d).doubleValue }

    @Test("Aviso de informe: gasto e ingreso con el convertido a 0 cuentan reconvertidos")
    func report_zeroConverted_reconverts() {
        let txs = sinConvertir() + [tx(nativo: 200, divisa: "USD", guardado: 0, category: sueldo)]
        let t = informe(txs, tasaUSD)
        #expect(cerca(double(t.totalExpense), 285), "con el bug: 100 (\(t.totalExpense))")
        #expect(cerca(double(t.totalIncome), 740), "con el bug: 0 (\(t.totalIncome))")
    }

    @Test("Control del aviso de informe: convertido escrito sin consultar la tasa; una sola divisa no cambia")
    func report_controls() {
        let escritas = convertidas() + [tx(nativo: 200, divisa: "USD", guardado: 740, category: sueldo)]
        let t = informe(escritas, tasaAbsurda)
        #expect(cerca(double(t.totalExpense), 285))
        #expect(cerca(double(t.totalIncome), 740))
        #expect(cerca(double(informe(monodivisa(), tasaAbsurda).totalExpense), 140))
    }

    // MARK: - Observaciones (`InsightsCalculator`)

    private func mayorGasto(_ txs: [TransactionItem], _ tasa: Decimal) -> HighestExpenseInfo? {
        InsightsCalculator.calculate(
            transactions: txs, accounts: [cuenta], categories: [comida, sueldo], budgets: [],
            scheduledPayments: [], period: .custom, criteria: FilterCriteria(), currencyCode: "PEN",
            customRange: abril, converter: conversor(tasa), now: day(2026, 4, 30)
        ).quickStats.highestExpense
    }

    @Test("Observaciones: el mayor gasto lee el reconvertido, no el 0")
    func insights_zeroConverted_reconverts() {
        let mayor = mayorGasto(sinConvertir(), tasaUSD)
        #expect(mayor?.note == "Hotel", "con el bug: Mercado, porque el hotel contaba 0 (\(String(describing: mayor)))")
        #expect(cerca(mayor?.amount ?? 0, 185))
    }

    @Test("Control de Observaciones: convertido escrito sin consultar la tasa; una sola divisa no cambia")
    func insights_controls() {
        let escrito = mayorGasto(convertidas(), tasaAbsurda)
        #expect(escrito?.note == "Hotel")
        #expect(cerca(escrito?.amount ?? 0, 185))
        let mono = mayorGasto(monodivisa(), tasaAbsurda)
        #expect(mono?.note == "Mercado")
        #expect(cerca(mono?.amount ?? 0, 100))
    }
}
