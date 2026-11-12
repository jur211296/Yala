//
//  ImportTransfersByLanguageTests.swift
//  YalaTests
//
//  H2 de la auditoría del import 2.2 (card ynsq), de punta a punta: archivos sintéticos con transferencias
//  nombradas en cada idioma, ajustes de saldo en todos los idiomas y las subcategorías sembradas que siguen
//  siendo normales, por la ruta CSV de una cuenta y la de varias divisas. Las cifras de ingresos y gastos dejan fuera lo que lleva `balanceAdjustmentType`
//  (`balanceAdjustmentType == nil` en 48 sitios), así que el oráculo es ese campo.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("El import reconoce transferencias y ajustes en todos los idiomas", .serialized)
@MainActor
struct ImportTransfersByLanguageTests {

    /// El nombre que Yala da a sus transferencias en cada idioma (de los `.lproj`): los de ja, nl, pl,
    /// zh-Hans y pt son los que la auditoría vio fallar; el resto, el control de que siguen funcionando.
    private static let transferNamesUnderTest: [String] = {
        do {
            return try TransferNamesParityTests.localizedTransferNames().sorted()
        } catch {
            Issue.record("ImportTransfersByLanguageTests: Error: \(error)")
            return []
        }
    }()

    /// Subcategorías sembradas con nombre propio: siguen siendo movimientos normales al importar (decisión
    /// de Jürgen, 2026-10-29; «口座振替» es una domiciliación en japonés).
    private static let seededNamesThatStayNormal = ["Account transfer", "Kontoüberweisung", "口座振替"]

    @Test("CSV de una cuenta: transferencias de cada idioma y ajustes de todos los idiomas")
    func singleAccountCSV_marksTransfersAndAdjustments() async throws {
        let context = try makeTestContext()
        let account = makeAccount(currency: "PEN", in: context)
        try context.save()

        let url = try writeCSV(rows: Self.rows(currency: "PEN"))
        defer { removeFile(url) }

        _ = try await TransactionCSVImportService.importAndSave(in: context) {
            try await TransactionCSVImportService.importCSV(
                from: url, into: account, in: context, allowCreatingNewCategories: true)
        }

        try assertClassification(in: context)
    }

    @Test("CSV de varias divisas: la misma decisión")
    func multiCurrencyCSV_marksTransfersAndAdjustments() async throws {
        let context = try makeTestContext()
        let pen = makeAccount(currency: "PEN", in: context)
        let usd = makeAccount(currency: "USD", in: context)
        try context.save()

        let url = try writeCSV(rows: Self.rows(currency: "PEN") + Self.rows(currency: "USD"))
        defer { removeFile(url) }

        _ = try await TransactionCSVImportService.importAndSave(in: context) {
            try await TransactionCSVImportService.importCSVMultiCurrency(
                from: url, currencyAccountMap: ["PEN": pen, "USD": usd], in: context,
                allowCreatingNewCategories: true)
        }

        try assertClassification(in: context)
        let transactions = try context.fetch(FetchDescriptor<TransactionItem>())
        #expect(transactions.contains { $0.account?.persistentModelID == usd.persistentModelID })
    }

    // MARK: - Fixture

    /// Una transferencia de ida y vuelta por cada nombre, un ajuste por cada nombre de ajuste y una compra
    /// normal. Los ajustes van todos: con la regla vieja solo valía el del idioma en que corre el test, así
    /// que «Ajustes de saldo» con la app en inglés (o «Balance adjustment» con la app en español) salía
    /// como transferencia.
    private static func rows(currency: String) -> [String] {
        var rows: [String] = []
        for name in transferNamesUnderTest {
            rows.append("2026-10-14,-100.00,\(currency),Otros,\(name),,")
            rows.append("2026-10-14,100.00,\(currency),Ingresos,\(name),,")
        }
        for name in Subcategory.balanceAdjustmentNames.sorted() {
            rows.append("2026-10-15,25.00,\(currency),Otros,\(name),,")
        }
        rows.append("2026-10-16,-12.50,\(currency),Alimentación,Delivery,,")
        for name in seededNamesThatStayNormal {
            rows.append("2026-10-17,40.00,\(currency),Ingresos,\(name),,")
        }
        return rows
    }

    private func assertClassification(in context: ModelContext) throws {
        let transactions = try context.fetch(FetchDescriptor<TransactionItem>())
        let currencies = Set(transactions.map(\.currencyCode)).count
        #expect(Self.transferNamesUnderTest.count >= 10)
        let expected = Self.transferNamesUnderTest.count * 2 + Subcategory.balanceAdjustmentNames.count + 1
            + Self.seededNamesThatStayNormal.count
        #expect(transactions.count == expected * currencies)
        #expect(!context.hasChanges, "importAndSave deja el contexto guardado")

        for tx in transactions {
            let name = tx.subcategory?.name ?? "—"
            if Self.transferNamesUnderTest.contains(name) {
                #expect(tx.balanceAdjustmentType == TransactionItem.adjustmentTypeTransfer, "«\(name)» no es transferencia")
            } else if Subcategory.balanceAdjustmentNames.contains(name) {
                #expect(tx.balanceAdjustmentType == InitialBalanceService.typeAdjustment, "«\(name)» no es ajuste")
            } else {
                #expect(name == "Delivery" || Self.seededNamesThatStayNormal.contains(name))
                #expect(tx.balanceAdjustmentType == nil, "«\(name)» es un movimiento normal")
            }
        }
    }

    private func makeAccount(currency: String, in context: ModelContext) -> Account {
        let account = Account(
            name: "Cuenta \(currency)", currencyCode: currency, colorHex: "#6366F1", iconName: "creditcard",
            type: "general")
        context.insert(account)
        return account
    }

    private func writeCSV(rows: [String]) throws -> URL {
        let csv = (["date,amount,currency,category,subcategory,tags,note"] + rows).joined(separator: "\n")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("transferencias-\(UUID().uuidString).csv")
        try csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func removeFile(_ url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            Issue.record("ImportTransfersByLanguageTests: Error: \(error)")
        }
    }
}
