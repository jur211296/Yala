//
//  ApplePayPendingStoreTests.swift
//  YalaTests
//
//  Tests de la cola cross-launch (App Group, una key por pago) de gastos de Apple Pay que el
//  intent encola y la app materializa. Ver ApplePayPendingStore / ApplePayDraftService.
//

import Foundation
import Testing

@testable import Yala

struct ApplePayPendingStoreTests {

    /// UserDefaults aislado por test (regla del proyecto — nunca .standard).
    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "test.\(UUID().uuidString)")!
    }

    private func expense(_ raw: String, _ merchant: String? = nil, at t: Double = 1) -> ApplePayPendingExpense {
        ApplePayPendingExpense(rawAmount: raw, merchant: merchant, savedAt: t)
    }

    @Test func appendThenPeek_returnsItem() {
        let defaults = makeDefaults()
        let e = expense("$10", "Café")
        ApplePayPendingStore.append(e, defaults: defaults)

        let peeked = ApplePayPendingStore.peekAll(defaults: defaults)
        #expect(peeked.count == 1)
        #expect(peeked.first?.expense == e)
    }

    @Test func appendMultiple_sortedBySavedAt() {
        let defaults = makeDefaults()
        ApplePayPendingStore.append(expense("$30", "C", at: 3), defaults: defaults)
        ApplePayPendingStore.append(expense("$10", "A", at: 1), defaults: defaults)
        ApplePayPendingStore.append(expense("$20", "B", at: 2), defaults: defaults)

        let peeked = ApplePayPendingStore.peekAll(defaults: defaults)
        #expect(peeked.map(\.expense.rawAmount) == ["$10", "$20", "$30"])
    }

    /// peekAll NO consume: dos llamadas devuelven lo mismo (consume-after-save → sin pérdida si el
    /// save falla o el proceso muere antes de materializar).
    @Test func peekAll_doesNotConsume() {
        let defaults = makeDefaults()
        ApplePayPendingStore.append(expense("$10"), defaults: defaults)

        #expect(ApplePayPendingStore.peekAll(defaults: defaults).count == 1)
        #expect(ApplePayPendingStore.peekAll(defaults: defaults).count == 1)
    }

    /// remove borra SOLO las keys dadas (las materializadas tras un save exitoso).
    @Test func remove_deletesOnlyGivenKeys() {
        let defaults = makeDefaults()
        ApplePayPendingStore.append(expense("$10", at: 1), defaults: defaults)
        ApplePayPendingStore.append(expense("$20", at: 2), defaults: defaults)

        let peeked = ApplePayPendingStore.peekAll(defaults: defaults)
        ApplePayPendingStore.remove(keys: [peeked[0].key], defaults: defaults)

        let after = ApplePayPendingStore.peekAll(defaults: defaults)
        #expect(after.map(\.expense.rawAmount) == ["$20"])
    }

    @Test func peekAll_whenEmpty_returnsEmpty() {
        let defaults = makeDefaults()
        #expect(ApplePayPendingStore.peekAll(defaults: defaults).isEmpty)
    }

    /// Dato corrupto (no-JSON) bajo una key nuestra: peekAll lo descarta sin crashear ni ocultar
    /// los pagos válidos.
    @Test func corruptData_isDiscarded_validSurvives() {
        let defaults = makeDefaults()
        defaults.set(Data("no soy json".utf8), forKey: ApplePayPendingStore.keyPrefix + "corrupt")
        ApplePayPendingStore.append(expense("$10"), defaults: defaults)

        let peeked = ApplePayPendingStore.peekAll(defaults: defaults)
        #expect(peeked.count == 1)
        #expect(peeked.first?.expense.rawAmount == "$10")
    }

    /// Dos pagos con contenido idéntico se guardan por separado (key por `id` único), no se pisan
    /// entre sí — clave para no perder pagos repetidos hechos antes de abrir la app.
    @Test func sameContent_distinctIDs_bothKept() {
        let defaults = makeDefaults()
        ApplePayPendingStore.append(expense("$10", "A", at: 1), defaults: defaults)
        ApplePayPendingStore.append(expense("$10", "A", at: 1), defaults: defaults)

        #expect(ApplePayPendingStore.peekAll(defaults: defaults).count == 2)
    }
}
