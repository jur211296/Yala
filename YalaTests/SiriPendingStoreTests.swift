//
//  SiriPendingStoreTests.swift
//  YalaTests
//
//  Tests de la cola cross-launch (App Group, una key por dictado) de dictados de Siri que el
//  intent encola y la app materializa. Ver SiriPendingStore / SiriDraftService.
//

import Foundation
import Testing

@testable import Yala

struct SiriPendingStoreTests {

    /// UserDefaults aislado por test (regla del proyecto — nunca .standard).
    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "test.\(UUID().uuidString)")!
    }

    private func parsed(_ amount: Decimal?, note: String = "café", isExpense: Bool = true) -> ParsedTransaction {
        ParsedTransaction(
            amount: amount,
            date: nil,
            note: note,
            isExpense: isExpense,
            subcategoryHint: nil,
            tagHints: [],
            currencyHint: nil,
            confidence: ParsedTransaction.TransactionConfidence(amount: 1, date: 0, merchant: 0, subcategory: 0, tags: 0)
        )
    }

    private func entry(_ raw: String, _ txs: [ParsedTransaction], at t: Double = 1) -> SiriPendingEntry {
        SiriPendingEntry(rawText: raw, transactions: txs, savedAt: t)
    }

    @Test func appendThenPeek_returnsEntry() {
        let defaults = makeDefaults()
        let e = entry("50 en café", [parsed(50)])
        SiriPendingStore.append(e, defaults: defaults)

        let peeked = SiriPendingStore.peekAll(defaults: defaults)
        #expect(peeked.count == 1)
        #expect(peeked.first?.entry == e)
    }

    @Test func appendMultiple_sortedBySavedAt() {
        let defaults = makeDefaults()
        SiriPendingStore.append(entry("C", [parsed(30)], at: 3), defaults: defaults)
        SiriPendingStore.append(entry("A", [parsed(10)], at: 1), defaults: defaults)
        SiriPendingStore.append(entry("B", [parsed(20)], at: 2), defaults: defaults)

        let peeked = SiriPendingStore.peekAll(defaults: defaults)
        #expect(peeked.map(\.entry.rawText) == ["A", "B", "C"])
    }

    @Test func remove_deletesOnlyGivenKeys() {
        let defaults = makeDefaults()
        SiriPendingStore.append(entry("A", [parsed(10)], at: 1), defaults: defaults)
        SiriPendingStore.append(entry("B", [parsed(20)], at: 2), defaults: defaults)

        let all = SiriPendingStore.peekAll(defaults: defaults)
        let keyOfA = all.first { $0.entry.rawText == "A" }!.key
        SiriPendingStore.remove(keys: [keyOfA], defaults: defaults)

        let remaining = SiriPendingStore.peekAll(defaults: defaults)
        #expect(remaining.count == 1)
        #expect(remaining.first?.entry.rawText == "B")
    }

    @Test func peekAll_discardsCorruptData() {
        let defaults = makeDefaults()
        SiriPendingStore.append(entry("ok", [parsed(10)]), defaults: defaults)
        // Corrupto: Data no-decodable bajo una key con nuestro prefijo.
        defaults.set(Data([0x00, 0x01]), forKey: SiriPendingStore.keyPrefix + "corrupt")

        let peeked = SiriPendingStore.peekAll(defaults: defaults)
        #expect(peeked.count == 1)   // solo la buena; la corrupta se descartó
        #expect(defaults.data(forKey: SiriPendingStore.keyPrefix + "corrupt") == nil)
    }

    @Test func multipleTransactionsPerEntry_preserved() {
        let defaults = makeDefaults()
        let e = entry("50 en café y 100 en uber", [parsed(50, note: "café"), parsed(100, note: "uber")])
        SiriPendingStore.append(e, defaults: defaults)

        let peeked = SiriPendingStore.peekAll(defaults: defaults)
        #expect(peeked.first?.entry.transactions.count == 2)
        #expect(peeked.first?.entry.transactions.map(\.note) == ["café", "uber"])
    }

    /// El `amount` (Decimal) debe sobrevivir el JSON de la cola sin corromper el Double final que
    /// consume la app (`SiriDraftService` hace `NSDecimalNumber(decimal:).doubleValue`).
    @Test func decimalPrecision_roundTrips() {
        for amountStr in ["32.04", "0.1", "1234.56", "0.01", "999999.99"] {
            let defaults = makeDefaults()
            let amount = Decimal(string: amountStr)!
            SiriPendingStore.append(entry("x", [parsed(amount)]), defaults: defaults)

            let decoded = SiriPendingStore.peekAll(defaults: defaults).first!.entry.transactions.first!.amount!
            #expect(
                NSDecimalNumber(decimal: decoded).doubleValue == NSDecimalNumber(decimal: amount).doubleValue,
                "amount \(amountStr) se corrompió en el round-trip JSON"
            )
        }
    }
}
