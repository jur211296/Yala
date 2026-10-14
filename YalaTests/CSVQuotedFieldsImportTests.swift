//
//  CSVQuotedFieldsImportTests.swift
//  YalaTests
//
//  La plantilla CSV que genera Yala pone cada campo entre comillas, y el importador partía las filas
//  con un `split` por delimitador que dejaba las comillas pegadas: `"date"` no casaba con `date` y el
//  archivo oficial fallaba con «El encabezado del CSV no es válido» (auditoría UX 2.2, lote 7, B9).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("El importador CSV entiende campos entre comillas", .serialized)
@MainActor
struct CSVQuotedFieldsImportTests {

    // MARK: - Partir una fila

    @Test func splitsQuotedFields_withoutTheQuotes() {
        let fields = TransactionCSVImportService.splitCSVFields(
            #""2026-10-14","-50.00","PEN","Alimentación","Delivery","","""#, delimiter: ",")
        #expect(fields == ["2026-10-14", "-50.00", "PEN", "Alimentación", "Delivery", "", ""])
    }

    @Test func keepsTheDelimiterInsideQuotes() {
        let fields = TransactionCSVImportService.splitCSVFields(
            #"2026-10-14,"1,234.56",PEN,Hogar,Luz,,"cena, cine""#, delimiter: ",")
        #expect(fields == ["2026-10-14", "1,234.56", "PEN", "Hogar", "Luz", "", "cena, cine"])
    }

    @Test func doubledQuoteIsALiteralQuote() {
        let fields = TransactionCSVImportService.splitCSVFields(#""dijo ""hola""",x"#, delimiter: ",")
        #expect(fields == [#"dijo "hola""#, "x"])
    }

    /// Lo que ya funcionaba sin comillas sigue igual, incluidos los vacíos del final y una comilla
    /// suelta en medio de un campo, que no abre nada.
    @Test func unquotedRowsBehaveAsBefore() {
        let fields = TransactionCSVImportService.splitCSVFields(
            #"2026-10-14;-12;PEN;Ocio;Bar;;Pepe's "bar""#, delimiter: ";")
        #expect(fields == ["2026-10-14", "-12", "PEN", "Ocio", "Bar", "", #"Pepe's "bar""#])
        #expect(TransactionCSVImportService.splitCSVFields("a,,", delimiter: ",") == ["a", "", ""])
    }

    // MARK: - Encabezado

    /// El encabezado exacto que escribe `ImportIntroSheet.generateCSVText`.
    @Test func templateHeaderMatchesTheExpectedColumns() {
        let header = #""date","amount","currency","category","subcategory","tags","note""#
        #expect(
            TransactionCSVImportService.headerFields(header, delimiter: ",")
                == ["date", "amount", "currency", "category", "subcategory", "tags", "note"])
    }

    @Test func headerWithTrailingDelimitersStillMatches() {
        #expect(
            TransactionCSVImportService.headerFields("Date;Amount;Currency;Category;Subcategory;;", delimiter: ";")
                == ["date", "amount", "currency", "category", "subcategory"])
    }

    // MARK: - El archivo de la plantilla, de punta a punta

    @Test func scanCurrencies_readsQuotedCurrencyColumn() throws {
        let url = try writeTemplateCSV()
        defer { removeFile(url) }
        #expect(try TransactionCSVImportService.scanCurrencies(from: url) == ["PEN"])
    }

    @Test func importCSV_acceptsTheTemplateFormat() async throws {
        let context = try makeTestContext()
        let category = Category(name: "Alimentación", colorHex: "#22C55E", isIncome: false)
        context.insert(category)
        context.insert(Subcategory(name: "Delivery", category: category))
        context.insert(Subcategory(name: "Restaurantes", category: category))
        let account = Account(
            name: "Cuenta", currencyCode: "PEN", colorHex: "#6366F1", iconName: "creditcard", type: "general")
        context.insert(account)
        try context.save()

        let url = try writeTemplateCSV()
        defer { removeFile(url) }

        var created = 0
        let result = try await TransactionCSVImportService.importCSV(
            from: url, into: account, in: context, allowCreatingNewCategories: false
        ) { _, _ in created += 1 }

        #expect(result.createdCount == 2)
        #expect(created == 2)
        #expect(result.drafts.map(\.note) == [nil, "con, coma"])
    }

    /// Mismo formato que la plantilla: todo entre comillas, separador coma.
    private func writeTemplateCSV() throws -> URL {
        let csv = """
            "date","amount","currency","category","subcategory","tags","note"
            "2026-01-14","-50.00","PEN","Alimentación","Delivery","",""
            "2026-01-15","-1,234.56","PEN","Alimentación","Restaurantes","","con, coma"
            """
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("plantilla-\(UUID().uuidString).csv")
        try csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func removeFile(_ url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            Issue.record("CSVQuotedFieldsImportTests: Error: \(error)")
        }
    }
}
