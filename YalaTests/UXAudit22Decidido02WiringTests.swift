//
//  UXAudit22Decidido02WiringTests.swift
//  YalaTests
//
//  Cableado del lote decidido 2.2 · 02 (sesión A) que vive en vistas y no se puede llamar desde un test: qué divisa
//  pasan el favorito y el pago planificado (card 4k2q), que el Panel ya no precarga una cuenta al azar (uipg), y que
//  el formulario usa la hoja de fecha con atajos (L2-7) y el selector de destino que ofrece crear otra cuenta (L2-6).
//  Los scans miran el código sin comentarios y el tramo de cada función, no el fichero entero.
//

import Foundation
import Testing

@Suite("Lote decidido 2.2 · 02 · cableado (source-scan)")
struct UXAudit22Decidido02WiringTests {

    private static func source(_ relative: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
    }

    private static func codeOnly(_ code: String) -> String {
        code.split(separator: "\n").map { line -> Substring in
            if let range = line.range(of: "//") { return line[..<range.lowerBound] }
            return line
        }.joined(separator: "\n")
    }

    /// El tramo de `start` hasta el siguiente `end` (sin comentarios).
    private static func section(_ code: String, from start: String, to end: String) throws -> String {
        let clean = codeOnly(code)
        let lower = try #require(clean.range(of: start), "no encuentro \(start)")
        let rest = clean[lower.upperBound...]
        let upper = rest.range(of: end)?.lowerBound ?? rest.endIndex
        return String(rest[..<upper])
    }

    private static let form = "Yala/App/Views/Transactions/NewTransactionView.swift"

    @Test func elFavorito_guardaLaDivisaDelImporte() throws {
        let body = try Self.section(Self.source(Self.form), from: "private var favoriteSheetContent", to: "private var recurringSheetContent")
        #expect(body.contains("currencyCode: viewModel.amountCurrencyCode"))
        #expect(!body.contains("effectiveCurrencyCode"))
        // L2-14: de una transferencia, origen y destino.
        #expect(body.contains("destinationAccount: viewModel.isTransfer ? viewModel.destinationAccount : nil"))
    }

    @Test func elPagoPlanificado_guardaLaDivisaDelImporte() throws {
        let code = try Self.source(Self.form)
        let editor = try Self.section(code, from: "private var recurringSheetContent", to: "private var splitCalculatorSheetContent")
        #expect(editor.contains("currencyCode: viewModel.amountCurrencyCode"))
        #expect(!editor.contains("effectiveCurrencyCode"))
        let quick = try Self.section(code, from: "private func createRecurringPayment", to: "SetupChecklistManager")
        #expect(quick.contains("currencyCode: viewModel.amountCurrencyCode"))
    }

    @Test func elEditorDePagos_conservaLaDivisaDelRegistroYSuDiaDeLaSemana() throws {
        let code = try Self.source("Yala/App/Views/Planning/ScheduledPaymentEditorView.swift")
        let prefill = try Self.section(code, from: "if payment == nil, let prefill = prefill {", to: "guard let payment = payment")
        #expect(prefill.contains("selectedWeekdays = [calendar.component(.weekday, from: prefill.transactionDate)]"))
        let save = try Self.section(code, from: "private func savePayment()", to: "let savedID")
        #expect(save.contains("prefillCurrency ?? selectedAccount?.currencyCode"))
    }

    @Test func elPanel_yaNoPrecargaUnaCuentaDelFiltro() throws {
        let code = Self.codeOnly(try Self.source("Yala/App/Views/Panel/PanelSheetsModifier.swift"))
        #expect(!code.contains("prefillAccountID: viewModel.selectedAccountID"))
    }

    @Test func elFormulario_usaLaFechaConAtajos_yElDestinoQueOfreceCrearOtraCuenta() throws {
        let code = Self.codeOnly(try Self.source(Self.form))
        #expect(code.contains("DatePickerSheet(selectedDate: $viewModel.transactionDate, quickPick: true)"))
        let destination = try Self.section(
            Self.source(Self.form), from: "$viewModel.showDestinationAccountSelector) {", to: ".sheet(")
        #expect(destination.contains("offersCreatingAccount: true"))
        // Ya no hay ★ en la barra: la estrella solo guarda (L2-13).
        #expect(!code.contains("Image(systemName: \"star.fill\")"))
    }

    @Test func losTresHosts_ponenQuienEditaTrasGuardar() throws {
        for path in [
            "Yala/App/Views/Panel/PanelShell.swift",
            "Yala/App/Views/Records/RecordsStandaloneView.swift",
            "Yala/App/Views/Statistics/DetailContainerView.swift",
        ] {
            let code = Self.codeOnly(try Self.source(path))
            #expect(code.contains(".environment(\\.savedRecordEditorOpener"), "falta en \(path)")
        }
    }
}
