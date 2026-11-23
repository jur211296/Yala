//
//  HacerRecurrenteExitoTests.swift
//  YalaTests
//
//  Decisión de Jürgen del 2026-11-23: «Hacer recurrente» (menú «···» de Nuevo registro) también enseña la pantalla de
//  éxito al guardar, como el guardado normal. Antes cerraba con el aviso breve «Guardado · se repetirá cada mes». La
//  prueba de interfaz que lo recorre: `YalaUITests/HacerRecurrenteExito/`.
//

import Foundation
import Testing
@testable import Yala

@Suite("Hacer recurrente · la pantalla de éxito")
struct HacerRecurrenteExitoTests {

    @Test("Un registro nuevo hecho recurrente lleva la pantalla completa")
    func registroNuevo_pantallaCompleta() {
        #expect(TransactionSaveFeedbackLogic.recurringFeedback(isEdit: false, successScreenShown: false) == .fullScreen)
    }

    @Test("Una edición hecha recurrente cierra con el aviso breve")
    func edicion_avisoBreve() {
        #expect(TransactionSaveFeedbackLogic.recurringFeedback(isEdit: true, successScreenShown: false) == .recurringNotice)
    }

    @Test("Desde la oferta de la pantalla de éxito, que ya se vio, cierra con el aviso breve")
    func desdeElExito_avisoBreve() {
        #expect(TransactionSaveFeedbackLogic.recurringFeedback(isEdit: false, successScreenShown: true) == .recurringNotice)
        #expect(TransactionSaveFeedbackLogic.recurringFeedback(isEdit: true, successScreenShown: true) == .recurringNotice)
    }

    @Test("El guardado normal no cambia")
    func guardadoNormal_igual() {
        #expect(TransactionSaveFeedbackLogic.feedback(isEdit: false) == .fullScreen)
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

    /// El cuerpo de una función, sin comentarios y con los espacios colapsados.
    private static func body(of start: String, until end: String, in path: String) throws -> String {
        let text = try source(path)
        let from = try #require(text.range(of: start))
        let to = try #require(text.range(of: end, range: from.upperBound..<text.endIndex))
        return text[from.lowerBound..<to.lowerBound]
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.hasPrefix("//") }
            .joined(separator: " ")
    }

    private static let form = "Yala/App/Views/Transactions/NewTransactionView.swift"

    private static func handleRecurringSavedBody() throws -> String {
        try body(of: "private func handleRecurringSaved(", until: "// MARK: - Hacer recurrente", in: form)
    }

    /// La decisión va antes del aviso: si `.fullScreen`, enseña el éxito y sale sin llegar a `closeWithSavedNotice`.
    @Test("«Hacer recurrente» decide con la lógica y enseña el éxito antes del aviso")
    func cableado_exitoAntesDelAviso() throws {
        let body = try Self.handleRecurringSavedBody()
        let decision = try #require(body.range(of: "TransactionSaveFeedbackLogic.recurringFeedback(isEdit: wasEdit, successScreenShown: showSuccessScreen)"))
        let success = try #require(body.range(of: "showTransactionSuccess(primer: .scheduledPayment)"))
        let notice = try #require(body.range(of: "closeWithSavedNotice("))
        #expect(decision.lowerBound < success.lowerBound)
        #expect(success.lowerBound < notice.lowerBound, "El éxito va antes del aviso, o salen los dos.")
        // Entre el éxito y el aviso hay un `return`: sin él, saldría el aviso encima de la pantalla.
        let between = body[success.upperBound..<notice.lowerBound]
        #expect(between.contains("return"), "Tras enseñar el éxito, «Hacer recurrente» no puede seguir al aviso breve.")
    }

    /// El editor completo («Más opciones…») enseña el éxito al cerrarse su hoja, no el aviso.
    @Test("Desde el editor completo, el éxito sale al cerrarse su hoja")
    func cableado_editorCompleto() throws {
        let body = try Self.handleRecurringSavedBody()
        #expect(body.contains("closeAfterRecurringEditor = { successRecurrence = recurrence showTransactionSuccess() }"))
    }

    /// La pantalla marca «Recurrente» con la frecuencia, y el guardado normal la vacía (no hereda la de antes).
    @Test("La pantalla de éxito recibe la frecuencia y el guardado normal la limpia")
    func cableado_frecuenciaEnLaPantalla() throws {
        let text = try Self.source(Self.form).split(whereSeparator: \.isWhitespace).joined(separator: " ")
        #expect(text.contains("recurrence: successRecurrence )"))
        let finish = try Self.body(of: "private func finishSave(", until: "private func closeWithSavedNotice(", in: Self.form)
        #expect(finish.contains("case .fullScreen: successRecurrence = nil showTransactionSuccess()"))
    }

    /// Ya recurrente, el botón no vuelve a abrir «Hacer recurrente» (crearía un segundo pago planificado).
    @Test("«Recurrente» marcado no se vuelve a abrir")
    func vista_recurrenteMarcadoDesactivado() throws {
        let text = try Self.source("Yala/App/Views/Transactions/TransactionSuccessView.swift")
        let start = try #require(text.range(of: "if let recurrence, !data.isTransfer {"))
        let end = try #require(text.range(of: "} else if let onRecurring", range: start.upperBound..<text.endIndex))
        let branch = text[start.lowerBound..<end.lowerBound]
        #expect(branch.contains("isDone: true"))
        #expect(branch.contains(".disabled(true)"))
        #expect(branch.contains("recurrence.localizedName"), "Sin texto nuevo: la frecuencia del pago planificado.")
    }
}
