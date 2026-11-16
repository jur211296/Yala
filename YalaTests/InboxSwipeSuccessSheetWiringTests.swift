//
//  InboxSwipeSuccessSheetWiringTests.swift
//  YalaTests
//
//  Ticket `inbox-swipe-save-success-sheet-shows-blank`. Deslizar para guardar un borrador abría, a ratos, una hoja de
//  éxito vacía: `.sheet(isPresented:)` con el contenido sacado de OTRO `@State`, escritos los dos en el mismo toque, y el
//  cierre de la hoja se quedaba con el valor de antes (`nil`). Medido el 2026-11-12: con el código viejo, 1 de 2 vueltas
//  de cada caso de `InboxDuplicateCheckUITests` salió vacía. La regla es de `.claude/rules/swiftui-ds.md`: para presentar
//  UN objeto, `.sheet(item:)`.
//
//  El XCUITest mide la pantalla, pero el fallo es intermitente y una corrida verde no prueba nada. Este scan fija el
//  cableado en cada corrida de unit: sin el arreglo, cae.
//

import Foundation
import Testing

@Suite("Bandeja · la hoja de éxito al deslizar se presenta con su propio valor")
struct InboxSwipeSuccessSheetWiringTests {

    private static func code(_ relative: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let text = try String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
        return text.split(separator: "\n").map { line -> Substring in
            if let range = line.range(of: "//") { return line[..<range.lowerBound] }
            return line
        }.joined(separator: "\n")
    }

    /// La hoja se presenta con `item:` y pinta el valor que recibe, no otro estado de la vista.
    @Test func swipeSuccessSheet_isPresentedByItem_andPaintsTheValueItReceives() throws {
        let inbox = try Self.code("Yala/App/Views/Inbox/InboxView.swift")
        let sheet = try #require(inbox.range(of: ".sheet(item: $swipeSuccess) { success in"),
                                 "La hoja de éxito de deslizar ya no se presenta con `item:`.")
        let after = inbox[sheet.upperBound...]
        let view = try #require(after.range(of: "InboxApproveSuccessView("))
        let data = try #require(after.range(of: "data: success.data"), "La hoja no pinta los datos que recibe.")
        #expect(view.upperBound <= data.lowerBound)
        // Ni el flag ni los estados aparte que la dejaban vacía.
        #expect(!inbox.contains("showSwipeSuccessView"), "Vuelve el flag `isPresented:` de la hoja de éxito.")
        #expect(!inbox.contains("swipeSuccessData"), "Vuelve el estado aparte con los datos de la hoja.")
        #expect(!inbox.contains("swipeApprovedTransaction"), "Vuelve el estado aparte con el registro de la hoja.")
    }

    /// El valor se escribe de una vez al aprobar, con los datos y el registro guardado: «Editar» abre ESE registro.
    @Test func approveDraft_setsTheSuccessValueOnce_withTheSavedRecord() throws {
        let inbox = try Self.code("Yala/App/Views/Inbox/InboxView.swift")
        let approve = try #require(inbox.range(of: "private func approveDraft(_ draft: InboxDraft"))
        let rest = inbox[approve.upperBound...]
        // Solo el cuerpo de `approveDraft`: hasta la función siguiente.
        let end = rest.range(of: "private func ")?.lowerBound ?? rest.endIndex
        let body = rest[..<end]
        let set = try #require(body.range(of: "swipeSuccess = InboxSwipeSuccess("),
                               "La aprobación deslizando ya no prepara el valor de la hoja.")
        let saved = try #require(body.range(of: "transaction: transaction"),
                                 "El valor de la hoja no lleva el registro guardado: «Editar» no sabría cuál abrir.")
        #expect(set.upperBound <= saved.lowerBound)
    }

    /// Cada salida de la hoja la cierra vaciando el valor ANTES de encadenar lo siguiente: con la hoja arriba, el editor
    /// («Editar») o el borrador siguiente («Guardar el siguiente») no se presentarían.
    @Test func everyExit_closesTheSheetBeforeChainingTheNextPresentation() throws {
        let inbox = try Self.code("Yala/App/Views/Inbox/InboxView.swift")
        let sheet = try #require(inbox.range(of: ".sheet(item: $swipeSuccess) { success in"))
        let after = inbox[sheet.upperBound...]
        // La hoja acaba donde empieza la presentación siguiente del fichero.
        let sheetEnd = try #require(after.range(of: ".alert(")).lowerBound
        let sheetBody = after[..<sheetEnd]
        let checks: [(exit: String, next: String)] = [
            ("onEdit: {", "selectedTransaction = success.transaction"),
            ("onAccept: {", "dismissIfNoPendingDrafts()"),
            ("onApproveNext: {", "openDraftAfterDelay(next)"),
        ]
        let starts = try checks.map { check in
            try #require(sheetBody.range(of: check.exit), "La hoja de éxito perdió \(check.exit)")
        }
        for (index, check) in checks.enumerated() {
            // El bloque de cada salida: hasta la salida siguiente (o el final de la hoja).
            let end = index + 1 < starts.count ? starts[index + 1].lowerBound : sheetBody.endIndex
            let block = sheetBody[starts[index].upperBound..<end]
            let close = try #require(block.range(of: "swipeSuccess = nil"), "\(check.exit) no cierra la hoja.")
            let next = try #require(block.range(of: check.next), "\(check.exit) no encadena \(check.next).")
            #expect(close.upperBound <= next.lowerBound, "\(check.exit) encadena antes de cerrar la hoja.")
        }
    }

    /// «Guardar de todas formas» no guarda con la hoja de éxito arriba: no podría salir la suya.
    @Test func saveAnyway_waitsForTheSuccessSheetToBeGone() throws {
        let inbox = try Self.code("Yala/App/Views/Inbox/InboxView.swift")
        let fn = try #require(inbox.range(of: "private func saveSwipedDuplicateAnyway(_ draft: InboxDraft)"))
        let rest = inbox[fn.upperBound...]
        let end = rest.range(of: "private func ")?.lowerBound ?? rest.endIndex
        #expect(rest[..<end].contains("guard selectedDraft == nil, swipeSuccess == nil,"))
    }
}
