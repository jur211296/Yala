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

    /// Desde `panel-balance-chart-contradicts-its-own-figure` (2026-10-16) el saldo no lee el monto guardado: es lo
    /// que hay en cada divisa NATIVA al cierre, valorado con la tasa de ese día (`BalanceValuation`). Con las filas de
    /// USD guardadas a 3,7 y la tasa a 4: 900 + 150 × 4 = 1.500 (al tipo guardado saldría 1.455).
    @Test("Saldo: valora lo nativo con la tasa del cierre, no el monto guardado")
    func balance_valuesNativeAmountsAtTheClosingRate() {
        let summary = resumen(unaSolaDivisa(date: haceDias(1)), tasa: 4)
        #expect(cerca(summary.periodBalance, 1_500), "saldo: \(String(describing: summary.periodBalance))")
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

    /// La curva del widget: cada punto es el saldo NATIVO al cierre de su día valorado con la tasa de ese día, y el de
    /// hoy es el saldo vivo que se le pasa (`BalanceValuation`, la regla de la curva de la app desde
    /// `panel-balance-chart-contradicts-its-own-figure`). Un saldo inicial de 10.000 soles hace 5 días y la mezcla
    /// ayer.
    private func curva(
        _ filas: [TransactionItem], tasa: Decimal, sinCuenta: [TransactionItem] = []
    ) -> (trend: WidgetTrendData, saldoVivo: Double) {
        let apertura = tx(nativo: 10_000, divisa: "PEN", guardado: 10_000, guardadaEn: "PEN",
                          category: sueldo, date: haceDias(5))
        let cuenta = Account(name: "Principal", currencyCode: "PEN", colorHex: "#000000", iconName: "creditcard", type: "bank")
        let todas = filas + [apertura]
        for fila in todas { fila.account = cuenta }
        let converter = MockCurrencyConverter(fixedRate: tasa)
        // El saldo de hoy como lo calcula `buildSnapshot`: la regla del saldo vivo sobre las mismas filas.
        let saldoVivo = LiveBalanceCalculator.liveBalance(
            accounts: [cuenta], transactions: todas, preferredCurrencyCode: "PEN", converter: converter
        )
        let trend = WidgetDataCache.buildTrendData(
            transactions: todas + sinCuenta, totalBalance: saldoVivo, currencyCode: "PEN", converter: converter
        )
        return (trend, saldoVivo)
    }

    private func punto(_ trend: WidgetTrendData, haceDias dias: Int) -> Double? {
        let dia = calendar.startOfDay(for: haceDias(dias))
        return trend.dailyPoints.first { $0.date == dia }?.balance
    }

    @Test("Curva de saldo: el día de la mezcla vale lo nativo a la tasa de ese día")
    func trend_mixedPreferredCurrencies_valuesNativeAtThatDaysRate() {
        let (trend, saldoVivo) = curva(mezcla(date: haceDias(1)), tasa: tasaUSD)
        #expect(cerca(punto(trend, haceDias: 2), 10_000), "antes de la mezcla: \(String(describing: punto(trend, haceDias: 2)))")
        #expect(cerca(punto(trend, haceDias: 1), 10_000 + 1_455), "el día de la mezcla: \(String(describing: punto(trend, haceDias: 1)))")
        // Hoy es el saldo vivo que recibe, y sin movimientos hoy coincide con el de ayer: ningún escalón.
        #expect(cerca(punto(trend, haceDias: 0), saldoVivo))
        #expect(cerca(saldoVivo, 10_000 + 1_455))
    }

    /// Una fila sin cuenta (pasa durante una importación de iCloud, con la relación aún sin llegar) no cuenta en el
    /// saldo vivo y tampoco en la curva: si contara solo en la curva, el punto de hoy pintaría un escalón.
    @Test("Curva de saldo: una fila sin cuenta no cuenta en ningún punto")
    func trend_rowWithoutAccount_countsInNoPoint() {
        let huerfana = tx(nativo: -3_000, divisa: "PEN", guardado: -3_000, guardadaEn: "PEN",
                          category: comida, date: haceDias(3))
        let (trend, saldoVivo) = curva(mezcla(date: haceDias(1)), tasa: tasaUSD, sinCuenta: [huerfana])
        #expect(cerca(saldoVivo, 10_000 + 1_455), "el saldo vivo no la cuenta")
        #expect(cerca(punto(trend, haceDias: 1), saldoVivo), "ayer = hoy sin movimientos hoy: \(String(describing: punto(trend, haceDias: 1)))")
        #expect(cerca(punto(trend, haceDias: 2), 10_000))
    }

    @Test("Curva de saldo: no lee el monto guardado, valora lo nativo")
    func trend_valuesNativeAmounts_notTheStoredOnes() {
        let (trend, _) = curva(unaSolaDivisa(date: haceDias(1)), tasa: 4)
        #expect(cerca(punto(trend, haceDias: 1), 10_000 + 1_500), "el día de la mezcla: \(String(describing: punto(trend, haceDias: 1)))")
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
