//
//  ExportRecordsCountTests.swift
//  YalaTests
//
//  L20-2: la cifra de «Saldrán N registros» sale del MISMO fetch y los mismos filtros que la exportación, y el filtro de
//  necesidad, que el asistente pintaba sin pasarlo, ahora recorta. L20-4: el archivo se llama «Yala_Registros_<fecha>».
//  Archivo propio: `makeTestContext()` reusa el store por `#fileID` (ver `testing.md`).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite(.serialized)
struct ExportRecordsCountTests {

    private func seed(_ context: ModelContext) throws -> [TransactionItem] {
        let now = Date.now
        let txs = [
            TransactionItem(date: now, amount: -10, currencyCode: "PEN", note: "taxi al aeropuerto"),
            TransactionItem(date: now, amount: -20, currencyCode: "PEN", note: "cena"),
            TransactionItem(date: now.addingTimeInterval(-86_400 * 400), amount: -30, currencyCode: "USD", note: "viejo"),
        ]
        txs[0].needOverride = SubcategoryNeed.essential.rawValue
        txs[1].needOverride = SubcategoryNeed.optional.rawValue
        txs.forEach(context.insert)
        try context.save()
        return txs
    }

    @Test func matchingCount_isWhatTheExportWouldWrite() throws {
        let context = try makeTestContext()
        _ = try seed(context)

        var everything = ExportFilters.allTransactions
        #expect(try TransactionsExportService.matchingCount(using: everything, in: context) == 3)

        everything.noteContains = "TAXI"
        #expect(try TransactionsExportService.matchingCount(using: everything, in: context) == 1)

        everything.noteContains = "no existe"
        #expect(try TransactionsExportService.matchingCount(using: everything, in: context) == 0, """
            Una nota que no casa: la cifra dice cero ANTES de tocar «Exportar» (L20-2).
            """)
        #expect(throws: TransactionsExportError.self) {
            _ = try TransactionsExportService.export(format: .csv, using: everything, columns: .default, in: context,
                                                     scheduleTagBackfill: false)
        }
    }

    @Test func matchingCount_respectsThePeriod() throws {
        let context = try makeTestContext()
        _ = try seed(context)
        let thisMonth = DetailPeriod.thisMonth.dateInterval()
        var filters = ExportFilters.allTransactions
        filters.dateFrom = thisMonth.start
        filters.dateTo = thisMonth.end
        #expect(try TransactionsExportService.matchingCount(using: filters, in: context) == 2)
    }

    @Test func needsFilter_narrows_andHidingInverts() throws {
        let context = try makeTestContext()
        _ = try seed(context)
        var filters = ExportFilters.allTransactions
        filters.selectedNeeds = [.essential]
        #expect(try TransactionsExportService.matchingCount(using: filters, in: context) == 1)
        filters.isExcludeMode = true
        #expect(try TransactionsExportService.matchingCount(using: filters, in: context) == 2,
                "Con «Ocultar», la necesidad elegida se quita y el resto se queda.")
        filters.selectedNeeds = []
        filters.isExcludeMode = false
        #expect(try TransactionsExportService.matchingCount(using: filters, in: context) == 3,
                "Sin necesidades elegidas no hay filtro.")
    }

    @Test func exportedFile_isNamedWithRecordsAndAReadableDate() throws {
        let context = try makeTestContext()
        _ = try seed(context)
        let result = try TransactionsExportService.export(
            format: .xlsx, using: .allTransactions, columns: .default, in: context, scheduleTagBackfill: false)
        let name = result.fileURL.lastPathComponent
        #expect(name.hasPrefix("Yala_\(ExportRecordsLogic.sanitizedForFileName(L10n.UXL20D.fileStem))_"), "\(name)")
        #expect(name.hasSuffix(".xlsx"))
        #expect(!name.contains("Transacciones"))
        #expect(result.exportedCount == 3)
    }
}
