//
//  ChatSuggestionsMerchantNameTests.swift
//  YalaTests
//
//  Card «Las sugerencias del saludo de Yala IA escriben los comercios en mayúsculas» (lote 12.4). El resumen del mes
//  agrupa los comercios por su canónico (`MerchantCanonicalizer.canonicalize`, en MAYÚSCULAS) y mandaba ese canónico al
//  prompt de `chat.suggestions`; el modelo lo copiaba: «¿Cómo se comparan mis gastos de SUPERMERCADO y MERCADO?».
//  Ahora se agrupa igual pero se manda la forma visible más frecuente.
//
//  Archivo propio: `makeTestContext()` reusa el store por `#fileID` (ver `testing.md`).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Sugerencias del chat · nombre visible del comercio", .serialized)
struct ChatSuggestionsMerchantNameTests {

    // MARK: - La forma visible de una nota

    @Test(arguments: [
        ("SUPERMERCADO", "Supermercado"),
        ("mercado central", "Mercado Central"),
        ("Starbucks Coffee", "Starbucks Coffee"),
        ("DP*Starbucks", "Starbucks"),
        ("KFC", "KFC"),
        ("BCP", "BCP"),
        ("  uber   eats ", "Uber Eats"),
        ("iPhone Store", "iPhone Store"),
        ("ÉXITO", "Éxito"),
    ])
    func displayName(_ note: String, _ expected: String) {
        #expect(MerchantCanonicalizer.displayName(for: note) == expected)
    }

    // MARK: - El resumen manda la forma visible, no el canónico

    @Test func monthSums_keepGroupingByCanonical_andExposeTheVisibleName() throws {
        let context = try makeTestContext()
        let cuenta = makeTestAccount(context: context, name: "Principal", currencyCode: "PEN")
        let comida = makeTestCategory(context: context, name: "Comida")
        let fecha = Date(timeIntervalSince1970: 1_775_000_000)
        func fila(_ amount: Double, _ note: String) -> TransactionItem {
            let t = TransactionItem(
                date: fecha, amount: amount, currencyCode: "PEN", note: note, category: comida, account: cuenta,
                amountInPreferredCurrency: amount, preferredCurrencyCode: "PEN"
            )
            context.insert(t)
            return t
        }
        let txs = [fila(-40, "Supermercado"), fila(-30, "Supermercado"), fila(-20, "SUPERMERCADO"), fila(-10, "KFC")]
        try context.save()

        let sums = ChatSuggestionsLLMService.monthSums(
            txs, tagCatalog: [:], currencyCode: "PEN", adjustment: .none, includeGroupTransactions: true,
            converter: MockCurrencyConverter(fixedRate: 1)
        )

        // Se sigue agrupando por el canónico: las tres notas son el mismo comercio.
        #expect(abs((sums.merchants["SUPERMERCADO"] ?? 0) - 90) < 0.001, "comercios: \(sums.merchants)")
        // Y lo que va al prompt es la forma que más se repite.
        #expect(sums.displayName(forMerchant: "SUPERMERCADO") == "Supermercado")
        #expect(sums.displayName(forMerchant: "KFC") == "KFC")
        // Un canónico sin notas (no debería pasar) se devuelve tal cual, nunca vacío.
        #expect(sums.displayName(forMerchant: "OTRO") == "OTRO")
    }

    @Test func displayName_tieIsDeterministic() {
        var sums = ChatSuggestionsLLMService.MonthSums()
        sums.merchantSpellings["TAMBO"] = ["Tambo": 2, "TAMBO+": 2]
        #expect(sums.displayName(forMerchant: "TAMBO") == "TAMBO+")
        sums.merchantSpellings["TAMBO"] = ["Tambo": 3, "TAMBO+": 2]
        #expect(sums.displayName(forMerchant: "TAMBO") == "Tambo")
    }

    // MARK: - El cableado: buildContext manda `displayName`, no la clave del diccionario

    @Test func buildContext_mapsTheTopMerchantsThroughTheVisibleName() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Yala/App/Services/ChatSuggestionsLLMService.swift")
        let source = try String(contentsOf: url, encoding: .utf8)
        #expect(source.contains("merchantNames = sums.merchants.sorted { $0.value > $1.value }.prefix(10)"))
        #expect(source.contains(".map { sums.displayName(forMerchant: $0.key) }"))
        #expect(!source.contains("merchantNames = sums.merchants.sorted { $0.value > $1.value }.prefix(10).map(\\.key)"))
    }
}
