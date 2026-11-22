//
//  RecurringChangesSourceTests.swift
//  YalaTests
//
//  S2 de pagos recurrentes con el almacén: el fixture de QA `-uitest-seed-s2-changes` produce los dos avisos que pinta
//  Pagos planificados, y lo que no es un cobro (ingresos, transferencias, grupos) no entra. Archivo propio porque usa
//  `makeTestContext()` (`testing.md`: la segunda suite de un archivo con contexto va aparte).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Pagos recurrentes S2 · con el almacén", .serialized)
@MainActor
struct RecurringChangesSourceTests {

    @Test("El fixture de QA da «Disney+ subió» y «¿Dejaste de pagar Spotify?»")
    func fixture_producesBothChanges() throws {
        let context = try makeTestContext()
        _ = makeTestAccount(context: context, name: "Débito", currencyCode: "PEN")
        try context.save()
        let now = Date.now
        DevSeedRecurringChanges.create(in: context, now: now)
        let items = try RecurringChangesSource.load(context: context, now: now)
        let byName = Dictionary(items.map { ($0.payment.name, $0.change.kind) }, uniquingKeysWith: { first, _ in first })
        #expect(byName["Disney+"] == .priceChanged(newAmount: 44.90, increased: true))
        if case .stopped? = byName["Spotify"] {} else { Issue.record("Spotify: \(String(describing: byName["Spotify"]))") }
        #expect(items.count == 2)
    }
}
