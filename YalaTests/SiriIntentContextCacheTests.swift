//
//  SiriIntentContextCacheTests.swift
//  YalaTests
//
//  Tests de la caché (App Group) del contexto que el intent de Siri lee para parsear sin tocar
//  SwiftData (subcategorías para el LLM + divisa + si hay cuentas). Ver SiriIntentContextCache.
//

import Foundation
import Testing

@testable import Yala

struct SiriIntentContextCacheTests {

    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "test.\(UUID().uuidString)")!
    }

    @Test func writeThenRead_roundTrips() {
        let defaults = makeDefaults()
        let ctx = SiriIntentContext(
            expenseSubcategories: ["Café", "Uber"],
            incomeSubcategories: ["Sueldo"],
            defaultCurrency: "PEN",
            hasRealAccount: true
        )
        SiriIntentContextCache.write(ctx, defaults: defaults)

        let read = SiriIntentContextCache.read(defaults: defaults)
        #expect(read?.expenseSubcategories == ["Café", "Uber"])
        #expect(read?.incomeSubcategories == ["Sueldo"])
        #expect(read?.defaultCurrency == "PEN")
        #expect(read?.hasRealAccount == true)
    }

    @Test func read_returnsNil_whenAbsent() {
        let defaults = makeDefaults()
        #expect(SiriIntentContextCache.read(defaults: defaults) == nil)
    }

    @Test func read_returnsNil_whenCorrupt() {
        let defaults = makeDefaults()
        defaults.set(Data([0x00, 0x01]), forKey: SiriIntentContextCache.storageKey)
        #expect(SiriIntentContextCache.read(defaults: defaults) == nil)
    }

    @Test func write_overwritesPrevious() {
        let defaults = makeDefaults()
        SiriIntentContextCache.write(
            SiriIntentContext(expenseSubcategories: ["A"], incomeSubcategories: [], defaultCurrency: "USD", hasRealAccount: false),
            defaults: defaults
        )
        SiriIntentContextCache.write(
            SiriIntentContext(expenseSubcategories: ["B"], incomeSubcategories: [], defaultCurrency: "EUR", hasRealAccount: true),
            defaults: defaults
        )

        let read = SiriIntentContextCache.read(defaults: defaults)
        #expect(read?.expenseSubcategories == ["B"])
        #expect(read?.defaultCurrency == "EUR")
        #expect(read?.hasRealAccount == true)
    }
}
