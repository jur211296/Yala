//
//  ResolvedAmountZeroConvertedTests.swift
//  YalaTests
//
//  Ticket `resolved-amount-trusts-a-zero-converted-amount`. Un movimiento suelto con su importe
//  convertido SIN ESCRIBIR (`amountInPreferredCurrency == 0` con `amount != 0`, la fila llegó
//  incompleta por sync o se creó sin contexto de tasas) contaba **0** en las estadísticas, y sin «≈»:
//  `CashFlowCalculator.resolvedAmount` leía ese 0 como un importe porque la fila decía estar guardada
//  en la divisa principal.
//
//  Ahora ese cero es una conversión AUSENTE y la fila se reconvierte desde su nativo con la tasa de
//  su día —la segunda rama de `resolvedAmount`, el mismo criterio que la síntesis de un gasto de grupo
//  desde #460—, con «≈» si la tasa no es exacta. Vale también para `TransactionItem.chatAmount`, la
//  regla gemela con la que Yala IA cuenta categorías, comercios y destacados.
//
//  Escena (principal PEN, 1 USD = 3,7 en el doble): un gasto de S/ 100 y un sueldo de S/ 1.000 ya en
//  soles, y un gasto de 50 USD y un ingreso de 200 USD con el convertido a 0.
//  - Correcto: gasto 100 + 185 = **285**, ingreso 1.000 + 740 = **1.740**.
//  - Con el bug: gasto **100**, ingreso **1.000**.
//  Cada superficie lleva su control: las mismas filas con el convertido escrito (−185 / 740) dan lo
//  mismo con una tasa ABSURDA, así que el converter no se consulta cuando el guardado vale.
//
//  Sin `ModelContext`: los `@Model` sueltos bastan, como `StatsAggregatorsPreferredCurrencyTests`.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Movimiento suelto con el convertido a 0 · se reconvierte", .serialized)
struct ResolvedAmountZeroConvertedTests {

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

    private var marzo: DateInterval {
        let start = calendar.startOfDay(for: day(2026, 3, 1))
        let end = calendar.date(byAdding: DateComponents(month: 1, second: -1), to: start) ?? start
        return DateInterval(start: start, end: end)
    }

    private let cuenta = Account(
        name: "Principal", currencyCode: "PEN", colorHex: "#000000", iconName: "creditcard", type: "bank"
    )
    private let comida = YalaCategory(name: "Comida", colorHex: "#FF0000", isIncome: false)
    private let sueldo = YalaCategory(name: "Sueldo", colorHex: "#00FF00", isIncome: true)
    private let viaje = YalaTag(name: "Viaje", colorHex: "#0000FF")

    private func tx(
        nativo: Double, divisa: String, guardado: Double, category: YalaCategory,
        note: String = "", date: Date? = nil
    ) -> TransactionItem {
        TransactionItem(
            date: date ?? day(2026, 4, 10), amount: nativo, currencyCode: divisa, note: note,
            category: category, account: cuenta, tags: [viaje],
            amountInPreferredCurrency: guardado, preferredCurrencyCode: "PEN"
        )
    }

    /// Las filas de USD con el convertido sin escribir.
    private func sinConvertir(date: Date? = nil) -> [TransactionItem] {
        [
            tx(nativo: -100, divisa: "PEN", guardado: -100, category: comida, note: "Mercado", date: date),
            tx(nativo: 1_000, divisa: "PEN", guardado: 1_000, category: sueldo, date: date),
            tx(nativo: -50, divisa: "USD", guardado: 0, category: comida, note: "Hotel", date: date),
            tx(nativo: 200, divisa: "USD", guardado: 0, category: sueldo, date: date),
        ]
    }

    /// Las mismas filas con el convertido escrito.
    private func convertidas(date: Date? = nil) -> [TransactionItem] {
        [
            tx(nativo: -100, divisa: "PEN", guardado: -100, category: comida, note: "Mercado", date: date),
            tx(nativo: 1_000, divisa: "PEN", guardado: 1_000, category: sueldo, date: date),
            tx(nativo: -50, divisa: "USD", guardado: -185, category: comida, note: "Hotel", date: date),
            tx(nativo: 200, divisa: "USD", guardado: 740, category: sueldo, date: date),
        ]
    }

    private func cerca(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 0.001 }

    private func conversor(_ tasa: Decimal, _ quality: RateQuality = .exact) -> MockCurrencyConverter {
        MockCurrencyConverter(fixedRate: tasa, quality: quality)
    }

    // MARK: - La regla: `resolvedAmount`

    @Test("resolvedAmount: un 0 guardado con nativo distinto de 0 se reconvierte, con signo")
    func resolvedAmount_zeroWithNonZeroNative_reconverts() {
        let gasto = tx(nativo: -50, divisa: "USD", guardado: 0, category: comida)
        let r = CashFlowCalculator.resolvedAmount(
            gasto, currencyCode: "PEN", adjustment: .none, converter: conversor(tasaUSD)
        )
        #expect(cerca(r.value, -185), "con el bug: 0 (\(r.value))")
        #expect(r.approximateMagnitude == 0, "tasa exacta: nada que marcar")
    }

    @Test("resolvedAmount: reconvertido con una tasa no exacta, toda su magnitud es duda")
    func resolvedAmount_zeroWithInexactRate_isApproximate() {
        let gasto = tx(nativo: -50, divisa: "USD", guardado: 0, category: comida)
        let r = CashFlowCalculator.resolvedAmount(
            gasto, currencyCode: "PEN", adjustment: .none,
            converter: conversor(tasaUSD, .carriedForward(fromDateKey: "2026-04-09"))
        )
        #expect(cerca(r.value, -185))
        #expect(cerca(r.approximateMagnitude, 185), "con el bug: 0 de duda y sin «≈»")
    }

    @Test("resolvedAmount: en la propia divisa principal, el 0 guardado vale el nativo")
    func resolvedAmount_zeroInThePreferredCurrency_readsTheNative() {
        let gasto = tx(nativo: -80, divisa: "PEN", guardado: 0, category: comida)
        let r = CashFlowCalculator.resolvedAmount(
            gasto, currencyCode: "PEN", adjustment: .none, converter: conversor(tasaAbsurda)
        )
        #expect(cerca(r.value, -80), "PEN → PEN no usa la tasa: \(r.value)")
        #expect(r.approximateMagnitude == 0)
    }

    /// Cuenta las conversiones: reconvertir un 0 también da 0, así que sin contar no se ve si el
    /// importe de 0 de verdad se quedó en la primera rama.
    private final class ConversorQueCuenta: CurrencyConverting {
        var llamadas = 0
        private let base = MockCurrencyConverter(fixedRate: 1_000)
        func convert(_ amount: Decimal, from: String, to: String, on date: Date) -> Decimal {
            llamadas += 1; return base.convert(amount, from: from, to: to, on: date)
        }
        func convertWithLatestRate(_ amount: Decimal, from: String, to: String) -> Decimal {
            llamadas += 1; return base.convertWithLatestRate(amount, from: from, to: to)
        }
        func convertChecked(_ amount: Decimal, from: String, to: String, on date: Date)
            -> (amount: Decimal, quality: RateQuality) {
            llamadas += 1; return base.convertChecked(amount, from: from, to: to, on: date)
        }
        func convertCheckedWithLatestRate(_ amount: Decimal, from: String, to: String)
            -> (amount: Decimal, quality: RateQuality) {
            llamadas += 1; return base.convertCheckedWithLatestRate(amount, from: from, to: to)
        }
    }

    @Test("Control: un importe de 0 de verdad sigue siendo 0, sin consultar la tasa")
    func resolvedAmount_trueZero_staysZero() {
        let cero = tx(nativo: 0, divisa: "USD", guardado: 0, category: comida)
        let conversor = ConversorQueCuenta()
        let r = CashFlowCalculator.resolvedAmount(cero, currencyCode: "PEN", adjustment: .none, converter: conversor)
        #expect(r.value == 0)
        #expect(r.approximateMagnitude == 0)
        #expect(conversor.llamadas == 0, "un 0 con nativo 0 es un importe, no una conversión que falta")
        #expect(cero.chatAmount(in: "PEN", converter: conversor) == 0)
        #expect(conversor.llamadas == 0)
    }

    @Test("Control: el convertido escrito manda, y su flag decide la duda")
    func resolvedAmount_storedAmount_isRead() {
        let gasto = TransactionItem(
            date: day(2026, 4, 10), amount: -50, currencyCode: "USD", note: "",
            category: comida, account: cuenta,
            amountInPreferredCurrency: -185, preferredCurrencyCode: "PEN",
            isExchangeRateProvisional: true
        )
        let r = CashFlowCalculator.resolvedAmount(
            gasto, currencyCode: "PEN", adjustment: .none, converter: conversor(tasaAbsurda)
        )
        #expect(cerca(r.value, -185))
        #expect(cerca(r.approximateMagnitude, 185))
    }

    /// La pata real de un gasto de grupo con el convertido a 0 la cubre la síntesis (#460), y su
    /// importe se queda en ella: es el mismo número que leen los calculadores que no pasan por
    /// `resolvedAmount`. La pata de préstamo se guardó con OTRA tasa (3,5 y provisional), así que la
    /// síntesis (−370 + 315 = −55, con «≈») y reconvertir el nativo ajustado (−10 × 3,7 = −37) difieren.
    @Test("Pata real de un gasto de grupo con el convertido a 0: manda la síntesis")
    func resolvedAmount_groupRealLegWithZero_keepsTheSynthesis() {
        let grupos = Account(
            name: "Grupos", currencyCode: "USD", colorHex: "#000000", iconName: "person.3", type: "bank"
        )
        grupos.isSystemAccount = true
        let prestamos = YalaCategory(name: "Préstamo a grupos", colorHex: "#000000", isIncome: true)
        let real = TransactionItem(
            date: day(2026, 4, 10), amount: -100, currencyCode: "USD", note: "",
            category: comida, account: cuenta,
            amountInPreferredCurrency: 0, preferredCurrencyCode: "PEN"
        )
        real.splitExpenseID = "cena"
        let prestamo = TransactionItem(
            date: day(2026, 4, 10), amount: 90, currencyCode: "USD", note: "",
            category: prestamos, account: grupos,
            amountInPreferredCurrency: 315, preferredCurrencyCode: "PEN",
            isExchangeRateProvisional: true
        )
        prestamo.splitExpenseID = "cena"
        let ajuste = GroupBridgeStatsAdjustment.build(from: [real, prestamo], converter: conversor(tasaUSD))
        #expect(ajuste.isAdjusted(real))

        let r = CashFlowCalculator.resolvedAmount(
            real, currencyCode: "PEN", adjustment: ajuste, converter: conversor(tasaUSD)
        )
        #expect(cerca(r.value, ajuste.amountInPreferredCurrency(real)), "\(r.value)")
        #expect(cerca(r.value, -55), "reconvirtiendo el nativo ajustado saldría −37: \(r.value)")
        #expect(cerca(r.approximateMagnitude, 315), "la duda es la de la pata provisional")
    }

    // MARK: - Yala IA con «mi parte» = 0

    /// Pagué 100 USD por otros: mi parte es 0. La pata real llegó con el convertido a 0 y la de
    /// préstamo bien convertida (+370). Un mercado de S/ 50 en la misma categoría.
    private func gastoAjenoEntero() -> (txs: [TransactionItem], real: TransactionItem) {
        let grupos = Account(
            name: "Grupos", currencyCode: "USD", colorHex: "#000000", iconName: "person.3", type: "bank"
        )
        grupos.isSystemAccount = true
        let prestamos = YalaCategory(name: "Préstamo a grupos", colorHex: "#000000", isIncome: true)
        let real = TransactionItem(
            date: day(2026, 4, 10), amount: -100, currencyCode: "USD", note: "Cena de todos",
            category: comida, account: cuenta,
            amountInPreferredCurrency: 0, preferredCurrencyCode: "PEN"
        )
        real.splitExpenseID = "cena-ajena"
        let prestamo = TransactionItem(
            date: day(2026, 4, 10), amount: 100, currencyCode: "USD", note: "Cena de todos",
            category: prestamos, account: grupos,
            amountInPreferredCurrency: 370, preferredCurrencyCode: "PEN"
        )
        prestamo.splitExpenseID = "cena-ajena"
        let mercado = tx(nativo: -50, divisa: "PEN", guardado: -50, category: comida, note: "Mercado")
        return ([real, prestamo, mercado], real)
    }

    @Test("Yala IA: con mi parte a 0 y la pata real sin convertir, la categoría no suma el gasto entero")
    func aiContext_myShareZero_doesNotCountTheWholeExpense() throws {
        let g = gastoAjenoEntero()
        let ajuste = GroupBridgeStatsAdjustment.build(from: g.txs, converter: conversor(tasaUSD))
        #expect(cerca(ajuste.amountInPreferredCurrency(g.real), 0), "premisa: la síntesis da 0")

        let ctx = FullFinancialContextBuilder().buildFromArrays(
            transactions: g.txs, budgets: [], accounts: [], tags: [], scheduledPayments: [],
            currencyCode: "PEN", currencyDisplay: "S/", converter: conversor(tasaUSD),
            language: "es", country: "PE", includeAnomalies: false, adjustment: ajuste,
            now: day(2026, 4, 20)
        )
        let comidaIA = try #require(ctx.categories.first { $0.name == "Comida" })
        #expect(cerca(comidaIA.totalCurrentMonth, 50), """
            Comida: \(comidaIA.totalCurrentMonth). Comparando valores la pata parecía suelta y             `chatAmount` reconvertía el gasto entero: 420.
            """)
    }

    @Test("Anomalías: con mi parte a 0 y la pata real sin convertir, no hay anomalía de 370")
    func anomalies_myShareZero_doesNotFlagTheWholeExpense() {
        let g = gastoAjenoEntero()
        let base = [3, 10, 17].map { d in
            tx(nativo: -30, divisa: "PEN", guardado: -30, category: comida, note: "Mercado", date: day(2026, 3, d))
        }
        let todas = base + g.txs
        let ajuste = GroupBridgeStatsAdjustment.build(from: todas, converter: conversor(tasaUSD))
        let hits = AnomalyDetectionCalculator.detect(
            allTransactions: todas, periodTransactions: [g.real], interval: abril,
            currencyCode: "PEN", adjustment: ajuste, converter: conversor(tasaUSD)
        )
        #expect(!hits.contains { cerca($0.amount, 370) }, "anomalías: \(hits.map(\.amount))")
    }

    // MARK: - Sin categoría

    @Test("Sin categoría y con el convertido a 0: cuenta como gasto, no como ingreso negativo")
    func uncategorized_zeroConverted_isAnExpense() {
        let suelto = TransactionItem(
            date: day(2026, 4, 10), amount: -50, currencyCode: "USD", note: "",
            category: nil, account: cuenta,
            amountInPreferredCurrency: 0, preferredCurrencyCode: "PEN"
        )
        #expect(!TransactionClassificationLogic.isIncome(suelto), "el 0 guardado decía «ingreso»")
        let t = StatisticsViewModel.periodTotals(
            filtered: [suelto], currencyCode: "PEN", adjustment: .none, converter: conversor(tasaUSD)
        )
        #expect(cerca(t.expense, 185), "gasto: \(t.expense)")
        #expect(cerca(t.income, 0), "ingreso: \(t.income) (con el bug: −185)")
    }

    // MARK: - Panel: hero y Tendencias

    private func hero(_ txs: [TransactionItem], _ converter: CurrencyConverting) -> HeroBucketsCalculator.Buckets {
        HeroBucketsCalculator.calculate(
            transactions: txs, monthInterval: abril, prevInterval: marzo, periodInterval: abril,
            eligibleAccountIDs: [cuenta.persistentModelID], currencyCode: "PEN", converter: converter
        )
    }

    @Test("Hero del Panel: el convertido a 0 se reconvierte, y con tasa no exacta marca")
    func hero_zeroConverted_reconvertsAndMarks() {
        let exacta = hero(sinConvertir(), conversor(tasaUSD))
        #expect(cerca(exacta.periodExpense, 285), "gasto: \(exacta.periodExpense) (con el bug: 100)")
        #expect(cerca(exacta.periodIncome, 1_740), "ingreso: \(exacta.periodIncome) (con el bug: 1.000)")
        #expect(!exacta.periodExpenseApproximate)

        let aproximada = hero(sinConvertir(), conversor(tasaUSD, .carriedForward(fromDateKey: "2026-04-09")))
        #expect(aproximada.periodExpenseApproximate, "185 de 285 salen de una tasa que no era la del día")
        #expect(aproximada.periodIncomeApproximate, "740 de 1.740 salen de una tasa que no era la del día")
    }

    @Test("Control del hero: con el convertido escrito no se consulta la tasa")
    func hero_converted_readsStored() {
        let b = hero(convertidas(), conversor(tasaAbsurda))
        #expect(cerca(b.periodExpense, 285))
        #expect(cerca(b.periodIncome, 1_740))
    }

    @Test("Tendencias: el flujo del período reconvierte el convertido a 0")
    func cashFlow_zeroConverted_reconverts() {
        let s = CashFlowCalculator.calculateCashFlow(
            transactions: sinConvertir(), interval: abril, grouping: .day, currencyCode: "PEN",
            converter: conversor(tasaUSD)
        )
        #expect(cerca(s.totalExpense, 285), "gasto: \(s.totalExpense)")
        #expect(cerca(s.totalIncome, 1_740), "ingreso: \(s.totalIncome)")

        let control = CashFlowCalculator.calculateCashFlow(
            transactions: convertidas(), interval: abril, grouping: .day, currencyCode: "PEN",
            converter: conversor(tasaAbsurda)
        )
        #expect(cerca(control.totalExpense, 285))
        #expect(cerca(control.totalIncome, 1_740))
    }

    // MARK: - Estadísticas e Informes

    @Test("Estadísticas: KPI, Distribución y etiquetas reconvierten el convertido a 0")
    func statistics_zeroConverted_reconverts() throws {
        let kpi = StatisticsViewModel.periodTotals(
            filtered: sinConvertir(), currencyCode: "PEN", adjustment: .none, converter: conversor(tasaUSD)
        )
        #expect(cerca(kpi.expense, 285), "KPI gasto: \(kpi.expense)")
        #expect(cerca(kpi.income, 1_740), "KPI ingreso: \(kpi.income)")

        let sankey = SankeyFlowCalculator.compute(
            transactions: sinConvertir(), interval: abril, currencyCode: "PEN", converter: conversor(tasaUSD)
        )
        #expect(cerca(sankey.totalExpense, 285), "Distribución: \(sankey.totalExpense)")

        let etiquetas = TagSpendingCalculator.calculateTopSpending(
            transactions: sinConvertir(), interval: abril, currencyCode: "PEN",
            allTags: [viaje], converter: conversor(tasaUSD)
        )
        let fila = try #require(etiquetas.first)
        #expect(cerca(fila.amount, 285), "«Viaje»: \(fila.amount)")
    }

    @Test("Informes: la tabla dinámica reconvierte el convertido a 0 en las dos columnas")
    func pivot_zeroConverted_reconverts() throws {
        let nodos = PivotTableCalculator.buildTree(
            currentTransactions: sinConvertir(), previousTransactions: sinConvertir(date: day(2026, 3, 10)),
            hierarchy: [.tipo], preferredCurrency: "PEN", allTags: [viaje], converter: conversor(tasaUSD)
        )
        let gasto = try #require(nodos.first { !$0.isIncome })
        #expect(cerca(gasto.amount, -285), "gasto actual: \(gasto.amount)")
        let anterior = try #require(gasto.previousAmount)
        #expect(cerca(anterior, -285), "gasto anterior: \(anterior)")
    }

    // MARK: - Yala IA

    private func contexto(_ txs: [TransactionItem], _ tasa: Decimal) -> FullFinancialContext {
        FullFinancialContextBuilder().buildFromArrays(
            transactions: txs, budgets: [], accounts: [], tags: [], scheduledPayments: [],
            currencyCode: "PEN", currencyDisplay: "S/", converter: conversor(tasa),
            language: "es", country: "PE", includeAnomalies: false, now: day(2026, 4, 20)
        )
    }

    @Test("Yala IA: totales del mes y de la categoría reconvierten el convertido a 0")
    func aiContext_zeroConverted_reconverts() throws {
        let ctx = contexto(sinConvertir(), tasaUSD)
        #expect(cerca(ctx.periods.currentMonth.expense, 285), "gasto del mes: \(ctx.periods.currentMonth.expense)")
        let comidaIA = try #require(ctx.categories.first { $0.name == "Comida" })
        #expect(cerca(comidaIA.totalCurrentMonth, 285), """
            Comida en el contexto (`chatAmount`): \(comidaIA.totalCurrentMonth). Con el bug: 100, y la app ya
            reconvertía: dos cifras para el mismo dinero.
            """)

        let control = contexto(convertidas(), tasaAbsurda)
        #expect(cerca(control.periods.currentMonth.expense, 285))
        let comidaControl = try #require(control.categories.first { $0.name == "Comida" })
        #expect(cerca(comidaControl.totalCurrentMonth, 285))
    }

    @Test("chatAmount: el 0 guardado se reconvierte; el escrito se lee")
    func chatAmount_zeroConverted_reconverts() {
        let sinEscribir = tx(nativo: -50, divisa: "USD", guardado: 0, category: comida)
        #expect(cerca(sinEscribir.chatAmount(in: "PEN", converter: conversor(tasaUSD)), 185))
        let escrito = tx(nativo: -50, divisa: "USD", guardado: -185, category: comida)
        #expect(cerca(escrito.chatAmount(in: "PEN", converter: conversor(tasaAbsurda)), 185))
    }

    @Test("Sugerencias del chat: el resumen del mes reconvierte el convertido a 0")
    func suggestions_zeroConverted_reconverts() {
        let s = ChatSuggestionsLLMService.monthSums(
            sinConvertir(), tagCatalog: Tag.byIDLookup([viaje]), currencyCode: "PEN",
            adjustment: .none, includeGroupTransactions: true, converter: conversor(tasaUSD)
        )
        #expect(cerca(s.totalExpense, 285), "gasto: \(s.totalExpense)")
        #expect(cerca(s.totalIncome, 1_740), "ingreso: \(s.totalIncome)")
        #expect(cerca(s.merchants[MerchantCanonicalizer.canonicalize("Hotel")] ?? 0, 185), "comercios: \(s.merchants)")
    }
}
