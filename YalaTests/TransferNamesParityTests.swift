//
//  TransferNamesParityTests.swift
//  YalaTests
//
//  H2 de la auditoría del import 2.2 (card ynsq): el import marca una fila como transferencia si su
//  subcategoría es de sistema, y eso lo decide su NOMBRE contra `Subcategory.transferNames`. Faltaban los
//  nombres de ja, nl, pl, zh-Hans y pt, así que en esos idiomas una transferencia importada contaba como
//  gasto e ingreso. Y el ajuste se reconocía con el texto del idioma ACTUAL: «Ajustes de saldo» importado
//  con el teléfono en inglés salía como transferencia.
//

import Foundation
import Testing

@testable import Yala

@Suite("Los nombres de transferencia y ajuste cubren los 16 idiomas")
@MainActor
struct TransferNamesParityTests {

    nonisolated private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    nonisolated static func tables() throws -> [(locale: String, table: [String: String])] {
        let resources = repoRoot.appendingPathComponent("Yala/Resources")
        let locales = try FileManager.default.contentsOfDirectory(atPath: resources.path)
            .filter { $0.hasSuffix(".lproj") }
            .sorted()
        return try locales.map { locale in
            let url = resources.appendingPathComponent("\(locale)/Localizable.strings")
            let table = try #require(NSDictionary(contentsOf: url) as? [String: String], "\(locale)")
            return (locale, table)
        }
    }

    /// Los nombres que Yala da a sus transferencias, leídos de los `.lproj` (no de la lista que se prueba).
    nonisolated static func localizedTransferNames() throws -> Set<String> {
        Set(try tables().compactMap { $0.table["transfer.categoryName"] })
    }

    @Test("El nombre de transferencia de cada .lproj está en transferNames")
    func everyLocalizedTransferName_isInTheList() throws {
        let tables = try Self.tables()
        #expect(tables.count == 16)
        for (locale, table) in tables {
            let name = try #require(table["transfer.categoryName"], "\(locale)")
            #expect(Subcategory.transferNames.contains(name), "\(locale): «\(name)» no está en la lista")
        }
    }

    /// Decisión de Jürgen (2026-10-29): las subcategorías sembradas solo son de sistema donde su texto
    /// coincide con el de las transferencias de Yala. En en, de, nl, ja y zh siguen siendo normales.
    @Test("Las subcategorías sembradas de transferencia no entran con su propio nombre")
    func seededTransferNames_areSystemOnlyWhereTheyMatchTheAppsTransferName() throws {
        let appNames = try Self.localizedTransferNames()
        var stayNormal: Set<String> = []
        for (locale, table) in try Self.tables() {
            for key in ["subcategory.accountTransfer", "subcategory.accountTransferOther"] {
                let name = try #require(table[key], "\(locale): falta \(key)")
                #expect(
                    Subcategory.transferNames.contains(name) == appNames.contains(name),
                    "\(locale): «\(name)» (\(key))")
                if !appNames.contains(name) { stayNormal.insert(name) }
            }
        }
        // Control: el caso existe (si un día coincidieran todos, este test no probaría nada).
        #expect(stayNormal.isSuperset(of: ["Account transfer", "Kontoüberweisung", "口座振替"]))
    }

    @Test("Ninguna lista pisa a la otra")
    func transferAndAdjustmentLists_doNotOverlap() {
        #expect(Subcategory.transferNames.isDisjoint(with: Subcategory.balanceAdjustmentNames))
    }

    // MARK: - El único punto de decisión

    @Test("Un ajuste de saldo en cualquier idioma es ajuste, sea cual sea el idioma de la app")
    func adjustment_isRecognizedInEveryLanguage() throws {
        let category = Category(name: "Otros", colorHex: "#64748B", isIncome: false)
        let names = Set(try Self.tables().compactMap { $0.table["subcategory.balanceAdjustment"] })
        #expect(names.count > 1)
        for name in names {
            let sub = Subcategory(name: name, category: category)
            #expect(
                TransactionCSVImportService.systemAdjustmentType(for: sub) == InitialBalanceService.typeAdjustment,
                "«\(name)»")
        }
    }

    @Test("Una transferencia en cualquier idioma es transferencia; la sembrada sigue siendo normal")
    func transfer_isRecognizedInEveryLanguage() throws {
        let category = Category(name: "Otros", colorHex: "#64748B", isIncome: false)
        for name in try Self.localizedTransferNames() {
            let sub = Subcategory(name: name, category: category)
            #expect(
                TransactionCSVImportService.systemAdjustmentType(for: sub) == TransactionItem.adjustmentTypeTransfer,
                "«\(name)»")
        }
        for name in ["Account transfer", "Kontoüberweisung", "口座振替", "账户转账", "Rekeningoverdracht"] {
            #expect(TransactionCSVImportService.systemAdjustmentType(for: Subcategory(name: name, category: category)) == nil)
        }
    }

    @Test("Una subcategoría normal no es de sistema; una con isSystem sigue siendo transferencia")
    func normalSubcategory_isNotSystem_andFlaggedOneStaysTransfer() {
        let category = Category(name: "Alimentación", colorHex: "#22C55E", isIncome: false)
        #expect(TransactionCSVImportService.systemAdjustmentType(for: Subcategory(name: "Delivery", category: category)) == nil)
        let flagged = Subcategory(name: "Gasto compartido", category: category)
        flagged.isSystem = true
        #expect(TransactionCSVImportService.systemAdjustmentType(for: flagged) == TransactionItem.adjustmentTypeTransfer)
    }

    // MARK: - Cableado

    /// Las cuatro rutas (CSV y Excel, una cuenta y varias divisas) llaman a la misma decisión, y ninguna
    /// vuelve a comparar con el texto del idioma actual.
    @Test("Las cuatro rutas del import llaman a la misma decisión")
    func fourImportRoutes_callTheSingleDecision() throws {
        let source = try String(
            contentsOf: Self.repoRoot.appendingPathComponent("Yala/Utils/TransactionCSVImportService.swift"),
            encoding: .utf8)
        let calls = source.components(
            separatedBy: "TransactionCSVImportService.systemAdjustmentType(for: draft.subcategory)").count - 1
        #expect(calls == 4)
        #expect(!source.contains("== L10n.Subcategory.balanceAdjustment"))
        #expect(!source.contains("draft.subcategory.isAnySystem"))
    }
}
