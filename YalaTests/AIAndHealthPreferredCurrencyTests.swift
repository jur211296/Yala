//
//  AIAndHealthPreferredCurrencyTests.swift
//  YalaTests
//
//  Tickets `yala-ia-context-sums-stored-amounts-from-other-preferred-currencies` y
//  `health-score-income-sums-stored-amounts-from-other-preferred-currencies`: tras #438/#451/#452 las
//  estadísticas, Tendencias y los widgets reconvertían las filas guardadas con otra divisa principal,
//  pero Yala IA y la salud financiera seguían sumando su `amountInPreferredCurrency` tal cual:
//  - las sugerencias del chat (totales del mes y rankings de categorías, comercios y etiquetas);
//  - el contexto de Yala IA y las anomalías, en la pata real de un gasto de grupo (el neto
//    `-myShare` se devolvía en la escala guardada);
//  - el ingreso con el que la salud financiera mide la carga de Compromisos.
//
//  Todas resuelven ahora cada fila con `CashFlowCalculator.resolvedAmount`. Cada superficie lleva las
//  dos direcciones, como `TrendsPreferredCurrencyTests`:
//  - **mezcla**: filas en soles y otras guardadas cuando la principal era USD ⇒ éstas se reconvierten;
//  - **una sola divisa**: todo guardado en la principal ⇒ el converter no interviene (tasa absurda).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Yala IA y salud financiera · divisas principales mezcladas", .serialized)
struct AIAndHealthPreferredCurrencyTests {

    /// 1 USD = 3,7 PEN en el doble.
    private let tasaUSD: Decimal = 3.7
    /// Tasa que ninguna fila debería usar en el caso de una sola divisa.
    private let tasaAbsurda: Decimal = 1_000

    private let calendar = Calendar.current

    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: 12)) ?? Date()
    }

    private func cerca(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 0.001 }

    // MARK: - Filas sueltas (sugerencias y salud financiera)

    private struct Escena {
        let cuenta: Account
        let comida: YalaCategory
        let viajes: YalaCategory
        let sueldo: YalaCategory
        let etiqueta: YalaTag
    }

    private func escena(_ context: ModelContext) -> Escena {
        let etiqueta = YalaTag(name: "Vacaciones")
        context.insert(etiqueta)
        return Escena(
            cuenta: makeTestAccount(context: context, name: "Principal", currencyCode: "PEN"),
            comida: makeTestCategory(context: context, name: "Comida"),
            viajes: makeTestCategory(context: context, name: "Viajes"),
            sueldo: makeTestCategory(context: context, name: "Sueldo", isIncome: true),
            etiqueta: etiqueta
        )
    }

    private func tx(
        _ context: ModelContext, _ e: Escena,
        nativo: Double, divisa: String, guardado: Double, guardadaEn: String,
        category: YalaCategory, note: String = "", tag: YalaTag? = nil, date: Date
    ) -> TransactionItem {
        let t = TransactionItem(
            date: date, amount: nativo, currencyCode: divisa, note: note,
            category: category, account: e.cuenta,
            amountInPreferredCurrency: guardado, preferredCurrencyCode: guardadaEn,
            tagIDs: tag?.id.uuidString
        )
        context.insert(t)
        return t
    }

    /// Principal PEN. Comida: 100 en soles. Viajes: 50 USD guardados cuando la principal era USD y sin
    /// recalcular. Sueldo: 1.000 en soles + 200 USD guardados en USD.
    /// Gasto: 100 + 50 × 3,7 = 285 (el viejo: 150). Ingreso: 1.000 + 200 × 3,7 = 1.740 (el viejo: 1.200).
    /// Viajes (185) pasa por delante de Comida (100); con la lectura vieja iba detrás (50).
    private func mezcla(_ context: ModelContext, _ e: Escena, _ date: Date) -> [TransactionItem] {
        [
            tx(context, e, nativo: -100, divisa: "PEN", guardado: -100, guardadaEn: "PEN",
               category: e.comida, note: "Mercado", date: date),
            tx(context, e, nativo: -50, divisa: "USD", guardado: -50, guardadaEn: "USD",
               category: e.viajes, note: "Hotel", tag: e.etiqueta, date: date),
            tx(context, e, nativo: 1_000, divisa: "PEN", guardado: 1_000, guardadaEn: "PEN",
               category: e.sueldo, date: date),
            tx(context, e, nativo: 200, divisa: "USD", guardado: 200, guardadaEn: "USD",
               category: e.sueldo, date: date),
        ]
    }

    /// Las mismas filas de USD, ya recalculadas a soles.
    private func unaSolaDivisa(_ context: ModelContext, _ e: Escena, _ date: Date) -> [TransactionItem] {
        [
            tx(context, e, nativo: -100, divisa: "PEN", guardado: -100, guardadaEn: "PEN",
               category: e.comida, note: "Mercado", date: date),
            tx(context, e, nativo: -50, divisa: "USD", guardado: -185, guardadaEn: "PEN",
               category: e.viajes, note: "Hotel", tag: e.etiqueta, date: date),
            tx(context, e, nativo: 1_000, divisa: "PEN", guardado: 1_000, guardadaEn: "PEN",
               category: e.sueldo, date: date),
            tx(context, e, nativo: 200, divisa: "USD", guardado: 740, guardadaEn: "PEN",
               category: e.sueldo, date: date),
        ]
    }

    // MARK: - Sugerencias del chat

    private func sumasDelMes(
        _ txs: [TransactionItem], _ e: Escena, tasa: Decimal
    ) -> ChatSuggestionsLLMService.MonthSums {
        ChatSuggestionsLLMService.monthSums(
            txs,
            tagCatalog: Tag.byIDLookup([e.etiqueta]),
            currencyCode: "PEN",
            adjustment: .none,
            includeGroupTransactions: true,
            converter: MockCurrencyConverter(fixedRate: tasa)
        )
    }

    private func compruebaSumas(_ s: ChatSuggestionsLLMService.MonthSums) {
        #expect(cerca(s.totalExpense, 285), "gasto: \(s.totalExpense)")
        #expect(cerca(s.totalIncome, 1_740), "ingreso: \(s.totalIncome)")
        #expect(cerca(s.categories["Viajes"] ?? 0, 185), "Viajes: \(s.categories)")
        #expect(cerca(s.merchants[MerchantCanonicalizer.canonicalize("Hotel")] ?? 0, 185), "comercios: \(s.merchants)")
        #expect(cerca(s.tags["Vacaciones"] ?? 0, 185), "etiquetas: \(s.tags)")
        let ranking = s.categories.sorted { $0.value > $1.value }.map(\.key)
        #expect(ranking == ["Viajes", "Comida"], "ranking: \(ranking)")
    }

    @Test("Sugerencias: totales y rankings reconvierten las filas guardadas en otra divisa")
    func suggestions_mixedPreferredCurrencies_convertsBeforeSumming() throws {
        let context = try makeTestContext()
        let e = escena(context)
        compruebaSumas(sumasDelMes(mezcla(context, e, day(2026, 4, 10)), e, tasa: tasaUSD))
    }

    @Test("Sugerencias: con todo en la principal, se lee el monto guardado")
    func suggestions_singlePreferredCurrency_readsStoredAmounts() throws {
        let context = try makeTestContext()
        let e = escena(context)
        compruebaSumas(sumasDelMes(unaSolaDivisa(context, e, day(2026, 4, 10)), e, tasa: tasaAbsurda))
    }

    // MARK: - Salud financiera (ingreso de la carga de Compromisos)

    private var abril: DateInterval {
        let start = calendar.startOfDay(for: day(2026, 4, 1))
        let end = calendar.date(byAdding: DateComponents(month: 1, second: -1), to: start) ?? start
        return DateInterval(start: start, end: end)
    }

    private func ingreso(_ txs: [TransactionItem], tasa: Decimal) -> Double {
        FinancialScoreCalculator.sumIncomeTransactions(
            txs,
            interval: abril,
            currencyCode: "PEN",
            adjustment: .none,
            converter: MockCurrencyConverter(fixedRate: tasa)
        )
    }

    @Test("Salud financiera: el ingreso reconvierte las filas guardadas en otra divisa")
    func healthIncome_mixedPreferredCurrencies_convertsBeforeSumming() throws {
        let context = try makeTestContext()
        let e = escena(context)
        let total = ingreso(mezcla(context, e, day(2026, 4, 10)), tasa: tasaUSD)
        #expect(cerca(total, 1_740), "ingreso: \(total)")
    }

    @Test("Salud financiera: con todo en la principal, el ingreso lee el monto guardado")
    func healthIncome_singlePreferredCurrency_readsStoredAmounts() throws {
        let context = try makeTestContext()
        let e = escena(context)
        let total = ingreso(unaSolaDivisa(context, e, day(2026, 4, 10)), tasa: tasaAbsurda)
        #expect(cerca(total, 1_740), "ingreso: \(total)")
    }

    // MARK: - Pata real de un gasto de grupo (contexto de Yala IA y anomalías)

    /// Un gasto de grupo de 300 USD que pagué yo (mi parte: 100 USD), en la cuenta en soles, y un gasto
    /// en soles de 50 en la misma categoría. `guardadaEn` es la divisa principal con la que se guardaron
    /// las dos patas del grupo; en USD sin recalcular, el neto guardado (−100) está en dólares.
    /// Correcto: mi parte = 100 × 3,7 = 370; Comida = 50 + 370 = 420 (el viejo: 150).
    private func gastoDeGrupo(
        _ context: ModelContext, guardadaEn: String, date: Date
    ) -> (txs: [TransactionItem], comida: YalaCategory) {
        let principal = makeTestAccount(context: context, name: "Principal", currencyCode: "PEN")
        let grupos = makeTestAccount(context: context, name: "Grupos", currencyCode: "PEN")
        grupos.isSystemAccount = true
        let comida = makeTestCategory(context: context, name: "Comida")
        let prestamos = makeTestCategory(context: context, name: "SistemaGrupos", isIncome: true)
        let factor: Double = guardadaEn == "PEN" ? 3.7 : 1

        let real = TransactionItem(
            date: date, amount: -300, currencyCode: "USD", note: "Cena",
            category: comida, account: principal,
            amountInPreferredCurrency: -300 * factor, preferredCurrencyCode: guardadaEn
        )
        real.splitExpenseID = "gasto-de-grupo"
        let prestamo = TransactionItem(
            date: date, amount: 200, currencyCode: "USD", note: "Cena",
            category: prestamos, account: grupos,
            amountInPreferredCurrency: 200 * factor, preferredCurrencyCode: guardadaEn
        )
        prestamo.splitExpenseID = "gasto-de-grupo"
        let soles = TransactionItem(
            date: date, amount: -50, currencyCode: "PEN", note: "Mercado",
            category: comida, account: principal,
            amountInPreferredCurrency: -50, preferredCurrencyCode: "PEN"
        )
        for t in [real, prestamo, soles] { context.insert(t) }
        return ([real, prestamo, soles], comida)
    }

    private func comidaEnElContexto(_ txs: [TransactionItem], tasa: Decimal) -> Double? {
        let ctx = FullFinancialContextBuilder().buildFromArrays(
            transactions: txs,
            budgets: [],
            accounts: [],
            tags: [],
            scheduledPayments: [],
            currencyCode: "PEN",
            currencyDisplay: "S/",
            converter: MockCurrencyConverter(fixedRate: tasa),
            language: "es",
            country: "PE",
            includeAnomalies: false,
            adjustment: GroupBridgeStatsAdjustment.build(from: txs),
            now: day(2026, 4, 20)
        )
        return ctx.categories.first { $0.name == "Comida" }?.totalCurrentMonth
    }

    @Test("Contexto de Yala IA: la pata real de un gasto de grupo reconvierte mi parte")
    func aiContext_groupRealLeg_mixedPreferredCurrencies_converts() throws {
        let context = try makeTestContext()
        let g = gastoDeGrupo(context, guardadaEn: "USD", date: day(2026, 4, 10))
        let total = try #require(comidaEnElContexto(g.txs, tasa: tasaUSD))
        #expect(cerca(total, 420), "Comida: \(total)")
    }

    @Test("Contexto de Yala IA: con todo en la principal, mi parte es la guardada")
    func aiContext_groupRealLeg_singlePreferredCurrency_readsStoredAmounts() throws {
        let context = try makeTestContext()
        let g = gastoDeGrupo(context, guardadaEn: "PEN", date: day(2026, 4, 10))
        let total = try #require(comidaEnElContexto(g.txs, tasa: tasaAbsurda))
        #expect(cerca(total, 420), "Comida: \(total)")
    }

    /// Línea base: tres gastos de 30 en soles en marzo (media 30, umbral 60). En abril, la pata real del
    /// gasto de grupo (mi parte) es una anomalía de 370. La lectura vieja también la detecta (100 > 60),
    /// así que el caso discrimina por el IMPORTE y no por el umbral.
    private func anomalia(guardadaEn: String, tasa: Decimal) throws -> AnomalyEntry? {
        let context = try makeTestContext()
        let g = gastoDeGrupo(context, guardadaEn: guardadaEn, date: day(2026, 4, 10))
        let principal = try #require(g.txs.first?.account)
        let base = [3, 10, 17].map { d in
            let t = TransactionItem(
                date: day(2026, 3, d), amount: -30, currencyCode: "PEN", note: "Mercado",
                category: g.comida, account: principal,
                amountInPreferredCurrency: -30, preferredCurrencyCode: "PEN"
            )
            context.insert(t)
            return t
        }
        let periodo = g.txs.filter { $0.splitExpenseID != nil }
        let todas = base + g.txs
        return AnomalyDetectionCalculator.detect(
            allTransactions: todas,
            periodTransactions: periodo,
            interval: abril,
            currencyCode: "PEN",
            adjustment: GroupBridgeStatsAdjustment.build(from: todas),
            converter: MockCurrencyConverter(fixedRate: tasa)
        ).first
    }

    @Test("Anomalías: la pata real de un gasto de grupo reconvierte mi parte")
    func anomalies_groupRealLeg_mixedPreferredCurrencies_converts() throws {
        let hit = try #require(try anomalia(guardadaEn: "USD", tasa: tasaUSD))
        #expect(cerca(hit.amount, 370), "anomalía: \(hit.amount)")
    }

    @Test("Anomalías: con todo en la principal, mi parte es la guardada")
    func anomalies_groupRealLeg_singlePreferredCurrency_readsStoredAmounts() throws {
        let hit = try #require(try anomalia(guardadaEn: "PEN", tasa: tasaAbsurda))
        #expect(cerca(hit.amount, 370), "anomalía: \(hit.amount)")
    }
}
