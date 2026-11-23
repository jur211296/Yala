//
//  TasasDeCambioLimpiezaTests.swift
//  YalaTests / TasasDeCambioLote
//
//  La limpieza diaria de `ExchangeRateService`: funde las copias de un día que traen identidad (la regla de «Activar la
//  nube», superviviente el menor `syncID`), deja las que no la traen y borra las claves que escribió otro calendario.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Tasas de cambio · la limpieza funde copias y borra claves imposibles", .serialized)
struct TasasDeCambioLimpiezaTests {

    private func insert(_ context: ModelContext, key: String, ts: TimeInterval?, sid: String?,
                        _ rates: [String: Double]) throws {
        let row = try ExchangeRate(dateKey: key, base: "USD", ratesDictionary: rates,
                                   timestamp: ts.map { Date(timeIntervalSince1970: $0) })
        row.syncID = sid.flatMap(UUID.init(uuidString:))
        context.insert(row)
    }

    private func rows(_ context: ModelContext, key: String) throws -> [ExchangeRate] {
        try context.fetch(FetchDescriptor<ExchangeRate>(predicate: #Predicate { $0.dateKey == key }))
    }

    private let sidA = "00000000-0000-0000-0000-00000000000A"
    private let sidB = "00000000-0000-0000-0000-00000000000B"
    private let sidC = "00000000-0000-0000-0000-00000000000C"

    @Test func copiesWithIdentity_fuseIntoTheSmallestSyncID() throws {
        let context = try makeTestContext()
        try insert(context, key: "2026-11-20", ts: 300, sid: sidC, ["USD": 1, "EUR": 0.95])
        try insert(context, key: "2026-11-20", ts: 100, sid: sidA, ["USD": 1, "EUR": 0.80, "PEN": 3.7])
        try insert(context, key: "2026-11-20", ts: 200, sid: sidB, ["USD": 1, "JPY": 150])
        try insert(context, key: "2026-11-21", ts: 100, sid: sidB, ["USD": 1])
        try context.save()

        let removed = try ExchangeRateService(provider: SilentRateProvider())
            .cleanUpStoredRates(currentYear: 2026, context: context)

        #expect(removed == 2)
        let left = try rows(context, key: "2026-11-20")
        #expect(left.count == 1)
        let survivor = try #require(left.first)
        #expect(survivor.syncID == UUID(uuidString: sidA))
        #expect(survivor.decodedRates() == ["USD": 1, "EUR": 0.95, "PEN": 3.7, "JPY": 150])
        #expect(survivor.timestamp == Date(timeIntervalSince1970: 300))
        #expect(try rows(context, key: "2026-11-21").count == 1)
    }

    /// Leer el día antes y después de limpiar da lo mismo: un 0 de la copia nueva no pisa la tasa buena de la vieja.
    @Test func anUnusableRateInTheNewerCopy_doesNotReplaceTheGoodOne() throws {
        let context = try makeTestContext()
        try insert(context, key: "2026-11-20", ts: 100, sid: sidA, ["USD": 1, "JPY": 150])
        try insert(context, key: "2026-11-20", ts: 200, sid: sidB, ["USD": 1, "JPY": 0, "EUR": 0.9])
        try context.save()

        try ExchangeRateService(provider: SilentRateProvider()).cleanUpStoredRates(currentYear: 2026, context: context)

        let survivor = try #require(try rows(context, key: "2026-11-20").first)
        #expect(survivor.decodedRates() == ["USD": 1, "JPY": 150, "EUR": 0.9])
    }

    @Test func copiesWithoutIdentity_areLeftAlone() throws {
        let context = try makeTestContext()
        try insert(context, key: "2026-11-20", ts: 100, sid: nil, ["USD": 1, "EUR": 0.80])
        try insert(context, key: "2026-11-20", ts: 200, sid: nil, ["USD": 1, "EUR": 0.95])
        try context.save()

        let removed = try ExchangeRateService(provider: SilentRateProvider())
            .cleanUpStoredRates(currentYear: 2026, context: context)

        #expect(removed == 0)
        #expect(try rows(context, key: "2026-11-20").count == 2)
    }

    /// Un día con copias con y sin identidad no se funde: fundir las que tienen `syncID` cambiaría lo que se lee.
    @Test func aDayMixingCopiesWithAndWithoutIdentity_isLeftAlone() throws {
        let context = try makeTestContext()
        try insert(context, key: "2026-11-20", ts: 100, sid: sidA, ["USD": 1, "EUR": 0.80])
        try insert(context, key: "2026-11-20", ts: 150, sid: nil, ["USD": 1, "EUR": 0.85])
        try insert(context, key: "2026-11-20", ts: 200, sid: sidB, ["USD": 1])
        try context.save()

        let removed = try ExchangeRateService(provider: SilentRateProvider())
            .cleanUpStoredRates(currentYear: 2026, context: context)

        #expect(removed == 0)
        #expect(try rows(context, key: "2026-11-20").count == 3)
    }

    @Test func keysFromAnotherCalendar_areDeleted() throws {
        let context = try makeTestContext()
        try insert(context, key: "2569-11-22", ts: nil, sid: sidA, ["USD": 1])
        try insert(context, key: "0008-11-22", ts: nil, sid: nil, ["USD": 1])
        try insert(context, key: "2026-11-22", ts: nil, sid: sidB, ["USD": 1])
        try context.save()

        let removed = try ExchangeRateService(provider: SilentRateProvider())
            .cleanUpStoredRates(currentYear: 2026, context: context)

        #expect(removed == 2)
        let keys = try context.fetch(FetchDescriptor<ExchangeRate>()).map(\.dateKey)
        #expect(keys == ["2026-11-22"])
    }

    @Test func nothingToCleanUp_doesNotTouchTheStore() throws {
        let context = try makeTestContext()
        try insert(context, key: "2026-11-20", ts: 100, sid: sidA, ["USD": 1, "EUR": 0.9])
        try context.save()

        let removed = try ExchangeRateService(provider: SilentRateProvider())
            .cleanUpStoredRates(currentYear: 2026, context: context)

        #expect(removed == 0)
        #expect(!context.hasChanges)
    }
}

/// No toca la red: la limpieza no pide nada.
@MainActor
private final class SilentRateProvider: ExchangeRateProviderProtocol {
    func fetchLatest(base: String, symbols: [String]) async throws -> LiveRateResult {
        LiveRateResult(rates: [:], timestamp: nil)
    }

    func fetchTimeseries(
        base: String, symbols: [String], startDate: Date, endDate: Date
    ) async throws -> [String: [String: Double]] {
        [:]
    }
}
