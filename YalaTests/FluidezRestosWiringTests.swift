//
//  FluidezRestosWiringTests.swift
//  YalaTests
//
//  Encargo fluidez-subpestanas-duplicados-y-splash (2026-11-03). Source-scan de lo que no cabe en
//  `TabImplicitAnimationsWiringTests` ni en `ContentTransitionsWiringTests`: el splash con Reducir movimiento (n3iq) y el
//  borrado de duplicados de Registros (0mzg). Que de verdad se vea se comprobó en vídeo en el simulador (PR).
//

import Foundation
import Testing

@Suite("Fluidez: splash y duplicados — cableado (source-scan)")
struct FluidezRestosWiringTests {

    private static func codeLines(_ relativePath: String, file: StaticString = #filePath) throws -> [String] {
        let repoRoot = URL(fileURLWithPath: "\(file)").deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: repoRoot.appending(path: relativePath), encoding: .utf8)
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("//") }
    }

    /// Card n3iq: con Reducir movimiento el temporizador de 20 Hz que mueve las partículas no arranca.
    @Test func splash_doesNotStartTheParticleTimer_withReduceMotion() throws {
        let code = try Self.codeLines("Yala/App/Views/SplashScreenView.swift")
        let calls = code.indices.filter { code[$0] == "startParticleAnimation(in: geometry.size)" }
        #expect(calls.count == 1, "El splash arranca las partículas desde más de un sitio (o desde ninguno).")
        let call = try #require(calls.first)
        #expect(code[call - 1] == "if !reduceMotion {", "Las partículas vuelven a moverse con Reducir movimiento.")
        // El temporizador solo nace dentro de esa función.
        #expect(code.filter { $0.contains("Timer.scheduledTimer(") }.count == 1)
    }

    /// Card 0mzg: en el modo duplicados, borrar un repetido funde su fila y «Quitar repetidos» anima con su contador.
    @Test func duplicates_animateTheirRows_andTheBulkRemoval() throws {
        let view = try Self.codeLines("Yala/App/Views/Statistics/RecordsTabView.swift")
        #expect(view.contains(".animatesRowEdits(ids: rowIDs)"), "Las filas del modo duplicados ya no se funden.")
        let model = try Self.codeLines("Yala/App/ViewModels/RecordsViewModel.swift")
        let confirm = try #require(model.firstIndex { $0.hasPrefix("func confirmDuplicateRemoval(") })
        let next = try #require(model[(confirm + 1)...].firstIndex { $0.hasPrefix("func ") })
        let body = model[confirm..<next]
        #expect(body.contains("duplicateRemovalCount += 1"), "«Quitar repetidos» ya no avisa a la vista para animar.")
        // Sube solo tras borrar: el `guard` de «nada que borrar» va antes.
        let guardLine = try #require(body.firstIndex { $0.hasPrefix("guard !ids.isEmpty") })
        let bump = try #require(body.firstIndex { $0 == "duplicateRemovalCount += 1" })
        #expect(guardLine < bump)
    }
}
