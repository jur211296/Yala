//
//  TransferNamesParityTests.swift
//  YalaTests
//
//  H2 de la auditoría del import 2.2 (card ynsq): el import marca una fila como transferencia por el texto de su
//  subcategoría (`Subcategory.transferNames`) y, desde el 2026-11-13, por el PAPEL de la subcategoría a la que va. Faltaban los
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

    /// Decisión de Jürgen (2026-11-13, reemplaza la del 29-oct): la subcategoría de transferencia que Yala siembra es
    /// de sistema en TODOS los idiomas. Sus nombres de los `.lproj` son exactamente `seededTransferNames`, y una
    /// sembrada con cualquiera de ellos tiene papel de transferencia.
    @Test("Los nombres sembrados de transferencia de cada .lproj son de sistema")
    func seededTransferNames_areSystemInEveryLanguage() throws {
        var seeded: Set<String> = []
        for (locale, table) in try Self.tables() {
            for key in ["subcategory.accountTransfer", "subcategory.accountTransferOther"] {
                let name = try #require(table[key], "\(locale): falta \(key)")
                seeded.insert(name)
                #expect(
                    Subcategory.inferredSystemRole(name: name, isDefaultSeed: true) == .transfer,
                    "\(locale): «\(name)» (\(key))")
            }
        }
        #expect(seeded == Subcategory.seededTransferNames)
        // Control: los que antes eran normales siguen en la lista (si coincidieran todos, el caso no existiría).
        #expect(seeded.subtracting(Subcategory.transferNames).isSuperset(of: ["Account transfer", "Kontoüberweisung", "口座振替"]))
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

    @Test("Una transferencia en cualquier idioma es transferencia, también la sembrada; la del usuario no")
    func transfer_isRecognizedInEveryLanguage() throws {
        let category = Category(name: "Otros", colorHex: "#64748B", isIncome: false)
        for name in try Self.localizedTransferNames().union(Subcategory.seededTransferNames) {
            let sub = Subcategory(name: name, category: category)
            #expect(
                TransactionCSVImportService.systemAdjustmentType(for: sub) == TransactionItem.adjustmentTypeTransfer,
                "«\(name)»")
            // Creada a mano con el mismo nombre: normal.
            let own = Subcategory(name: name, isDefaultSeed: false, category: category)
            #expect(TransactionCSVImportService.systemAdjustmentType(for: own) == nil, "«\(name)» del usuario")
        }
    }

    /// Desde el 2026-11-13 decide el papel. Una del puente de Grupos (`isSystem`) no tiene papel, y el import la rechaza
    /// antes de llegar aquí (`ImportError.groupRow`).
    @Test("Una subcategoría normal no es de sistema; una del puente no tiene papel")
    func normalSubcategory_isNotSystem_andBridgeOneHasNoRole() {
        let category = Category(name: "Alimentación", colorHex: "#22C55E", isIncome: false)
        #expect(TransactionCSVImportService.systemAdjustmentType(for: Subcategory(name: "Delivery", category: category)) == nil)
        let flagged = Subcategory(name: "Gasto compartido", category: category)
        flagged.isSystem = true
        #expect(TransactionCSVImportService.systemAdjustmentType(for: flagged) == nil)
    }

    @Test("El texto de una fila importada da su papel en cualquier idioma")
    func importedRowText_givesItsRole() throws {
        for name in Subcategory.balanceAdjustmentNames {
            #expect(TransactionCSVImportService.systemRole(forImportedSubcategoryName: name) == .balanceAdjustment)
        }
        for name in try Self.localizedTransferNames().union(Subcategory.seededTransferNames) {
            #expect(TransactionCSVImportService.systemRole(forImportedSubcategoryName: name) == .transfer, "«\(name)»")
        }
        #expect(TransactionCSVImportService.systemRole(forImportedSubcategoryName: "Delivery") == nil)
    }

    // MARK: - Cableado

    /// Todas las rutas (CSV y Excel, una cuenta, varias divisas y columna de cuenta) crean el movimiento en un
    /// solo sitio desde S27m, y ese sitio llama a la decisión; ninguna vuelve a comparar con el idioma actual.
    @Test("Todas las rutas del import llaman a la misma decisión")
    func importRoutes_callTheSingleDecision() throws {
        let source = try String(
            contentsOf: Self.repoRoot.appendingPathComponent("Yala/Utils/TransactionCSVImportService.swift"),
            encoding: .utf8)
        let calls = source.components(separatedBy: "systemAdjustmentType(for: draft.subcategory)").count - 1
        #expect(calls == 1)
        #expect(source.components(separatedBy: "TransactionItem(").count - 1 == 1, "Un solo sitio crea el movimiento.")
        #expect(!source.contains("== L10n.Subcategory.balanceAdjustment"))
        #expect(!source.contains("draft.subcategory.isAnySystem"))
    }
}
