//
//  ImportarLote1DeshacerTests.swift
//  YalaTests
//
//  «Deshacer importación» (H12 de la auditoría del import 2.2, ticket `import-cannot-be-undone`): importar y deshacer
//  deja la base como estaba —movimientos, categorías y etiquetas creadas por el import, y la fecha del saldo inicial—,
//  y lo creado que ya se usa se queda.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Importar lote 1 · deshacer un import", .serialized)
@MainActor
struct ImportarLote1DeshacerTests {

    private static let header = "date,amount,currency,category,subcategory,tags,note"

    /// Cada test con su fichero de registro, y el de producción intacto.
    private func withUndoFile(_ body: () async throws -> Void) async throws {
        let previous = ImportUndoService.fileURL
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("undo-\(UUID().uuidString)")
        ImportUndoService.fileURL = dir.appendingPathComponent("ultimo.json")
        defer {
            ImportUndoService.fileURL = previous
            do { try FileManager.default.removeItem(at: dir) } catch { /* puede no existir */ }
        }
        try await body()
    }

    private func setUp() throws -> (ModelContext, Account) {
        let context = try makeTestContext()
        let banco = Account(name: "Banco", currencyCode: "PEN", colorHex: "#6366F1", iconName: "creditcard",
                            type: "General")
        context.insert(banco)
        let comida = Yala.Category(name: "Comida", colorHex: "#22AA88", isIncome: false)
        context.insert(comida)
        context.insert(Subcategory(name: "Café", category: comida))
        try context.save()
        return (context, banco)
    }

    private func importLines(_ lines: [String], into account: Account, in context: ModelContext) async throws
        -> TransactionImportResult {
        let table = try ImportFileReader.parseCSV(([Self.header] + lines).joined(separator: "\n"))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("no-se-lee.csv")
        return try await ImportUndoService.importAndRemember(in: context) {
            try await TransactionCSVImportService.importFile(
                from: url, destination: .account(account), in: context, allowCreatingNewCategories: true,
                skippingInvalidRows: true, skippingDuplicates: true, preparedTable: table)
        }
    }

    private func counts(_ context: ModelContext) throws -> (tx: Int, categories: Int, subcategories: Int, tags: Int) {
        (try context.fetchCount(FetchDescriptor<TransactionItem>()),
         try context.fetchCount(FetchDescriptor<Yala.Category>()),
         try context.fetchCount(FetchDescriptor<Subcategory>()),
         try context.fetchCount(FetchDescriptor<Yala.Tag>()))
    }

    @Test("Importar y deshacer deja movimientos, categorías, subcategorías y etiquetas como estaban")
    func undoRestoresEverything() async throws {
        try await withUndoFile {
            let (context, banco) = try setUp()
            let before = try counts(context)
            let result = try await importLines([
                "2026-10-03,-10,PEN,Comida,Café,viaje,Café",
                "2026-10-04,-40,PEN,Hogar,Limpieza,viaje;casa,",
                "2026-10-05,-15,PEN,Comida,Panadería,,",
            ], into: banco, in: context)
            #expect(result.createdCount == 3)
            let record = try #require(ImportUndoService.current())
            #expect(record.count == 3)
            #expect(try counts(context).tx == before.tx + 3)

            let outcome = try await ImportUndoService.undo(in: context)
            #expect(outcome.deletedTransactions == 3)
            #expect(outcome.deletedTags == 2)
            let after = try counts(context)
            #expect(after.tx == before.tx)
            #expect(after.categories == before.categories)
            #expect(after.subcategories == before.subcategories)
            #expect(after.tags == before.tags)
            #expect(ImportUndoService.current() == nil, "Deshecho, ya no se ofrece.")
        }
    }

    @Test("Lo creado que ya usa otra cosa se queda: una etiqueta puesta a mano en otro movimiento")
    func usedTagStays() async throws {
        try await withUndoFile {
            let (context, banco) = try setUp()
            _ = try await importLines(["2026-10-03,-10,PEN,Comida,Café,viaje,"], into: banco, in: context)
            let tag = try #require(try context.fetch(FetchDescriptor<Yala.Tag>()).first { $0.name == "viaje" })
            let manual = TransactionItem(date: .now, amount: -5, currencyCode: "PEN")
            manual.account = banco
            manual.tags = [tag]
            context.insert(manual)
            try context.save()

            let outcome = try await ImportUndoService.undo(in: context)
            #expect(outcome.deletedTransactions == 1)
            #expect(outcome.deletedTags == 0)
            #expect(try context.fetch(FetchDescriptor<Yala.Tag>()).contains { $0.name == "viaje" })
            #expect(try context.fetchCount(FetchDescriptor<TransactionItem>()) == 1)
        }
    }

    @Test("La fecha del saldo inicial que el import retrocedió vuelve a la de antes")
    func initialBalanceDateIsRestored() async throws {
        try await withUndoFile {
            let (context, banco) = try setUp()
            let saldo = TransactionItem(date: Date(timeIntervalSince1970: 1_780_000_000), amount: 100, currencyCode: "PEN")
            saldo.account = banco
            saldo.balanceAdjustmentType = "initial_balance"
            context.insert(saldo)
            try context.save()
            let initial = try #require(InitialBalanceService.findInitialBalanceTransaction(for: banco, in: context))
            let original = initial.date

            let result = try await importLines(["2020-01-05,-10,PEN,Comida,Café,,"], into: banco, in: context)
            #expect(result.initialBalanceChanges.count == 1)
            #expect(initial.date < original)

            try await ImportUndoService.undo(in: context)
            let restored = try #require(InitialBalanceService.findInitialBalanceTransaction(for: banco, in: context))
            #expect(restored.date == original)
        }
    }

    @Test("Pasadas 24 h ya no se ofrece ni se deshace")
    func expiresAfterADay() async throws {
        try await withUndoFile {
            let (context, banco) = try setUp()
            _ = try await importLines(["2026-10-03,-10,PEN,Comida,Café,,"], into: banco, in: context)
            let later = Date.now.addingTimeInterval(25 * 60 * 60)
            #expect(ImportUndoService.current(now: later) == nil)
            await #expect(throws: ImportUndoService.UndoError.nothingToUndo) {
                try await ImportUndoService.undo(in: context, now: later)
            }
            #expect(try context.fetchCount(FetchDescriptor<TransactionItem>()) == 1)
        }
    }

    @Test("Un import que no crea nada (todo duplicado) no sustituye al que se puede deshacer")
    func emptyImportKeepsThePreviousRecord() async throws {
        try await withUndoFile {
            let (context, banco) = try setUp()
            let lines = ["2026-10-03,-10,PEN,Comida,Café,,"]
            _ = try await importLines(lines, into: banco, in: context)
            let first = try #require(ImportUndoService.current())
            let again = try await importLines(lines, into: banco, in: context)
            #expect(again.createdCount == 0)
            #expect(ImportUndoService.current() == first)
        }
    }
}
