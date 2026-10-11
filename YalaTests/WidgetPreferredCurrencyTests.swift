//
//  WidgetPreferredCurrencyTests.swift
//  YalaTests
//
//  Ticket `widgets-sum-stored-amounts-from-other-preferred-currencies`: los totales de los widgets
//  sumaban el `amountInPreferredCurrency` guardado sin mirar EN QUÉ divisa principal se guardó. Tras
//  cambiar de divisa principal con filas sin recalcular, el widget enseñaba otro gasto que la app,
//  con el símbolo de la divisa vigente.
//
//  El snapshot resuelve ahora cada fila con `CashFlowCalculator.resolvedAmount`, la regla de la app
//  (#434/#438/#451). Cada superficie del snapshot lleva las dos direcciones:
//  - **mezcla**: una fila en soles y otra guardada cuando la principal era USD ⇒ la de USD se
//    reconvierte (con el código viejo el total sale con las dos escalas sumadas);
//  - **una sola divisa**: todo guardado en la principal ⇒ el converter no interviene. La tasa del
//    doble es absurda a propósito: cualquier reconversión de más se ve en el total.
//

import Foundation
import Testing

@testable import Yala

@MainActor
@Suite("Widgets · divisas principales mezcladas", .serialized)
struct WidgetPreferredCurrencyTests {

    /// 1 USD = 3,7 PEN en el doble.
    private let tasaUSD: Decimal = 3.7
    /// Tasa que ninguna fila debería usar en el caso de una sola divisa.
    private let tasaAbsurda: Decimal = 1_000

    private let calendar = Calendar.current

    private let comida = YalaCategory(name: "Comida", colorHex: "#FF0000", isIncome: false)
    private let sueldo = YalaCategory(name: "Sueldo", colorHex: "#00FF00", isIncome: true)
    private var mercado: Subcategory { Subcategory(name: "Mercado", category: comida) }

    /// Mediodía de hace `dias` días: lejos de la medianoche para que ningún cambio de día lo mueva.
    private func haceDias(_ dias: Int) -> Date {
        let hoy = calendar.startOfDay(for: Date.now)
        let dia = calendar.date(byAdding: .day, value: -dias, to: hoy) ?? hoy
        return calendar.date(byAdding: .hour, value: 12, to: dia) ?? dia
    }

    /// Una fila con su monto nativo y el monto que se guardó cuando la principal era `guardadaEn`.
    private func tx(
        nativo: Double, divisa: String, guardado: Double, guardadaEn: String,
        category: YalaCategory, subcategory: Subcategory? = nil, date: Date
    ) -> TransactionItem {
        TransactionItem(
            date: date, amount: nativo, currencyCode: divisa, note: "",
            category: category, subcategory: subcategory,
            amountInPreferredCurrency: guardado, preferredCurrencyCode: guardadaEn
        )
    }

    /// Principal PEN: un gasto y un ingreso ya en soles, y otro par guardado cuando la principal era
    /// USD y sin recalcular. Gasto correcto: 100 + 50 × 3,7 = 285 (el viejo: 150). Ingreso correcto:
    /// 1.000 + 200 × 3,7 = 1.740 (el viejo: 1.200). Neto con signo: 1.455 (el viejo: 1.050).
    private func mezcla(date: Date) -> [TransactionItem] {
        let sub = mercado
        return [
            tx(nativo: -100, divisa: "PEN", guardado: -100, guardadaEn: "PEN",
               category: comida, subcategory: sub, date: date),
            tx(nativo: 1_000, divisa: "PEN", guardado: 1_000, guardadaEn: "PEN", category: sueldo, date: date),
            tx(nativo: -50, divisa: "USD", guardado: -50, guardadaEn: "USD",
               category: comida, subcategory: sub, date: date),
            tx(nativo: 200, divisa: "USD", guardado: 200, guardadaEn: "USD", category: sueldo, date: date),
        ]
    }

    /// Las mismas filas de USD, ya recalculadas a soles: todo guardado en la principal.
    private func unaSolaDivisa(date: Date) -> [TransactionItem] {
        let sub = mercado
        return [
            tx(nativo: -100, divisa: "PEN", guardado: -100, guardadaEn: "PEN",
               category: comida, subcategory: sub, date: date),
            tx(nativo: 1_000, divisa: "PEN", guardado: 1_000, guardadaEn: "PEN", category: sueldo, date: date),
            tx(nativo: -50, divisa: "USD", guardado: -185, guardadaEn: "PEN",
               category: comida, subcategory: sub, date: date),
            tx(nativo: 200, divisa: "USD", guardado: 740, guardadaEn: "PEN", category: sueldo, date: date),
        ]
    }

    private func cerca(_ a: Double?, _ b: Double) -> Bool {
        guard let a else { return false }
        return abs(a - b) < 0.001
    }

    private func resumen(
        _ filas: [TransactionItem], tasa: Decimal, quality: RateQuality = .exact
    ) -> WidgetPeriodSummary {
        WidgetDataCache.buildPeriodSummary(
            transactions: filas,
            periodStart: haceDias(3),
            periodEnd: Date.now,
            currencyCode: "PEN",
            allTransactionsForBalance: filas,
            converter: MockCurrencyConverter(fixedRate: tasa, quality: quality)
        )
    }

    // MARK: - Totales del período

    @Test("Totales: las filas guardadas en otra divisa se reconvierten antes de sumar")
    func totals_mixedPreferredCurrencies_convertsBeforeSumming() {
        let summary = resumen(mezcla(date: haceDias(1)), tasa: tasaUSD)
        #expect(cerca(summary.totalExpense, 285), "gasto: \(summary.totalExpense)")
        #expect(cerca(summary.totalIncome, 1_740), "ingreso: \(summary.totalIncome)")
        #expect(cerca(summary.netCashFlow, 1_455), "neto: \(summary.netCashFlow)")
    }

    @Test("Totales: con todo en la principal, lee el monto guardado")
    func totals_singlePreferredCurrency_readsStoredAmounts() {
        let summary = resumen(unaSolaDivisa(date: haceDias(1)), tasa: tasaAbsurda)
        #expect(cerca(summary.totalExpense, 285), "gasto: \(summary.totalExpense)")
        #expect(cerca(summary.totalIncome, 1_740), "ingreso: \(summary.totalIncome)")
    }

    // MARK: - Saldo del período

    @Test("Saldo: las filas guardadas en otra divisa se reconvierten antes de acumular")
    func balance_mixedPreferredCurrencies_convertsBeforeSumming() {
        let summary = resumen(mezcla(date: haceDias(1)), tasa: tasaUSD)
        #expect(cerca(summary.periodBalance, 1_455), "saldo: \(String(describing: summary.periodBalance))")
    }

    @Test("Saldo: con todo en la principal, lee el monto guardado")
    func balance_singlePreferredCurrency_readsStoredAmounts() {
        let summary = resumen(unaSolaDivisa(date: haceDias(1)), tasa: tasaAbsurda)
        #expect(cerca(summary.periodBalance, 1_455), "saldo: \(String(describing: summary.periodBalance))")
    }

    // MARK: - Categorías y subcategorías

    @Test("Categorías y subcategorías: el gasto reconvertido entra en su categoría")
    func breakdowns_mixedPreferredCurrencies_convertsBeforeSumming() {
        let summary = resumen(mezcla(date: haceDias(1)), tasa: tasaUSD)
        let categoria = summary.topCategories.first { $0.name == "Comida" }
        #expect(cerca(categoria?.amount, 285), "categoría: \(String(describing: categoria?.amount))")
        let subcategoria = summary.topSubcategories.first { $0.name == "Mercado" }
        #expect(cerca(subcategoria?.amount, 285), "subcategoría: \(String(describing: subcategoria?.amount))")
    }

    @Test("Categorías y subcategorías: con todo en la principal, lee el monto guardado")
    func breakdowns_singlePreferredCurrency_readsStoredAmounts() {
        let summary = resumen(unaSolaDivisa(date: haceDias(1)), tasa: tasaAbsurda)
        let categoria = summary.topCategories.first { $0.name == "Comida" }
        #expect(cerca(categoria?.amount, 285), "categoría: \(String(describing: categoria?.amount))")
        let subcategoria = summary.topSubcategories.first { $0.name == "Mercado" }
        #expect(cerca(subcategoria?.amount, 285), "subcategoría: \(String(describing: subcategoria?.amount))")
    }

    // MARK: - Flujo de caja por día

    @Test("Flujo por día: el día de la mezcla suma en la divisa vigente")
    func cashFlow_mixedPreferredCurrencies_convertsBeforeSumming() {
        let dia = calendar.startOfDay(for: haceDias(1))
        let summary = resumen(mezcla(date: haceDias(1)), tasa: tasaUSD)
        let punto = summary.cashFlowPoints.first { $0.date == dia }
        #expect(cerca(punto?.expense, 285), "gasto del día: \(String(describing: punto?.expense))")
        #expect(cerca(punto?.income, 1_740), "ingreso del día: \(String(describing: punto?.income))")
    }

    @Test("Flujo por día: con todo en la principal, lee el monto guardado")
    func cashFlow_singlePreferredCurrency_readsStoredAmounts() {
        let dia = calendar.startOfDay(for: haceDias(1))
        let summary = resumen(unaSolaDivisa(date: haceDias(1)), tasa: tasaAbsurda)
        let punto = summary.cashFlowPoints.first { $0.date == dia }
        #expect(cerca(punto?.expense, 285), "gasto del día: \(String(describing: punto?.expense))")
        #expect(cerca(punto?.income, 1_740), "ingreso del día: \(String(describing: punto?.income))")
    }

    // MARK: - La marca «≈»

    @Test("Marca: una reconversión con tasa aproximada marca el gasto")
    func mark_approximateReconversion_marksTheExpense() {
        // 185 de 285 salen de una tasa aproximada: el 65 %, muy por encima del umbral.
        let summary = resumen(mezcla(date: haceDias(1)), tasa: tasaUSD, quality: .staticFallback)
        #expect(summary.expenseIsApproximate == true)
        // Control: la misma mezcla con tasa exacta no marca.
        let exacto = resumen(mezcla(date: haceDias(1)), tasa: tasaUSD)
        #expect(exacto.expenseIsApproximate == false)
    }

    @Test("Marca: una reconversión con tasa aproximada marca también el ingreso y el saldo")
    func mark_approximateReconversion_marksIncomeAndBalance() {
        // Ingreso: 740 dudosos de 1.740 (43 %). Saldo: 185 + 740 = 925 dudosos sobre 1.455 (64 %).
        let summary = resumen(mezcla(date: haceDias(1)), tasa: tasaUSD, quality: .staticFallback)
        #expect(summary.incomeIsApproximate == true)
        #expect(summary.periodBalanceIsApproximate == true)
        // Control: la misma mezcla con tasa exacta no marca ninguno de los dos.
        let exacto = resumen(mezcla(date: haceDias(1)), tasa: tasaUSD)
        #expect(exacto.incomeIsApproximate == false)
        #expect(exacto.periodBalanceIsApproximate == false)
    }

    // MARK: - Curva de saldo

    /// La curva se recorre HACIA ATRÁS desde el saldo de hoy, que ya está en la divisa vigente: el
    /// punto de antes del día de la mezcla es `saldo − cambio de ese día`.
    private func puntoAntesDeLaMezcla(_ filas: [TransactionItem], tasa: Decimal) -> Double? {
        // Una fila vieja y nula fija cuántos días de curva hay (5), sin mover el saldo.
        let ancla = tx(nativo: 0, divisa: "PEN", guardado: 0, guardadaEn: "PEN",
                       category: comida, date: haceDias(5))
        let trend = WidgetDataCache.buildTrendData(
            transactions: filas + [ancla],
            totalBalance: 10_000,
            currencyCode: "PEN",
            converter: MockCurrencyConverter(fixedRate: tasa)
        )
        let antes = calendar.startOfDay(for: haceDias(2))
        return trend.dailyPoints.first { $0.date == antes }?.balance
    }

    @Test("Curva de saldo: el día de la mezcla resta en la divisa vigente")
    func trend_mixedPreferredCurrencies_convertsBeforeSubtracting() {
        let punto = puntoAntesDeLaMezcla(mezcla(date: haceDias(1)), tasa: tasaUSD)
        #expect(cerca(punto, 10_000 - 1_455), "punto: \(String(describing: punto))")
    }

    @Test("Curva de saldo: con todo en la principal, lee el monto guardado")
    func trend_singlePreferredCurrency_readsStoredAmounts() {
        let punto = puntoAntesDeLaMezcla(unaSolaDivisa(date: haceDias(1)), tasa: tasaAbsurda)
        #expect(cerca(punto, 10_000 - 1_455), "punto: \(String(describing: punto))")
    }

    // MARK: - La fila que viaja al widget

    /// El camino de emergencia del widget suma `amountInPreferredCurrency` de estas filas, y la fila
    /// no viaja con la divisa en que se guardó: el snapshot tiene que escribirla ya resuelta.
    @Test("Fila del widget: viaja con el importe ya resuelto en la divisa vigente")
    func widgetRow_mixedPreferredCurrencies_travelsResolved() {
        let usd = tx(nativo: -50, divisa: "USD", guardado: -50, guardadaEn: "USD",
                     category: comida, date: haceDias(1))
        let fila = WidgetDataCache.widgetTransaction(
            usd, currencyCode: "PEN", converter: MockCurrencyConverter(fixedRate: tasaUSD)
        )
        #expect(cerca(fila.amountInPreferredCurrency, -185), "importe: \(fila.amountInPreferredCurrency)")
        #expect(fila.isExchangeRateProvisional == false)
        // El importe que pinta el widget de últimos registros sigue siendo el nativo.
        #expect(fila.amount == -50 && fila.currencyCode == "USD")
    }

    @Test("Fila del widget: con todo en la principal, viaja el monto guardado y su flag")
    func widgetRow_singlePreferredCurrency_travelsStored() {
        let usd = TransactionItem(
            date: haceDias(1), amount: -50, currencyCode: "USD", category: comida,
            amountInPreferredCurrency: -185, preferredCurrencyCode: "PEN",
            isExchangeRateProvisional: true
        )
        let fila = WidgetDataCache.widgetTransaction(
            usd, currencyCode: "PEN", converter: MockCurrencyConverter(fixedRate: tasaAbsurda)
        )
        #expect(cerca(fila.amountInPreferredCurrency, -185), "importe: \(fila.amountInPreferredCurrency)")
        #expect(fila.isExchangeRateProvisional == true)
    }

    @Test("Fila del widget: una reconversión con tasa aproximada viaja marcada")
    func widgetRow_approximateReconversion_travelsFlagged() {
        let usd = tx(nativo: -50, divisa: "USD", guardado: -50, guardadaEn: "USD",
                     category: comida, date: haceDias(1))
        let fila = WidgetDataCache.widgetTransaction(
            usd, currencyCode: "PEN",
            converter: MockCurrencyConverter(fixedRate: tasaUSD, quality: .staticFallback)
        )
        #expect(fila.isExchangeRateProvisional == true)
    }
}
