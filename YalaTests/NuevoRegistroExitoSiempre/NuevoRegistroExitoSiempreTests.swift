//
//  NuevoRegistroExitoSiempreTests.swift
//  YalaTests
//
//  Decisión de Jürgen del 2026-11-23: al guardar un registro nuevo, la pantalla de éxito aparece SIEMPRE. Antes solo en los
//  tres primeros (UX 2.2 · L2-5); desde el cuarto, el formulario se cerraba con el aviso breve. La prueba de interfaz que
//  lo recorre en gasto, ingreso y transferencia: `YalaUITests/NuevoRegistroExitoSiempre/`.
//

import Foundation
import Testing
@testable import Yala

@Suite("Nuevo registro · la pantalla de éxito sale siempre")
struct NuevoRegistroExitoSiempreTests {

    @Test("Un registro nuevo lleva la pantalla completa")
    func registroNuevo_pantallaCompleta() {
        #expect(TransactionSaveFeedbackLogic.feedback(isEdit: false) == .fullScreen)
    }

    @Test("Una edición cierra con «Cambios guardados»")
    func edicion_avisoDeCambios() {
        #expect(TransactionSaveFeedbackLogic.feedback(isEdit: true) == .editedNotice)
    }

    // MARK: - Cableado (source-scan)

    private static func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    /// El cuerpo de `finishSave` del formulario, sin comentarios.
    private static func finishSaveBody() throws -> String {
        let text = try source("Yala/App/Views/Transactions/NewTransactionView.swift")
        let start = try #require(text.range(of: "private func finishSave("))
        let end = try #require(text.range(of: "private func closeWithSavedNotice(", range: start.upperBound..<text.endIndex))
        return text[start.lowerBound..<end.lowerBound]
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// Lo que cortaba la pantalla de éxito era un recuento de registros guardados: que no vuelva a decidir el guardado.
    @Test("Guardar no consulta cuántos registros lleva la persona")
    func guardar_noMiraElRecuento() throws {
        let body = try Self.finishSaveBody()
        #expect(!body.contains("savedRecordsKey"))
        #expect(!body.contains("transactionsSavedCount"))
        #expect(!body.contains("closeWithSavedNotice"), "Un registro nuevo no cierra con el aviso breve.")
        #expect(body.contains("showTransactionSuccess()"))
    }

    /// «Guardar» de un registro nuevo pasa por `finishSave` y solo «Agregar otro» lo evita (otro flujo: deja la hoja abierta).
    @Test("El guardado normal acaba en finishSave")
    func guardado_acabaEnFinishSave() throws {
        let text = try Self.source("Yala/App/Views/Transactions/NewTransactionView.swift")
        let collapsed = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        #expect(collapsed.contains("if addAnother && !wasEdit { startAnotherAfterSave() } else { finishSave(wasEdit: wasEdit) }"))
    }
}
