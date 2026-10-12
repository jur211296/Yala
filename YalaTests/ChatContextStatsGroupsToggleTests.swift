//
//  ChatContextStatsGroupsToggleTests.swift
//  YalaTests
//
//  Card `el-contexto-de-yala-ia-suma-los-gastos-de-grupo` (hallazgo del PR #461). Con «Incluir gastos de
//  grupo en estadísticas» apagado, el Panel y Estadísticas dejan fuera los movimientos de grupo
//  (`BridgedTransactionFilter`), y el contexto de Yala IA (`FullFinancialContextBuilder`) seguía contando «mi
//  parte» de cada gasto de grupo en periodos, categorías y destacados: la IA citaba un gasto del mes mayor que el
//  del Panel. Ahora recibe el interruptor (`includeGroupTransactionsInStats`) y lo aplica como el Panel.
//
//  Escena (USD, tasa 1, a mitad de octubre). Pagué una cena de grupo de 300 de la que me tocan 100 (pata real
//  −300 en Principal, pata de préstamo +200 en la cuenta sistema de Grupos), cobré una liquidación de 40, compré
//  en el mercado por 50 y cobré un sueldo de 1.000.
//  - Interruptor apagado: gasto 50, ingreso 1.000; sin cena en categorías, comercios ni destacados.
//  - Interruptor encendido (hoy): gasto 150 (100 + 50), ingreso 1.040.
//  - Con el código viejo, apagado daba lo mismo que encendido: ese es el rojo.
//
//  La paridad se mide contra el filtro REAL de Estadísticas (`FilterService.filterForTrends`, el que aplica
//  `BridgedTransactionFilter` con el interruptor) y el `CashFlowCalculator` que usa el hero, y contra el resumen
//  de las sugerencias del chat (`ChatSuggestionsLLMService.monthSums`), que ya lo seguía desde #461.
//
//  Archivo propio: `makeTestContext()` reusa el store por `#fileID` (ver `testing.md`).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Contexto de Yala IA · interruptor de grupos de Estadísticas", .serialized)
struct ChatContextStatsGroupsToggleTests {

    private let calendar = Calendar.current

    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 15, hour: 12)) ?? .distantPast
    }

    private func day(_ d: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: d, hour: 12)) ?? .distantPast
    }

    private func cerca(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 0.001 }

    private struct Escena {
        let accounts: [Account]
        let txs: [TransactionItem]
    }

    private func escena(_ context: ModelContext) throws -> Escena {
        let principal = makeTestAccount(context: context, name: "Principal", currencyCode: "USD")
        let grupos = makeTestAccount(context: context, name: "Grupos", currencyCode: "USD")
        grupos.isSystemAccount = true
        let comida = makeTestCategory(context: context, name: "Comida")
        let sueldo = makeTestCategory(context: context, name: "Sueldo", isIncome: true)
        let prestamos = makeTestCategory(context: context, name: "Préstamo a grupos", isIncome: true)
        let cobros = makeTestCategory(context: context, name: "Cobros", isIncome: true)
        let restaurantes = makeTestSubcategory(context: context, name: "Restaurantes", category: comida)
        let mercado = makeTestSubcategory(context: context, name: "Mercado", category: comida)

        func fila(
            _ amount: Double, _ note: String, _ when: Date, _ category: YalaCategory, _ account: Account,
            _ sub: Subcategory? = nil
        ) -> TransactionItem {
            let t = TransactionItem(
                date: when, amount: amount, currencyCode: "USD", note: note,
                category: category, account: account,
                amountInPreferredCurrency: amount, preferredCurrencyCode: "USD"
            )
            t.subcategory = sub
            context.insert(t)
            return t
        }

        let real = fila(-300, "Cena", day(10), comida, principal, restaurantes)
        real.splitExpenseID = "cena-de-grupo"
        let prestamo = fila(200, "Cena", day(10), prestamos, grupos)
        prestamo.splitExpenseID = "cena-de-grupo"
        let liquidacion = fila(40, "Liquidación", day(12), cobros, principal)
        liquidacion.splitSettlementID = "liquidacion-1"

        let txs = [
            fila(-50, "Mercado", day(5), comida, principal, mercado),
            fila(1_000, "", day(1), sueldo, principal),
            real, prestamo, liquidacion,
        ]
        try context.save()
        return Escena(accounts: [principal, grupos], txs: txs)
    }

    private func contexto(_ e: Escena, includeGroupTransactionsInStats: Bool) -> FullFinancialContext {
        FullFinancialContextBuilder().buildFromArrays(
            transactions: e.txs,
            budgets: [],
            accounts: e.accounts,
            tags: [],
            scheduledPayments: [],
            currencyCode: "USD",
            currencyDisplay: "$",
            converter: MockCurrencyConverter(fixedRate: 1.0),
            language: "es",
            country: "US",
            includeAnomalies: false,
            includeGroupTransactionsInStats: includeGroupTransactionsInStats,
            adjustment: GroupBridgeStatsAdjustment.build(from: e.txs),
            now: now
        )
    }

    /// Lo que suma el hero del mes: el filtro de Estadísticas con el interruptor y `CashFlowCalculator` con el
    /// ajuste construido del conjunto crudo, como el Panel.
    private func panelMes(_ e: Escena, includeGroupTransactionsInStats: Bool) -> CashFlowSummary {
        let filtered = FilterService.filterForTrends(
            transactions: e.txs,
            accounts: e.accounts,
            criteria: FilterCriteria(),
            includeBridgedGroupTx: includeGroupTransactionsInStats
        )
        let month = calendar.dateInterval(of: .month, for: now) ?? DateInterval(start: now, end: now)
        let interval = DateInterval(start: month.start, end: now)
        return CashFlowCalculator.calculateCashFlow(
            transactions: filtered.filter { interval.contains($0.date) },
            interval: interval,
            grouping: .day,
            currencyCode: "USD",
            adjustment: GroupBridgeStatsAdjustment.build(from: e.txs),
            converter: MockCurrencyConverter(fixedRate: 1.0)
        )
    }

    private func sugerencias(_ e: Escena, includeGroupTransactions: Bool) -> ChatSuggestionsLLMService.MonthSums {
        ChatSuggestionsLLMService.monthSums(
            e.txs,
            tagCatalog: [:],
            currencyCode: "USD",
            adjustment: GroupBridgeStatsAdjustment.build(from: e.txs),
            includeGroupTransactions: includeGroupTransactions,
            converter: MockCurrencyConverter(fixedRate: 1.0)
        )
    }

    // MARK: - Apagado

    @Test("Apagado: el mes no cuenta los movimientos de grupo y cuadra con el Panel")
    func toggleOff_monthMatchesThePanel() throws {
        let e = try escena(try makeTestContext())

        let mes = contexto(e, includeGroupTransactionsInStats: false).periods.currentMonth
        let panel = panelMes(e, includeGroupTransactionsInStats: false)
        let resumen = sugerencias(e, includeGroupTransactions: false)

        #expect(cerca(mes.expense, 50), "gasto: \(mes.expense) (con el código viejo: 150)")
        #expect(cerca(mes.income, 1_000), "ingreso: \(mes.income) (con el código viejo: 1.040)")
        #expect(cerca(mes.expense, panel.totalExpense), "Panel: \(panel.totalExpense)")
        #expect(cerca(mes.income, panel.totalIncome), "Panel: \(panel.totalIncome)")
        #expect(cerca(mes.expense, resumen.totalExpense), "sugerencias: \(resumen.totalExpense)")
        #expect(cerca(mes.income, resumen.totalIncome), "sugerencias: \(resumen.totalIncome)")
        #expect(mes.txCount == 2, "movimientos: \(mes.txCount)")
        // El año en curso es otro periodo: tampoco los cuenta.
        let año = contexto(e, includeGroupTransactionsInStats: false).periods.currentYear
        #expect(cerca(año.expense, 50) && cerca(año.income, 1_000), "año: \(año.expense) / \(año.income)")
    }

    @Test("Apagado: categorías, comercios, destacados, patrones y sin categoría sin la cena de grupo")
    func toggleOff_breakdownsLeaveTheGroupExpenseOut() throws {
        let e = try escena(try makeTestContext())

        let ctx = contexto(e, includeGroupTransactionsInStats: false)

        let comida = try #require(ctx.categories.first { $0.name == "Comida" })
        #expect(cerca(comida.totalCurrentMonth, 50), "Comida: \(comida.totalCurrentMonth) (con el código viejo: 150)")
        #expect(comida.txCountCurrentMonth == 1)
        #expect(comida.subcategories.map(\.name) == ["Mercado"], "subcategorías: \(comida.subcategories.map(\.name))")
        #expect(!ctx.merchantsTop20.contains { $0.name == MerchantCanonicalizer.canonicalize("Cena") },
                "comercios: \(ctx.merchantsTop20.map(\.name))")
        #expect(ctx.topTxBySubcategory.map(\.subcategoryName) == ["Mercado"],
                "destacados: \(ctx.topTxBySubcategory.map(\.subcategoryName))")
        #expect(cerca(ctx.patterns.needsBreakdownCurrentMonth.total, 50),
                "necesidades: \(ctx.patterns.needsBreakdownCurrentMonth.total)")
        #expect(cerca(ctx.patterns.weekdayPattern30Days.reduce(0) { $0 + $1.total }, 50),
                "día de la semana: \(ctx.patterns.weekdayPattern30Days.map(\.total))")
    }

    // MARK: - Encendido (igual que hoy)

    @Test("Encendido: igual que hoy, cuenta mi parte de la cena y cuadra con el Panel")
    func toggleOn_countsMyShare_likeToday() throws {
        let e = try escena(try makeTestContext())

        let ctx = contexto(e, includeGroupTransactionsInStats: true)
        let porDefecto = FullFinancialContextBuilder().buildFromArrays(
            transactions: e.txs,
            budgets: [],
            accounts: e.accounts,
            tags: [],
            scheduledPayments: [],
            currencyCode: "USD",
            currencyDisplay: "$",
            converter: MockCurrencyConverter(fixedRate: 1.0),
            language: "es",
            country: "US",
            includeAnomalies: false,
            adjustment: GroupBridgeStatsAdjustment.build(from: e.txs),
            now: now
        )
        let panel = panelMes(e, includeGroupTransactionsInStats: true)

        #expect(cerca(ctx.periods.currentMonth.expense, 150), "gasto: \(ctx.periods.currentMonth.expense)")
        #expect(cerca(ctx.periods.currentMonth.income, 1_040), "ingreso: \(ctx.periods.currentMonth.income)")
        #expect(cerca(ctx.periods.currentMonth.expense, panel.totalExpense))
        #expect(cerca(ctx.periods.currentMonth.income, panel.totalIncome))
        let comida = try #require(ctx.categories.first { $0.name == "Comida" })
        #expect(cerca(comida.totalCurrentMonth, 150))
        let cena = try #require(ctx.topTxBySubcategory.first { $0.subcategoryName == "Restaurantes" })
        #expect(cena.transactions.map(\.amount) == [100], "mi parte: \(cena.transactions.map(\.amount))")
        // Sin pasar el interruptor, el default es el del ajuste (encendido): nada cambia para el golden ni los tests.
        #expect(porDefecto == ctx)
    }

    // MARK: - Caché

    @Test("La caché de 60 s no sirve el contexto calculado con el otro valor del interruptor")
    func cache_isKeyedByTheToggle() throws {
        let e = try escena(try makeTestContext())
        let builder = FullFinancialContextBuilder()

        func build(_ include: Bool) -> FullFinancialContext {
            builder.buildFromArrays(
                transactions: e.txs, budgets: [], accounts: e.accounts, tags: [], scheduledPayments: [],
                currencyCode: "USD", currencyDisplay: "$", converter: MockCurrencyConverter(fixedRate: 1.0),
                language: "es", country: "US", includeAnomalies: false,
                includeGroupTransactionsInStats: include,
                adjustment: GroupBridgeStatsAdjustment.build(from: e.txs), now: now
            )
        }

        #expect(cerca(build(true).periods.currentMonth.expense, 150))
        #expect(cerca(build(false).periods.currentMonth.expense, 50))
        #expect(cerca(build(true).periods.currentMonth.expense, 150))
    }
}

/// `runAskFlow` es privado y necesita red: se fija el cableado leyendo el fuente. Lo que cuenta es que el
/// interruptor se lea de la clave de Estadísticas, con default ON, y llegue al builder.
@Suite("Contexto de Yala IA · cableado del interruptor de grupos (source-scan)")
struct ChatContextStatsGroupsToggleWiringTests {

    private static func source(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: " ")
    }

    @Test("runAskFlow lee el interruptor de Estadísticas (default ON) y se lo pasa al builder")
    func runAskFlow_passesTheStatsToggle() throws {
        let src = try Self.source("Yala/Services/ChatAssistantService.swift")
        let start = try #require(src.range(of: "private func runAskFlow("))
        let end = try #require(src.range(of: "let systemPrompt = buildSystemPrompt(", range: start.upperBound..<src.endIndex))
        let body = String(src[start.upperBound..<end.lowerBound])

        #expect(body.contains(
            "includeGroupTransactionsInStats: (UserDefaults.standard.object( forKey: AppPreferences.Keys.includeGroupTransactionsInStats ) as? Bool) ?? true"
        ), "el builder recibe la clave de Estadísticas con default ON")
    }

    @Test("build(modelContext:) reenvía el interruptor a buildFromArrays")
    func build_forwardsTheToggle() throws {
        let src = try Self.source("Yala/Services/Chat/FullFinancialContextBuilder.swift")
        let start = try #require(src.range(of: "func build( modelContext: ModelContext,"))
        let end = try #require(src.range(of: "func buildFromArrays(", range: start.upperBound..<src.endIndex))
        let body = String(src[start.upperBound..<end.lowerBound])

        #expect(body.contains("includeGroupTransactionsInStats: includeGroupTransactionsInStats,"))
    }
}
