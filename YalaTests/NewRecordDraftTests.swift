//
//  NewRecordDraftTests.swift
//  YalaTests
//
//  Card «Nuevo registro a medias vuelve vacío» (2026-11-04): lo escrito en «Nuevo registro» lo guarda quien presenta la
//  hoja, para que un formulario rehecho sin cerrarse lo retome. Solo en memoria, y se descarta al cerrar la hoja. Que el
//  formulario rehecho conserve el importe en pantalla lo prueba `ExternalEntryForeignSheetUITests.test_rebuiltForm_*`.
//

import Foundation
import Testing
@testable import Yala

@MainActor
@Suite("Borrador de Nuevo registro")
struct NewRecordDraftTests {

    @Test func theSecondFormGetsTheSameModel() {
        let draft = NewRecordDraft()
        let first = draft.resolveViewModel()
        first.amountString = "1234"
        let rebuilt = draft.resolveViewModel()
        #expect(rebuilt === first)
        #expect(rebuilt.amountString == "1234")
    }

    @Test func isResumableOnlyOnceTheFirstFormTookItsBaseline() {
        let draft = NewRecordDraft()
        #expect(!draft.isResumable)
        let model = draft.resolveViewModel()
        #expect(!draft.isResumable, "Sin foto de partida aún no hay nada que retomar: el primer formulario la toma.")
        draft.baseline = model.formSnapshot
        #expect(draft.isResumable)
    }

    @Test func discardStartsTheNextOpeningFromScratch() {
        let draft = NewRecordDraft()
        let model = draft.resolveViewModel()
        model.amountString = "1234"
        draft.baseline = model.formSnapshot
        draft.discard()
        #expect(!draft.isResumable)
        let next = draft.resolveViewModel()
        #expect(next !== model)
        #expect(next.amountString != "1234")
    }

    @Test func createAnotherMovesTheDraftToTheNewModel() {
        let draft = NewRecordDraft()
        let old = draft.resolveViewModel()
        let replacement = NewTransactionViewModel()
        draft.adopt(replacement)
        #expect(draft.resolveViewModel() === replacement)
        #expect(draft.resolveViewModel() !== old)
    }
}

/// Source-scan del cableado: los tres sitios que abren «Nuevo registro» le pasan el borrador y lo descartan al cerrarse
/// la hoja (en `onDismiss`, que no corre si la hoja solo se rehace), y el formulario retoma sin volver a precargar.
@Suite("Borrador de Nuevo registro — cableado (source-scan)")
struct NewRecordDraftWiringTests {

    private static func code(_ relativePath: String, file: StaticString = #filePath) throws -> String {
        let repoRoot = URL(fileURLWithPath: "\(file)").deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: repoRoot.appending(path: relativePath), encoding: .utf8)
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.hasPrefix("//") }
            .joined(separator: "\n")
    }

    @Test(arguments: [
        "Yala/App/Views/Statistics/StatisticsView.swift",
        "Yala/App/Views/Records/RecordsStandaloneView.swift",
        "Yala/App/Views/Panel/PanelSheetsModifier.swift",
    ])
    func presenterKeepsAndDiscardsTheDraft(_ path: String) throws {
        let code = try Self.code(path)
        #expect(code.contains("@State private var newRecordDraft = NewRecordDraft()"))
        #expect(code.contains("draft: newRecordDraft"))
        #expect(code.contains("newRecordDraft.discard()"))
        #expect(code.contains(".newRecordSheetIdentity()"))
        // El descarte va en el `onDismiss` de la hoja de Nuevo registro, no en un `onDisappear` del contenido: este
        // corre también cuando la hoja solo se rehace, y tiraría lo escrito justo cuando hay que retomarlo.
        let sheet = try #require(code.range(of: ".sheet(isPresented: $"))
        let discard = try #require(code.range(of: "newRecordDraft.discard()"))
        #expect(sheet.lowerBound < discard.lowerBound)
        #expect(!code.contains(".onDisappear { newRecordDraft.discard() }"))
    }

    @Test func formResumesWithoutPrefillingAgain() throws {
        let code = try Self.code("Yala/App/Views/Transactions/NewTransactionView.swift")
        #expect(code.contains("_viewModel = State(initialValue: draft?.resolveViewModel() ?? NewTransactionViewModel())"))
        #expect(code.contains("let resumesDraft = formBaseline == nil && (draft?.isResumable ?? false)"))
        #expect(code.contains("if !resumesDraft { prefillFromContext() }"))
        #expect(code.contains("draft?.baseline = formBaseline"))
        #expect(code.contains("draft?.adopt(newViewModel)"))
    }
}
