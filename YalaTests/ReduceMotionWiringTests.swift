//
//  ReduceMotionWiringTests.swift
//  YalaTests
//
//  Cards C5 y C6 de la auditoría de fluidez (`docs/fluidez/AUDITORIA-FLUIDEZ-2-2.md`, 2026-11-02).
//
//  C6: las vistas que animaban aunque estuviera activado Reducir movimiento pasan todas por `dsAnimation` /
//  `dsWithAnimation(reduceMotion, …)` o por `reduceMotion ? nil : …`. Source-scan: en cada fichero de la lista, toda
//  `.animation(` lleva `reduceMotion` y no queda ningún `withAnimation(` suelto.
//
//  C5: Ajustes abierto desde Más se presenta sin el `.transaction { $0.animation = nil }` que le apagaba las animaciones
//  (lo puso `c6d44bac8` contra un parpadeo que, según su propio mensaje, no arregló).
//

import Foundation
import Testing

@Suite("Reducir movimiento y Ajustes desde Más — cableado (source-scan)")
struct ReduceMotionWiringTests {

    private static func source(_ relativePath: String, file: StaticString = #filePath) throws -> String {
        let repoRoot = URL(fileURLWithPath: "\(file)").deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: repoRoot.appending(path: relativePath), encoding: .utf8)
    }

    /// Las líneas de código, sin comentarios, para que documentar el patrón no cuente como usarlo.
    private static func codeLines(_ relativePath: String) throws -> [String] {
        try source(relativePath).components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.hasPrefix("//") && !$0.hasPrefix("///") }
    }

    /// Las vistas de la card C6 que se revisan enteras: ninguna animación sin Reducir movimiento.
    static let wholeFiles = [
        "Yala/App/Views/Panel/SetupChecklistCard.swift",
        "Yala/App/Views/Panel/Components/ScoreRingView.swift",
        "Yala/App/Views/Records/RecordsStandaloneView.swift",
        "Yala/App/Views/Groups/GroupFormView.swift",
        "Yala/App/Views/Groups/GroupSettingsView.swift",
        "Yala/App/Views/Accounts/AccountFormView.swift",
        "Yala/App/Views/Chat/YalaAIChatPresentation.swift",
    ]

    @Test(arguments: wholeFiles)
    func everyAnimation_respectsReduceMotion(_ path: String) throws {
        let code = try Self.codeLines(path)
        for (index, line) in code.enumerated() where line.contains(".animation(") {
            // Una llamada partida en varias líneas: `reduceMotion` llega en la siguiente.
            let call = line.hasSuffix(".animation(") && index + 1 < code.count ? line + code[index + 1] : line
            #expect(call.contains("reduceMotion"), "\(path): «\(line)» anima con Reducir movimiento activado.")
        }
        for line in code where line.contains("withAnimation(") {
            #expect(line.contains("dsWithAnimation(reduceMotion"),
                    "\(path): «\(line)» es un `withAnimation` que no mira Reducir movimiento.")
        }
        for line in code where line.contains(".dsAnimation(") {
            #expect(line.contains("reduceMotion: reduceMotion"), "\(path): «\(line)» no pasa Reducir movimiento.")
        }
        #expect(code.contains { $0.contains("reduceMotion") }, "\(path) ya no lee Reducir movimiento.")
    }

    /// El panel de voz de Yala IA: el resto de `ChatSheetView` es de la card C8.
    @Test func chatVoicePanel_respectsReduceMotion() throws {
        let code = try Self.codeLines("Yala/App/Views/Chat/ChatSheetView.swift")
        #expect(code.contains(".animation(reduceMotion ? nil : DS.Animation.appear, value: isVoiceActive)"))
        #expect(code.contains(".animation(reduceMotion ? nil : DS.Animation.appear, value: viewModel.isTranscribing)"))
        #expect(!code.contains(".animation(.easeInOut(duration: 0.25), value: isVoiceActive)"))
    }

    /// C5: la hoja de Ajustes que abre Más ya no apaga sus animaciones; desde el Panel y Grupos nunca lo hizo.
    @Test func settingsFromMore_keepsItsAnimations() throws {
        let code = try Self.codeLines("Yala/App/Views/More/MoreView.swift")
        let profile = try #require(code.firstIndex(of: "ProfileView()"), "MoreView ya no presenta Ajustes.")
        let after = code[(profile + 1)..<min(profile + 4, code.count)]
        #expect(!after.contains { $0.contains("$0.animation = nil") },
                "Ajustes desde Más vuelve a apagar sus animaciones (card C5).")
    }
}
