//
//  ChatSuggestionsGroupExpenseTests.swift
//  YalaTests
//
//  Ticket `chat-suggestions-context-counts-the-whole-group-expense`. El resumen del mes con el que se
//  generan las sugerencias del chat (`ChatSuggestionsLLMService.monthSums`) sumaba un gasto de grupo
//  ENTERO y su pata de préstamo como ingreso, y no seguía el interruptor de grupos de Estadísticas.
//  Ahora cuenta como el hero del Panel: «mi parte», sin el préstamo, y nada de grupos con el
//  interruptor apagado.
//
//  Escena (divisa principal PEN, tasa absurda: nada se convierte). Pagué una cena de grupo de S/ 300
//  de la que me tocan S/ 100 (pata real −300, pata de préstamo +200 en la cuenta sistema de Grupos),
//  más un mercado de S/ 50 y un sueldo de S/ 1.000.
//  - Correcto: gasto 150 (100 + 50), ingreso 1.000, Comida 150, «Cena» 100.
//  - Con `adjustment: .none` (el código viejo): gasto 350, ingreso 1.200, Comida 350, «Cena» 300.
//
//  Archivo propio: `makeTestContext()` reusa el store por `#fileID` (ver `testing.md`).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Sugerencias del chat · gasto de grupo", .serialized)
struct ChatSuggestionsGroupExpenseTests {

    private let fecha = Date(timeIntervalSince1970: 1_775_000_000)
    private let tasaAbsurda: Decimal = 1_000

    private func cerca(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 0.001 }

    private func escena(_ context: ModelContext, conGrupo: Bool = true) throws -> [TransactionItem] {
        let principal = makeTestAccount(context: context, name: "Principal", currencyCode: "PEN")
        let grupos = makeTestAccount(context: context, name: "Grupos", currencyCode: "PEN")
        grupos.isSystemAccount = true
        let comida = makeTestCategory(context: context, name: "Comida")
        let sueldo = makeTestCategory(context: context, name: "Sueldo", isIncome: true)
        let prestamos = makeTestCategory(context: context, name: "Préstamo a grupos", isIncome: true)

        func fila(_ amount: Double, _ note: String, _ category: YalaCategory, _ account: Account) -> TransactionItem {
            let t = TransactionItem(
                date: fecha, amount: amount, currencyCode: "PEN", note: note,
                category: category, account: account,
                amountInPreferredCurrency: amount, preferredCurrencyCode: "PEN"
            )
            context.insert(t)
            return t
        }

        var txs = [
            fila(-50, "Mercado", comida, principal),
            fila(1_000, "", sueldo, principal),
        ]
        if conGrupo {
            let real = fila(-300, "Cena", comida, principal)
            real.splitExpenseID = "cena-de-grupo"
            let prestamo = fila(200, "Cena", prestamos, grupos)
            prestamo.splitExpenseID = "cena-de-grupo"
            txs += [real, prestamo]
        }
        try context.save()
        return txs
    }

    private func sumas(
        _ txs: [TransactionItem],
        adjustment: GroupBridgeStatsAdjustment,
        includeGroupTransactions: Bool = true
    ) -> ChatSuggestionsLLMService.MonthSums {
        ChatSuggestionsLLMService.monthSums(
            txs,
            tagCatalog: [:],
            currencyCode: "PEN",
            adjustment: adjustment,
            includeGroupTransactions: includeGroupTransactions,
            converter: MockCurrencyConverter(fixedRate: tasaAbsurda)
        )
    }

    @Test("Gasto de grupo: suma mi parte y el préstamo no es ingreso")
    func groupExpense_countsMyShare_andTheLoanIsNotIncome() throws {
        let context = try makeTestContext()
        let txs = try escena(context)

        let s = sumas(txs, adjustment: GroupBridgeStatsAdjustment.build(from: txs))

        #expect(cerca(s.totalExpense, 150), "gasto: \(s.totalExpense) (con el bug: 350)")
        #expect(cerca(s.totalIncome, 1_000), "ingreso: \(s.totalIncome) (con el bug: 1.200)")
        #expect(cerca(s.categories["Comida"] ?? 0, 150), "Comida: \(s.categories)")
        #expect(s.categories["Préstamo a grupos"] == nil, "categorías: \(s.categories)")
        #expect(cerca(s.merchants[MerchantCanonicalizer.canonicalize("Cena")] ?? 0, 100), "comercios: \(s.merchants)")
    }

    @Test("Interruptor de grupos apagado: el gasto de grupo no entra en el resumen")
    func groupsToggleOff_leavesTheGroupExpenseOut() throws {
        let context = try makeTestContext()
        let txs = try escena(context)

        let s = sumas(
            txs, adjustment: GroupBridgeStatsAdjustment.build(from: txs), includeGroupTransactions: false
        )

        #expect(cerca(s.totalExpense, 50), "gasto: \(s.totalExpense)")
        #expect(cerca(s.totalIncome, 1_000), "ingreso: \(s.totalIncome)")
        #expect(s.merchants[MerchantCanonicalizer.canonicalize("Cena")] == nil, "comercios: \(s.merchants)")
    }

    @Test("Control: sin gastos de grupo, el ajuste no cambia nada")
    func withoutGroupExpenses_theAdjustmentIsIdentity() throws {
        let context = try makeTestContext()
        let txs = try escena(context, conGrupo: false)

        let conAjuste = sumas(txs, adjustment: GroupBridgeStatsAdjustment.build(from: txs))
        let sinAjuste = sumas(txs, adjustment: .none)

        #expect(cerca(conAjuste.totalExpense, 50) && cerca(sinAjuste.totalExpense, 50))
        #expect(cerca(conAjuste.totalIncome, 1_000) && cerca(sinAjuste.totalIncome, 1_000))
        #expect(conAjuste.categories == sinAjuste.categories)
    }
}

/// `buildContext` es privado y necesita un `ModelContext` real: se fija el cableado leyendo el fuente.
/// Lo que cuenta es que el ajuste se construya con el fetch CRUDO (antes del filtro de cuentas) y que
/// llegue a `monthSums` junto con el interruptor de Estadísticas.
@Suite("Sugerencias del chat · cableado del ajuste de grupos (source-scan)")
struct ChatSuggestionsGroupExpenseWiringTests {

    private static func source(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    @Test("buildContext construye el ajuste del fetch crudo y lo pasa con el interruptor")
    func buildContext_wiresTheAdjustmentAndTheToggle() throws {
        let src = try Self.source("Yala/App/Services/ChatSuggestionsLLMService.swift")
        let start = try #require(src.range(of: "private func buildContext("))
        let end = try #require(src.range(of: "FetchDescriptor<Budget>()", range: start.upperBound..<src.endIndex))
        let body = String(src[start.upperBound..<end.lowerBound])

        let build = try #require(body.range(of: "GroupBridgeStatsAdjustment.build(from: monthTxs, context: modelContext)"))
        let filtro = try #require(body.range(of: "let txs = monthTxs.filter"))
        #expect(build.lowerBound < filtro.lowerBound, "el ajuste se construye ANTES de filtrar cuentas")
        #expect(body.contains("adjustment: adjustment,"))
        #expect(body.contains("forKey: AppPreferences.Keys.includeGroupTransactionsInStats"))
        #expect(body.contains(") as? Bool) ?? true,"), "el default del interruptor es ON, como el Panel")
        #expect(!body.contains("includeGroupTransactions: !"))
        #expect(!body.contains("adjustment: .none"))
    }
}
