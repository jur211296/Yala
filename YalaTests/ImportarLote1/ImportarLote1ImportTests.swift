//
//  ImportarLote1ImportTests.swift
//  YalaTests
//
//  El lote 1 de Importar registros de punta a punta (22-nov-2026): reimportar no duplica (H11), las fechas se leen por
//  archivo y al mediodía local (H10), las transferencias se emparejan mirando la cuenta y el cambio de moneda (H9) y la
//  vista previa ya no crea los movimientos para tirarlos (H14).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Importar lote 1 · de punta a punta", .serialized)
@MainActor
struct ImportarLote1ImportTests {

    nonisolated private static let lima = TimeZone(identifier: "America/Lima") ?? .gmt
    private static let now: Date = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = lima
        return calendar.date(from: DateComponents(year: 2026, month: 11, day: 22, hour: 20)) ?? .distantPast
    }()

    private static let header = "date,amount,currency,category,subcategory,tags,note"

    private func setUp() throws -> (ModelContext, Account) {
        let context = try makeTestContext()
        let banco = account("Banco", "PEN", in: context)
        let comida = Yala.Category(name: "Comida", colorHex: "#22AA88", isIncome: false)
        context.insert(comida)
        context.insert(Subcategory(name: "Café", category: comida))
        try context.save()
        return (context, banco)
    }

    @discardableResult
    private func account(_ name: String, _ currency: String, in context: ModelContext) -> Account {
        let account = Account(name: name, currencyCode: currency, colorHex: "#6366F1", iconName: "creditcard",
                              type: "General")
        context.insert(account)
        return account
    }

    private func table(_ lines: [String]) throws -> ImportTable {
        try ImportFileReader.parseCSV(([Self.header] + lines).joined(separator: "\n"))
    }

    private func run(
        _ lines: [String], destination: ImportDestination, in context: ModelContext, skippingDuplicates: Bool = true,
        timeZone: TimeZone = lima, locale: Locale = Locale(identifier: "es_PE"), inserts: Bool = true
    ) throws -> TransactionImportResult {
        let result = try TransactionCSVImportService.importTable(
            try table(lines), destination: destination, in: context, allowCreatingNewCategories: true,
            skippingInvalidRows: true, skippingDuplicates: skippingDuplicates, insertsTransactions: inserts,
            locale: locale, timeZone: timeZone, now: Self.now)
        if inserts { try context.save() }
        return result
    }

    private func count(_ context: ModelContext) throws -> Int {
        try context.fetchCount(FetchDescriptor<TransactionItem>())
    }

    // MARK: - Duplicados (H11)

    @Test("Importar dos veces el mismo archivo: la segunda vez todas las filas son duplicados y no entra nada")
    func reimportSkipsEverything() throws {
        let (context, banco) = try setUp()
        let lines = ["2026-10-03,-10,PEN,Comida,Café,,Café", "2026-10-03,-10,PEN,Comida,Café,,Café",
                     "2026-10-04,-25.50,PEN,Comida,Café,,"]
        let first = try run(lines, destination: .account(banco), in: context)
        #expect(first.createdCount == 3, "Dos cafés iguales en un archivo nuevo entran los dos.")
        #expect(first.duplicateRowNumbers.isEmpty)

        let second = try run(lines, destination: .account(banco), in: context)
        #expect(second.duplicateRowNumbers == [2, 3, 4])
        #expect(second.skippedDuplicateCount == 3)
        #expect(second.createdCount == 0)
        #expect(try count(context) == 3)
    }

    @Test("«Importarlos igual» los importa; y un archivo con un café más solo trae ese")
    func importAnywayAndPartialOverlap() throws {
        let (context, banco) = try setUp()
        _ = try run(["2026-10-03,-10,PEN,Comida,Café,,Café"], destination: .account(banco), in: context)

        let lines = ["2026-10-03,-10,PEN,Comida,Café,,Café", "2026-10-03,-10,PEN,Comida,Café,,Café"]
        let skipping = try run(lines, destination: .account(banco), in: context, inserts: false)
        #expect(skipping.duplicateRowNumbers == [2])
        #expect(skipping.createdCount == 1)

        let anyway = try run(lines, destination: .account(banco), in: context, skippingDuplicates: false)
        #expect(anyway.duplicateRowNumbers == [2])
        #expect(anyway.createdCount == 2)
        #expect(try count(context) == 3)
    }

    @Test("El mismo movimiento en otra cuenta no es duplicado")
    func otherAccountIsNotADuplicate() throws {
        let (context, banco) = try setUp()
        let caja = account("Caja", "PEN", in: context)
        _ = try run(["2026-10-03,-10,PEN,Comida,Café,,Café"], destination: .account(banco), in: context)
        let result = try run(["2026-10-03,-10,PEN,Comida,Café,,Café"], destination: .account(caja), in: context)
        #expect(result.duplicateRowNumbers.isEmpty)
        #expect(result.createdCount == 1)
    }

    // MARK: - Fechas (H10)

    @Test("Un archivo de EE. UU.: 03/04/2026 entra el 4 de marzo porque otra fila trae un 15 de día")
    func usFileByFile() throws {
        let (context, banco) = try setUp()
        let result = try run(["03/04/2026,-10,PEN,Comida,Café,,", "03/15/2026,-10,PEN,Comida,Café,,"],
                             destination: .account(banco), in: context)
        #expect(result.createdCount == 2)
        #expect(result.dateDecision?.order == .monthFirst)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Self.lima
        let days = result.drafts.map { calendar.dateComponents([.month, .day], from: $0.date) }
        #expect(days.map(\.month) == [3, 3])
        #expect(days.map(\.day) == [4, 15])
    }

    @Test("Una fecha importada en Pacific/Auckland se ve el mismo día")
    func aucklandSameDay() throws {
        let (context, banco) = try setUp()
        let auckland = TimeZone(identifier: "Pacific/Auckland") ?? .gmt
        let result = try run(["2026-10-27,-10,PEN,Comida,Café,,"], destination: .account(banco), in: context,
                             timeZone: auckland)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = auckland
        let draft = try #require(result.drafts.first)
        #expect(calendar.component(.day, from: draft.date) == 27)
        #expect(calendar.component(.hour, from: draft.date) == 12)
    }

    @Test("Hoy sin hora no es futuro aunque aún no sea mediodía; mañana sí")
    func futureIsByDay() throws {
        let (context, banco) = try setUp()
        let result = try run(["2026-11-22,-10,PEN,Comida,Café,,", "2026-11-23,-10,PEN,Comida,Café,,"],
                             destination: .account(banco), in: context)
        #expect(result.createdCount == 1)
        #expect(result.ignoredFutureDatesCount == 1)
    }

    // MARK: - Transferencias (H9)

    @Test("PEN → USD el mismo día, por moneda a dos cuentas: las dos patas quedan emparejadas")
    func currencyChangeTransferPairs() throws {
        let (context, banco) = try setUp()
        let dolares = account("Dólares", "USD", in: context)
        try context.save()
        let result = try run([
            "2026-10-03,-375,PEN,Otros,Transferencia entre cuentas,,",
            "2026-10-03,100,USD,Otros,Transferencia entre cuentas,,",
        ], destination: .byCurrency(["PEN": banco, "USD": dolares]), in: context)
        #expect(result.createdCount == 2)
        #expect(result.looseTransferCount == 0)
        let transfers = try context.fetch(FetchDescriptor<TransactionItem>())
        let pairIDs = Set(transfers.compactMap(\.transferPairID))
        #expect(transfers.count == 2)
        #expect(pairIDs.count == 1)
    }

    @Test("Dos patas de la misma cuenta quedan sueltas y la vista previa lo dice")
    func sameAccountLegsStayLoose() throws {
        let (context, banco) = try setUp()
        let preview = try run([
            "2026-10-03,-100,PEN,Otros,Transferencia entre cuentas,,",
            "2026-10-03,100,PEN,Otros,Transferencia entre cuentas,,",
        ], destination: .account(banco), in: context, inserts: false)
        #expect(preview.looseTransferCount == 2)
        let made = ImportPreviewLogic.make(result: preview, existingBillableAccounts: 1)
        #expect(made.looseTransferCount == 2)
    }

    // MARK: - Vista previa sin insertar (H14)

    @Test("La vista previa valida sin crear movimientos, y cuenta lo mismo que el import")
    func previewDoesNotInsert() throws {
        let (context, banco) = try setUp()
        let lines = ["2026-10-03,-10,PEN,Comida,Café,viaje,", "2026-10-04,-12,PEN,Comida,Nueva,,"]
        let preview = try run(lines, destination: .account(banco), in: context, inserts: false)
        let inserted = context.insertedModelsArray.compactMap { $0 as? TransactionItem }
        #expect(inserted.isEmpty)
        #expect(preview.createdCount == 2)
        #expect(preview.accountNames == ["Banco"])
        context.rollback()

        let result = try run(lines, destination: .account(banco), in: context)
        #expect(result.createdCount == preview.createdCount)
        #expect(try count(context) == 2)
    }
}
