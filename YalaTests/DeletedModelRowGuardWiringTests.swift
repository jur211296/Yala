//
//  DeletedModelRowGuardWiringTests.swift
//  YalaTests
//
//  Cableado del arreglo del crash de TestFlight 2.2 (2) (card f8rj): una fila que observa su modelo puede volver a
//  pintarse con él ya borrado, y en el iPhone (iOS 27.2) leerlo aborta la app. El simulador 27.0 no aborta, así que
//  ningún test de UI lo caza: estos scans fijan que las dos filas miran antes de leer y que la retirada diferida de la
//  Bandeja apunta lo que espera. El mecanismo se prueba en `InboxPendingRemovalTests`.
//

import Foundation
import Testing

@Suite("Filas que no leen un modelo borrado — cableado (source-scan)")
struct DeletedModelRowGuardWiringTests {

    private static func readSource(of relativePath: String, file: StaticString = #filePath) throws -> String {
        let testFile = URL(fileURLWithPath: "\(file)")
        let repoRoot = testFile.deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: repoRoot.appending(path: relativePath), encoding: .utf8)
    }

    /// Las líneas de código del `body`, sin comentarios ni líneas vacías, desde su apertura.
    private static func bodyCodeLines(_ source: String) throws -> [String] {
        let lines = source.components(separatedBy: "\n")
        let start = try #require(lines.firstIndex { $0.contains("var body: some View {") })
        return lines[(start + 1)...]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("//") }
    }

    @Test func inboxDraftRow_checksTheDraftBeforeReadingIt() throws {
        let code = try Self.bodyCodeLines(Self.readSource(of: "Yala/App/Views/Inbox/InboxDraftRowView.swift"))
        #expect(code.first == "if draft.isReadableInInbox {")
    }

    @Test func recordRow_checksTheRecordBeforeReadingIt() throws {
        let code = try Self.bodyCodeLines(Self.readSource(of: "Yala/App/Views/Records/Components/RecordRowView.swift"))
        #expect(code.first == "if record.isDeleted || record.modelContext == nil {")
        #expect(code.dropFirst().first == "EmptyView()")
    }

    /// La retirada diferida apunta el borrador (`beginRemoval`, no `removeDraft`) y lo suelta ANTES de la recarga final.
    @Test func inboxDeferredRemoval_marksTheDraftUntilItEnds() throws {
        let source = try Self.readSource(of: "Yala/App/Views/Inbox/InboxView.swift")
        let start = try #require(source.range(of: "private func removeDraftWithAnimation("))
        let end = try #require(source.range(of: "private func dismissIfNoPendingDrafts()", range: start.upperBound..<source.endIndex))
        let function = String(source[start.upperBound..<end.lowerBound])

        #expect(function.contains("viewModel.beginRemoval(draft)"))
        #expect(!function.contains("viewModel.removeDraft(draft)"))
        let lastEnd = try #require(function.range(of: "viewModel.endRemoval(id: draftID)", options: .backwards))
        let lastReload = try #require(function.range(of: "viewModel.loadData()", options: .backwards))
        #expect(lastEnd.lowerBound < lastReload.lowerBound, "La recarga final corre antes de soltar el borrador.")
    }
}
