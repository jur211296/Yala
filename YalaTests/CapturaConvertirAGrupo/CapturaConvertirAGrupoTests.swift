//
//  CapturaConvertirAGrupoTests.swift
//  YalaTests
//
//  Bug de Jürgen del 2026-11-20: en la pantalla de lo leído de una foto, «Convertir a gasto compartido» guardaba bien el
//  gasto en Grupos, pero la fila seguía ahí sin marcarse. El borrador se borra al convertirse y la pantalla lo buscaba con
//  `isDeleted`, que tras el guardado vuelve a `false`. Ahora lo convertido sale guardado (de una copia) y, si era el único,
//  la hoja se cierra como al guardar el último. Cancelar no marca nada. La voz tenía el mismo hueco y comparte el arreglo.
//

import Foundation
import SwiftData
import Testing
@testable import Yala

@Suite("Captura → gasto compartido: queda registrado")
struct CapturaConvertirAGrupoTests {

    typealias Logic = DraftGroupConversionReviewLogic

    /// El estado de cierre de la hoja de foto tal como lo arma `closeIfEverythingIsSaved`.
    private func autoCloseState(drafts: Int, approved: Int, registered: Int) -> ImageEntryAutoCloseLogic.State {
        ImageEntryAutoCloseLogic.State(
            draftCount: Logic.rowCount(drafts: drafts, registeredInGroup: registered),
            savedCount: Logic.savedCount(approved: approved, registeredInGroup: registered),
            saveFailed: false,
            failedPhotos: 0,
            leftOut: 0
        )
    }

    // MARK: - Guardar en grupo marca registrado

    @Test func guardarEnGrupo_loMarcaRegistrado() {
        let registered = Logic.registered([String](), adding: "almuerzo")
        #expect(registered == ["almuerzo"])
        #expect(Logic.allSaved(pending: 0, drafts: 0, registeredInGroup: registered.count))
    }

    @Test func guardarEnGrupo_dosVeces_noLoCuentaDoble() {
        let once = Logic.registered(["almuerzo"], adding: "almuerzo")
        #expect(once == ["almuerzo"])
    }

    @Test func guardarUnoDeDos_elOtroSigueAbierto() {
        // Dos leídos: uno pasa al grupo y el otro sigue pendiente.
        let registered = Logic.registered([String](), adding: "taxi")
        #expect(!Logic.allSaved(pending: 1, drafts: 1, registeredInGroup: registered.count))
        #expect(!ImageEntryAutoCloseLogic.closesAfterSaving(autoCloseState(drafts: 1, approved: 0, registered: 1)))
        #expect(Logic.rowCount(drafts: 1, registeredInGroup: 1) == 2)
    }

    @Test func unoPersonalYOtroEnGrupo_todoGuardado() {
        #expect(Logic.allSaved(pending: 0, drafts: 1, registeredInGroup: 1))
        #expect(ImageEntryAutoCloseLogic.closesAfterSaving(autoCloseState(drafts: 1, approved: 1, registered: 1)))
    }

    // MARK: - Cerrar si era el único

    @Test func eraElUnico_laHojaSeCierraComoAlGuardar() {
        // No se cierra «vacía» en el acto: enseña «Guardado» y se va sola, como al guardar el último.
        #expect(!Logic.closesEmpty(drafts: 0, registeredInGroup: 1))
        #expect(ImageEntryAutoCloseLogic.closesAfterSaving(autoCloseState(drafts: 0, approved: 0, registered: 1)))
    }

    @Test func sinNadaQueEnsenar_seCierraEnElActo() {
        // Lo que ya hacía: un borrador descartado desde su hoja deja la pantalla vacía.
        #expect(Logic.closesEmpty(drafts: 0, registeredInGroup: 0))
    }

    // MARK: - Cancelar no marca

    @Test func cancelarElFormulario_noMarcaNada() {
        let registered = Logic.registered([String](), adding: nil)
        #expect(registered.isEmpty)
        #expect(!Logic.allSaved(pending: 1, drafts: 1, registeredInGroup: registered.count))
        #expect(!ImageEntryAutoCloseLogic.closesAfterSaving(autoCloseState(drafts: 1, approved: 0, registered: 0)))
    }

    // MARK: - La copia de lo registrado

    @MainActor
    @Test func laCopia_tomaLoDelBorradorSiNoEncuentraElGasto() {
        let draft = InboxDraft(note: "Almuerzo", amount: -42.5, sourceType: .receiptPhoto)
        let group = SplitGroup(name: "Viaje a Cusco", currencyCode: "PEN")
        let copy = DraftGroupConversion.registered(draft: draft, group: group, expenseID: "no-es-un-uuid")
        #expect(copy.title == "Almuerzo")
        #expect(copy.amount == 42.5)
        #expect(copy.currencyCode == "PEN")
        #expect(copy.groupName == "Viaje a Cusco")
        #expect(copy.id == draft.persistentModelID)
    }
}

@Suite("Captura → gasto compartido: cableado (source-scan)")
struct CapturaConvertirAGrupoWiringTests {

    private static func readSource(of relativePath: String, file: StaticString = #filePath) throws -> String {
        let repoRoot = URL(fileURLWithPath: "\(file)")
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: repoRoot.appending(path: relativePath), encoding: .utf8)
    }

    /// Código sin comentarios ni líneas vacías, recortado.
    private static func codeLines(_ source: String) -> [String] {
        source.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("//") }
    }

    @Test func elFlujo_copiaAntesDeBorrarElBorrador() throws {
        let code = Self.codeLines(try Self.readSource(of: "Yala/App/Views/Inbox/DraftGroupConversionFlow.swift"))
        let copy = try #require(code.firstIndex { $0.hasPrefix("let registered = DraftGroupConversion.registered(draft: ctx.draft") })
        let delete = try #require(code.firstIndex { $0.hasPrefix("DraftService.shared.handleDraftConvertedToGroupExpense(ctx.draft") })
        let outcome = try #require(code.firstIndex { $0.hasPrefix("outcome = DraftGroupConversionOutcome(group: ctx.group, registered: registered)") })
        #expect(copy < delete)
        #expect(delete < outcome)
    }

    @Test func laFilaRegistrada_noAbreNada() throws {
        // Sin botón ni gesto: lo convertido no puede volver a guardarse como personal.
        let source = try Self.readSource(of: "Yala/App/Views/Inbox/DraftGroupConversionFlow.swift")
        let row = try #require(source.range(of: "struct DraftRegisteredInGroupRow: View {"))
        let body = Self.codeLines(String(source[row.lowerBound...])).joined(separator: "\n")
        #expect(!body.contains("Button"))
        #expect(!body.contains("onTapGesture"))
    }

    @Test(arguments: [
        "Yala/App/Views/Image/ImageSelectionView.swift",
        "Yala/App/Views/Voice/VoiceRecordingView.swift",
    ])
    func cadaPantalla_ensenaLoRegistradoYOlvidaElBorrado(_ path: String) throws {
        let code = Self.codeLines(try Self.readSource(of: path))
        #expect(code.contains("drafts.removeAll { $0.isDeleted || $0.modelContext == nil || $0.status == .rejected }"))
        #expect(code.contains("DraftRegisteredInGroupRow(entry: entry)"))
        #expect(code.contains("if ids.count > registeredInGroup.count { registeredInGroup.append(registered) }"))
        #expect(code.contains(".draftGroupConversionFlow($conversionRequest, onFinished: afterGroupConversion)"))
    }
}
