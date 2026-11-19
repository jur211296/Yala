//
//  CuelguesFixture.swift
//  YalaTests / CuelguesHeroWidget
//
//  El almacén de las dos suites de Sentry YALA-IOS-N y YALA-IOS-M: un historial con las filas que separan las reglas de
//  ingreso y gasto (con categoría de cada lado, sin categoría de cada signo y una devolución en una categoría de gasto),
//  repartido entre este mes, el anterior y los de antes.
//

import Foundation
import SwiftData

@testable import Yala

@MainActor
enum CuelguesFixture {

    static func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("Cuelgues-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func makeContainer(_ dir: URL) throws -> ModelContainer {
        let personal = ModelConfiguration("CU-Personal", schema: SwiftDataConfiguration.personalSchema,
                                          url: dir.appendingPathComponent("p.sqlite"), cloudKitDatabase: .none)
        let groups = ModelConfiguration("CU-Groups", schema: SwiftDataConfiguration.groupsSchema,
                                        url: dir.appendingPathComponent("g.sqlite"), cloudKitDatabase: .none)
        let meta = ModelConfiguration("CU-Meta", schema: SwiftDataConfiguration.syncMetaSchema,
                                      url: dir.appendingPathComponent("m.sqlite"), cloudKitDatabase: .none)
        return try ModelContainer(for: SwiftDataConfiguration.schema, configurations: personal, groups, meta)
    }

    /// `count` movimientos, del más nuevo (`now`) hacia atrás, uno cada `spacing` segundos.
    static func seed(_ container: ModelContainer, count: Int, now: Date, spacing: TimeInterval = 7_200) throws {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let account = Account(name: "A", currencyCode: "PEN", colorHex: "#000000", iconName: "x", type: "cash")
        context.insert(account)
        let food = Category(name: "Comida", colorHex: "#FF0000", isIncome: false)
        let salary = Category(name: "Sueldo", colorHex: "#00FF00", isIncome: true)
        context.insert(food)
        context.insert(salary)
        for i in 0..<count {
            let category: Yala.Category?
            let value: Double
            switch i % 7 {
            case 0: category = salary; value = 2_500 + Double(i % 13)
            case 1: category = food; value = 30 + Double(i % 11)        // devolución en una categoría de gasto
            case 2: category = nil; value = 40 + Double(i % 5)          // sin categoría, positivo: ingreso
            case 3: category = nil; value = -(15 + Double(i % 9))       // sin categoría, negativo: gasto
            default: category = food; value = -(10 + Double(i % 90))
            }
            let tx = TransactionItem(date: now.addingTimeInterval(-Double(i) * spacing), amount: value,
                                     currencyCode: "PEN", category: category, account: account,
                                     amountInPreferredCurrency: value, preferredCurrencyCode: "PEN")
            tx.createdAt = tx.date
            context.insert(tx)
        }
        try context.save()
    }

    static func allTransactions(_ context: ModelContext) throws -> [TransactionItem] {
        try context.fetch(FetchDescriptor<TransactionItem>(sortBy: [
            SortDescriptor(\.date, order: .reverse), SortDescriptor(\.createdAt, order: .reverse)
        ]))
    }

    /// El bloque más largo que el hilo principal pasó sin atender a otra tarea mientras `isBusy` siga en `true`, y
    /// cuántas veces la atendió. Un cálculo que no cede da un bloque del tamaño del cálculo entero.
    static func measureMainThread(while isBusy: () -> Bool, timeout: Duration = .seconds(60)) async throws
        -> (longest: Duration, turns: Int) {
        let clock = ContinuousClock()
        var longest: Duration = .zero
        var turns = 0
        var last = clock.now
        let deadline = clock.now + timeout
        while isBusy() && clock.now < deadline {
            try await Task.sleep(for: .milliseconds(1))
            let now = clock.now
            longest = max(longest, now - last)
            last = now
            turns += 1
        }
        return (longest, turns)
    }
}
