//
//  ImportFailureRollbackTests.swift
//  YalaTests
//
//  H6 de la auditoría del import 2.2 (card a27x): los dos `catch` de `ImportIntroSheet` cerraban la hoja sin
//  `rollback()`, y lo que el import ya había insertado (categorías, etiquetas, movimientos) se quedaba
//  pendiente en el contexto principal hasta que el siguiente `save()` de cualquier pantalla lo guardaba.
//  Ahora la hoja importa y guarda por `TransactionCSVImportService.importAndSave`, que deshace al fallar.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Un import que falla tras insertar no deja nada en el contexto", .serialized)
@MainActor
struct ImportFailureRollbackTests {

    private struct ForcedSaveFailure: Error {}

    @Test("Falla el guardado tras un import real: nada pendiente y nada en el store")
    func saveFailsAfterARealImport_leavesTheContextClean() async throws {
        let context = try makeTestContext()
        let account = Account(
            name: "Cuenta", currencyCode: "PEN", colorHex: "#6366F1", iconName: "creditcard", type: "general")
        context.insert(account)
        try context.save()
        let categoriesBefore = try context.fetchCount(FetchDescriptor<Yala.Category>())

        let url = try writeCSV()
        defer { removeFile(url) }

        var insertedBeforeTheFailure = 0
        await #expect(throws: ForcedSaveFailure.self) {
            _ = try await TransactionCSVImportService.importAndSave(
                in: context,
                save: { context in
                    // El import ya insertó: lo comprobamos justo antes de fallar.
                    insertedBeforeTheFailure = try context.fetchCount(FetchDescriptor<TransactionItem>())
                    throw ForcedSaveFailure()
                }
            ) {
                try await TransactionCSVImportService.importCSV(
                    from: url, into: account, in: context, allowCreatingNewCategories: true)
            }
        }

        #expect(insertedBeforeTheFailure == 2, "el fallo tiene que llegar después de insertar")
        #expect(!context.hasChanges)
        #expect(try context.fetchCount(FetchDescriptor<TransactionItem>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Yala.Category>()) == categoriesBefore)
        #expect(try context.fetchCount(FetchDescriptor<Yala.Tag>()) == 0)
    }

    @Test("Falla el propio import tras insertar: también se deshace")
    func importThrowsAfterInserting_leavesTheContextClean() async throws {
        let context = try makeTestContext()
        let category = Category(name: "Alimentación", colorHex: "#22C55E", isIncome: false)
        context.insert(category)
        try context.save()

        await #expect(throws: ForcedSaveFailure.self) {
            _ = try await TransactionCSVImportService.importAndSave(in: context) { () async throws -> Int in
                context.insert(Subcategory(name: "Delivery", category: category))
                context.insert(TransactionItem(
                    date: .now, amount: -10, currencyCode: "PEN", note: nil, category: category,
                    subcategory: nil, account: nil, tags: []))
                throw ForcedSaveFailure()
            }
        }

        #expect(!context.hasChanges)
        #expect(try context.fetchCount(FetchDescriptor<TransactionItem>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Subcategory>()) == 0)
    }

    /// El rollback solo deshace lo del import: lo que otra pantalla tenía pendiente se guarda antes de
    /// empezar. Con un `rollback()` a secas, la cuenta de este test desaparecía.
    @Test("Lo pendiente de otra pantalla sobrevive a un import que falla")
    func pendingChangesFromElsewhere_surviveAFailedImport() async throws {
        let context = try makeTestContext()
        let category = Category(name: "Alimentación", colorHex: "#22C55E", isIncome: false)
        context.insert(category)
        try context.save()
        // Otra pantalla deja algo sin guardar.
        context.insert(Account(
            name: "Pendiente", currencyCode: "PEN", colorHex: "#6366F1", iconName: "creditcard", type: "general"))
        category.name = "Comida"
        #expect(context.hasChanges)

        await #expect(throws: ForcedSaveFailure.self) {
            _ = try await TransactionCSVImportService.importAndSave(in: context) { () async throws -> Int in
                context.insert(Subcategory(name: "Delivery", category: category))
                throw ForcedSaveFailure()
            }
        }

        #expect(!context.hasChanges)
        #expect(try context.fetchCount(FetchDescriptor<Subcategory>()) == 0, "lo del import se deshace")
        #expect(try context.fetch(FetchDescriptor<Account>()).map(\.name) == ["Pendiente"])
        #expect(try context.fetch(FetchDescriptor<Yala.Category>()).map(\.name) == ["Comida"])
    }

    @Test("Sin fallo, guarda y devuelve el resultado")
    func success_savesAndReturnsTheResult() async throws {
        let context = try makeTestContext()
        let account = Account(
            name: "Cuenta", currencyCode: "PEN", colorHex: "#6366F1", iconName: "creditcard", type: "general")
        context.insert(account)
        try context.save()

        let url = try writeCSV()
        defer { removeFile(url) }

        let result = try await TransactionCSVImportService.importAndSave(in: context) {
            try await TransactionCSVImportService.importCSV(
                from: url, into: account, in: context, allowCreatingNewCategories: true)
        }

        #expect(result.createdCount == 2)
        #expect(!context.hasChanges)
        #expect(try context.fetchCount(FetchDescriptor<TransactionItem>()) == 2)
    }

    /// La hoja ya no guarda por su cuenta: las dos rutas pasan por `importAndSave`.
    @Test("ImportIntroSheet importa y guarda por importAndSave en sus dos rutas")
    func importSheet_usesImportAndSave() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(
            contentsOf: root.appendingPathComponent("Yala/App/Views/Import/ImportIntroSheet.swift"), encoding: .utf8)
        #expect(source.components(separatedBy: "TransactionCSVImportService.importAndSave(in: modelContext)").count - 1 == 2)
        #expect(!source.contains("try modelContext.save()"))
    }

    // MARK: - Fixture

    private func writeCSV() throws -> URL {
        let csv = """
            date,amount,currency,category,subcategory,tags,note
            2026-10-14,-50.00,PEN,Alimentación,Delivery,cena,
            2026-10-15,-20.00,PEN,Ocio,Cine,,
            """
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("import-falla-\(UUID().uuidString).csv")
        try csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func removeFile(_ url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            Issue.record("ImportFailureRollbackTests: Error: \(error)")
        }
    }
}
