//
//  ImportAccountChoiceAndResultTests.swift
//  YalaTests
//
//  QA guiado del 19-oct (A · C1): «Importar archivo» ofrecía la cuenta interna de Grupos («Grupos PEN»), y al
//  terminar a veces no salía «Importación completada».
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Importar archivo · cuentas que se ofrecen y aviso al terminar")
struct ImportAccountChoiceAndResultTests {

    private func cuenta(_ nombre: String, sistema: Bool = false, archivada: Bool = false) -> Account {
        let account = Account(name: nombre, currencyCode: "PEN", colorHex: "#6366F1", iconName: "creditcard", type: "bank")
        account.isSystemAccount = sistema
        account.isArchived = archivada
        return account
    }

    @Test("Ni la cuenta de Grupos ni las archivadas; el resto, por nombre")
    func importableAccounts() {
        let cuentas = [cuenta("Tarjeta"), cuenta("Grupos PEN", sistema: true), cuenta("Vieja", archivada: true),
                       cuenta("Ahorros")]
        #expect(ImportAccountChoiceLogic.importableAccounts(cuentas).map(\.name) == ["Ahorros", "Tarjeta"])
    }

    // MARK: - Cableado

    private static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()

    private static func code(_ relative: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(relative), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    @Test("Los dos selectores del importador piden las cuentas a la misma regla")
    func pickersUseTheRule() throws {
        let intro = try Self.code("Yala/App/Views/Import/ImportIntroSheet.swift")
        #expect(intro.contains("ImportAccountChoiceLogic.importableAccounts(accounts)"))
        let mapping = try Self.code("Yala/App/Views/Import/ImportCurrencyMappingSheet.swift")
        #expect(mapping.contains("ImportAccountChoiceLogic.importableAccounts(accounts)"))
        #expect(!mapping.contains("&& !$0.isArchived"), "el mapeo por divisa volvió a filtrar por su cuenta")
    }

    @Test("El aviso del resultado se pide al cerrarse la hoja, sin retardo fijo")
    func resultAlertWaitsForTheSheet() throws {
        let profile = try Self.code("Yala/App/Views/Profile/ProfileView.swift")
        let inicio = try #require(profile.range(of: ".sheet(item: $activeSheet, onDismiss: {"))
        let fin = try #require(profile.range(of: "case .exportWizard:", range: inicio.upperBound..<profile.endIndex))
        let tramo = profile[inicio.upperBound..<fin.lowerBound]
        // El `onDismiss` enseña el aviso si hay un resultado esperando…
        #expect(tramo.contains("if importResultAwaitingDismiss {"))
        #expect(tramo.contains("showImportResult = true"))
        // …y el callback de la hoja solo lo deja esperando y la cierra.
        let callback = try #require(tramo.range(of: "onImportCompleted: { result in"))
        let resto = tramo[callback.upperBound...]
        #expect(resto.contains("importResultAwaitingDismiss = true"))
        #expect(!resto.contains("Task.sleep"), "volvió el retardo fijo")
        #expect(!resto.contains("showImportResult = true"), "el aviso se vuelve a pedir con la hoja aún cerrándose")
    }
}
