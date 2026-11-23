//
//  ImportarLote1MedicionTests.swift
//  YalaTests
//
//  Mide cuánto tarda el import con miles de filas sintéticas (ticket `import-runs-twice-on-the-main-thread`, H14 de la
//  auditoría del import 2.2). No afirma tiempos: imprime `MEDIDA …` para el ticket. Va gateado con
//  `YALA_MEDIR_IMPORT=1` (`TEST_RUNNER_YALA_MEDIR_IMPORT=1` con xcodebuild) porque con 10.000 filas tarda.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Import · medición con miles de filas", .serialized)
@MainActor
struct ImportarLote1MedicionTests {

    nonisolated static var isEnabled: Bool {
        ProcessInfo.processInfo.environment["YALA_MEDIR_IMPORT"] == "1"
    }

    @Test(.enabled(if: ImportarLote1MedicionTests.isEnabled), arguments: [3_000, 10_000])
    func medir(rows: Int) async throws {
        let context = try makeTestContext()
        let account = Account(name: "Banco", currencyCode: "PEN", colorHex: "#6366F1", iconName: "creditcard",
                              type: "General")
        context.insert(account)
        for index in 0..<10 {
            let category = Yala.Category(name: "Cat \(index)", colorHex: "#22AA88", isIncome: index == 0)
            context.insert(category)
            for sub in 0..<3 { context.insert(Subcategory(name: "Sub \(index).\(sub)", category: category)) }
        }
        try context.save()

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("medir-\(UUID().uuidString).csv")
        try Self.csv(rows: rows).write(to: url, atomically: true, encoding: .utf8)
        defer {
            do { try FileManager.default.removeItem(at: url) } catch { Issue.record("medir: \(error)") }
        }

        let clock = ContinuousClock()
        var table: ImportTable?
        let readTime = try clock.measure { table = try ImportFileReader.readTable(from: url) }
        #expect(table?.rows.count == rows)

        // El camino de la app desde el 2026-11-22: la vista previa solo valida (no inserta); el import
        // reutiliza esa tabla y salta duplicados.
        var preview: ImportPreview?
        var prepared: ImportTable?
        let previewTime = try await clock.measure {
            let made = try await ImportPreviewService.previewAndTable(
                of: url, target: .single(account), allowCreatingNewCategories: true, container: context.container)
            preview = made.preview
            prepared = made.table
        }
        #expect(preview?.count == rows)

        var result: TransactionImportResult?
        let importTime = try await clock.measure {
            result = try await TransactionCSVImportService.importFile(
                from: url, destination: .account(account), in: context, allowCreatingNewCategories: true,
                skippingInvalidRows: true, skippingDuplicates: true, preparedTable: prepared)
        }
        let saveTime = try clock.measure { try context.save() }
        #expect(result?.createdCount == rows)

        // Reimportar el mismo archivo: la vista previa con todo duplicado.
        let reimportTime = try await clock.measure {
            let again = try await ImportPreviewService.preview(
                of: url, target: .single(account), allowCreatingNewCategories: true, container: context.container)
            #expect(again.duplicateCount == rows)
        }

        // Deshacer: borrar lo importado.
        // Deshacer de verdad, por tandas (`ImportUndoService`).
        var undone: ImportUndoOutcome?
        let undoTime = try await clock.measure {
            undone = try await ImportUndoService.undoInBatches(
                in: context, matching: try context.fetch(FetchDescriptor<TransactionItem>()))
        }
        #expect(undone?.deletedTransactions == rows)
        let undoSaveTime = Duration.zero
        print("MEDIDA import filas=\(rows) lectura=\(readTime) vistaPrevia=\(previewTime) importar=\(importTime) guardar=\(saveTime) "
              + "reimportarVistaPrevia=\(reimportTime) borrar=\(undoTime) guardarBorrado=\(undoSaveTime)")
    }

    /// Un CSV con la forma del caso real: dos años de fechas, diez categorías, etiquetas en una de cada diez filas.
    static func csv(rows: Int) -> String {
        var lines = ["date,amount,currency,category,subcategory,tags,note"]
        lines.reserveCapacity(rows + 1)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let start = calendar.date(from: DateComponents(year: 2024, month: 1, day: 1)) ?? .distantPast
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        for index in 0..<rows {
            let date = calendar.date(byAdding: .day, value: index % 700, to: start) ?? start
            let cat = index % 10
            let amount = cat == 0 ? "\(1000 + index % 500).50" : "-\(5 + index % 300).\(index % 100)"
            let tags = index % 10 == 0 ? "viaje;trabajo" : ""
            lines.append("\(formatter.string(from: date)),\(amount),PEN,Cat \(cat),Sub \(cat).\(index % 3),\(tags),Nota \(index)")
        }
        return lines.joined(separator: "\n")
    }
}
