//
//  CurrencyConverterLatestRateArrivalTests.swift
//  YalaTests
//
//  Card «La tasa de hoy que llega por iCloud o por la nube no se usa en "tasa de hoy" hasta medianoche» (ticket
//  `latest-rates-cache-ignores-rate-rows-from-the-mirror-and-the-pull`). La caché de la tasa de hoy solo se retiraba con
//  `.yalaExchangeRatesUpdated`, que no postean ni el espejo de iCloud ni el pull del Modo Nube. Ahora se retira con los
//  mismos avisos que la memoria de filas: cualquier guardado (`ModelContext.didSave`) y cualquier cambio del store
//  (`.NSPersistentStoreRemoteChange`, el único que oye un import del espejo).
//
//  Cada caso lleva su control: ANTES de la llegada, la conversión sale de la fila de ayer (aproximada). Con el arreglo
//  quitado, el primer caso sigue dando la tasa de ayer después de la llegada.
//

import CoreData
import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Converter · la fila de hoy que llega sin aviso de tasas se usa en la siguiente conversión", .serialized)
struct CurrencyConverterLatestRateArrivalTests {

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([ExchangeRate.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func makeContext(_ container: ModelContainer) -> ModelContext {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return context
    }

    private func insertRow(_ rates: [String: Double], on date: Date, into context: ModelContext) throws {
        let row = try ExchangeRate(dateKey: Self.dateFormatter.string(from: date), base: "USD", ratesDictionary: rates)
        context.insert(row)
    }

    /// El estado de antes de la llegada: ayer con PEN, hoy sin fila. La caché resuelve PEN con la fila de ayer
    /// (`carriedForward`) y la funde.
    private func seedYesterdayAndWarmTheCache(converter: CurrencyConverter, reader: ModelContext) throws {
        try insertRow(["USD": 1, "PEN": 3.0], on: Date.now.addingTimeInterval(-86_400), into: reader)
        try reader.save()
        let before = converter.convertCheckedWithLatestRate(100, from: "USD", to: "PEN", context: reader)
        #expect(before.amount == 300, "control: antes de la llegada sale la fila de ayer")
        #expect(!before.quality.isExact, "control: y marcada aproximada")
    }

    // MARK: - El pull del Modo Nube: otro contexto guarda la fila de hoy, sin aviso de tasas

    @Test func todaysRowSavedByAnotherContext_isUsedInTheNextConversion() throws {
        let container = try makeContainer()
        let reader = makeContext(container)
        let converter = CurrencyConverter()
        try seedYesterdayAndWarmTheCache(converter: converter, reader: reader)

        // El pull aplica su página en su propio contexto y guarda. Nadie postea `.yalaExchangeRatesUpdated`.
        let writer = makeContext(container)
        try insertRow(["USD": 1, "PEN": 3.8], on: Date.now, into: writer)
        try writer.save()

        let after = converter.convertCheckedWithLatestRate(100, from: "USD", to: "PEN", context: reader)
        #expect(after.amount == 380)
        #expect(after.quality == .exact)
        #expect(converter._testCacheState?["PEN"] == 3.8)

        // Las dos rutas de acuerdo tras la llegada (`currency-fx.md`).
        let byDate = converter.convertChecked(100, from: "USD", to: "PEN", on: Date.now, context: reader)
        #expect(byDate.amount == after.amount)
        #expect(byDate.quality == after.quality)
    }

    // MARK: - Cada aviso, por separado

    /// El import del espejo de iCloud no pasa por un `ModelContext`: lo único que se oye es el cambio del store.
    @Test func storeRemoteChange_dropsTheCache() throws {
        let container = try makeContainer()
        let reader = makeContext(container)
        let converter = CurrencyConverter()
        try seedYesterdayAndWarmTheCache(converter: converter, reader: reader)
        #expect(converter._testCacheState != nil, "control: la caché está llena")

        NotificationCenter.default.post(name: .NSPersistentStoreRemoteChange, object: nil)

        #expect(converter._testCacheState == nil)
    }

    @Test func anySave_dropsTheCache() throws {
        let container = try makeContainer()
        let reader = makeContext(container)
        let converter = CurrencyConverter()
        try seedYesterdayAndWarmTheCache(converter: converter, reader: reader)
        #expect(converter._testCacheState != nil, "control: la caché está llena")

        NotificationCenter.default.post(name: ModelContext.didSave, object: nil)

        #expect(converter._testCacheState == nil)
    }

    @Test func theRatesNotification_stillDropsTheCache() throws {
        let container = try makeContainer()
        let reader = makeContext(container)
        let converter = CurrencyConverter()
        try seedYesterdayAndWarmTheCache(converter: converter, reader: reader)
        #expect(converter._testCacheState != nil, "control: la caché está llena")

        NotificationCenter.default.post(name: .yalaExchangeRatesUpdated, object: nil)

        #expect(converter._testCacheState == nil)
    }
}
