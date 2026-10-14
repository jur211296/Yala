//
//  ProTourSkipWiringTests.swift
//  YalaTests
//
//  Auditoría UX 2.2 · lote 5 · B7: «Omitir guía» en el tour Pro solo saltaba la fase en curso; el tour volvía a
//  salir en el Panel y en Estadísticas. Ahora `CoachMarkOverlay` distingue omitir de terminar (`onSkip`) y las tres
//  fases del tour Pro omiten con `ProTourManager.skipTour()`.
//
//  El tour no se ve en ningún XCUITest (se suprime con `-uitest`), así que el cableado se fija por source-scan, con
//  el cuerpo de cada llamada normalizado y el EMPAREJAMIENTO de los dos cierres (omitir ≠ terminar).
//

import Foundation
import Testing

@testable import Yala

@MainActor
@Suite("Tour Pro · «Omitir guía» salta el tour entero", .serialized)
struct ProTourSkipWiringTests {

    /// Quita comentarios de línea y une el código en una sola línea con espacios simples.
    private static func normalized(_ source: String) -> String {
        source.split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> Substring in
                if let range = line.range(of: "//") { return line[..<range.lowerBound] }
                return line
            }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func source(_ relative: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
    }

    /// La llamada `.coachMarkOverlay( … )` que monta `steps`, de su paréntesis de apertura al de cierre.
    private static func overlayCall(in code: String, steps: String) throws -> String {
        let stepsRange = try #require(code.range(of: "steps: \(steps),"))
        let open = try #require(code.range(of: ".coachMarkOverlay(", options: .backwards, range: code.startIndex..<stepsRange.lowerBound))
        var depth = 0
        var index = open.upperBound
        depth = 1
        while index < code.endIndex, depth > 0 {
            if code[index] == "(" { depth += 1 }
            if code[index] == ")" { depth -= 1 }
            index = code.index(after: index)
        }
        return String(code[open.lowerBound..<index])
    }

    @Test("cada fase del tour Pro omite el tour y termina su fase", arguments: [
        ("Yala/App/Views/Profile/ProfileView.swift", "ProTourSteps.profileSteps"),
        ("Yala/App/Views/Panel/PanelView.swift", "ProTourSteps.panelSteps"),
        ("Yala/App/Views/Statistics/InsightsTabView.swift", "ProTourSteps.insightsSteps"),
    ])
    func phaseWiring(_ c: (file: String, steps: String)) throws {
        let call = try Self.overlayCall(in: Self.normalized(Self.source(c.file)), steps: c.steps)
        #expect(call.contains("onSkip: { ProTourManager.shared.skipTour() }, onComplete: { ProTourManager.shared.advancePhase() }"))
    }

    @Test("el botón «Omitir guía» llama al cierre de omitir, y terminar sigue llamando a onComplete")
    func overlaySeparatesSkipFromComplete() throws {
        let code = Self.normalized(try Self.source("Yala/App/Tips/CoachMarkOverlay.swift"))
        #expect(code.contains("Button { dismissAndComplete(skipped: true) } label: { Text(L10n.TipKit.skip)"))
        #expect(code.contains("isPresented = false if skipped, let onSkip { onSkip() } else { onComplete() }"))
        // «Siguiente» en el último paso termina, no omite.
        #expect(code.contains("} else { dismissAndComplete() }"))
    }

    @Test("omitir deja el tour terminado: ninguna fase vuelve a salir")
    func skipTourCompletesTheTour() {
        let manager = ProTourManager.shared
        defer { manager.reset() }
        manager.reset()
        manager.skipTour()
        #expect(manager.hasCompleted)
        #expect(manager.currentPhase == .done)
    }
}
