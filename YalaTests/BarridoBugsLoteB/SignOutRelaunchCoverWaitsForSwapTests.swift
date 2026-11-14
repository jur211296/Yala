//
//  SignOutRelaunchCoverWaitsForSwapTests.swift
//  YalaTests
//
//  Barrido del iPhone 14 (14-nov), lote B, card p9q0. Medido en el teléfono con la consola: «CloudSignOut swap COMPLETED» y,
//  encima del Welcome nuevo, «Ya casi está · Vuelve a abrir Yala». La pantalla de reabrir se armaba en el árbol viejo al
//  pasar a `.awaitingRelaunch`, justo antes del cambio en caliente; el cambio desmontaba ese árbol y UIKit dejaba el cover
//  presentado, sin nadie que lo retirara. El cover no se arma con el cambio en vuelo, y se arma si termina sin consumarse.
//
//  Escaneo de fuente: la presentación real solo se ve en un aparato (el simulador monta con espejo y salta el cambio).
//

import Foundation
import Testing

@Suite("Lote B · «Ya casi está» espera al cambio en caliente (p9q0)")
struct SignOutRelaunchCoverWaitsForSwapTests {

    private static func source(_ relative: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let text = try String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
        // Sin comentarios y con los espacios aplastados: lo que se fija es el código.
        return text.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.hasPrefix("//") }
            .joined(separator: " ")
    }

    private static func modifier() throws -> String {
        let view = try source("Yala/App/ContentView.swift")
        let start = try #require(view.range(of: "private struct SignOutRelaunchNetModifier: ViewModifier {"))
        let end = try #require(view.range(of: "// MARK: - Force-update net", range: start.upperBound..<view.endIndex)
            ?? view.range(of: "private struct ForceUpdateNetModifier", range: start.upperBound..<view.endIndex))
        return String(view[start.upperBound..<end.lowerBound])
    }

    @Test func theCoverIsNotArmedWhileTheSwapIsInFlight() throws {
        let body = try Self.modifier()
        let arm = try #require(body.range(of: "private func arm() {"))
        let present = try #require(body.range(of: "showRelaunchCover = true", range: arm.upperBound..<body.endIndex))
        let guardRange = try #require(body.range(of: "guard !CloudSessionSignOut.shared.inPlaceSwapInFlight else { return }",
                                                 range: arm.upperBound..<body.endIndex))
        #expect(guardRange.lowerBound < present.lowerBound, "el cover se armaría antes de saber si el cambio se consuma")
    }

    @Test func aSwapThatEndsWithoutConsumingArmsTheCover() throws {
        let body = try Self.modifier()
        #expect(body.contains(".onChange(of: CloudSessionSignOut.shared.inPlaceSwapInFlight) { _, inFlight in "
                              + "if !inFlight && phase == .awaitingRelaunch { arm() } }"))
    }

    /// El cuarto cierre (empezar de cero en la nube desde el Welcome) pone la fase antes de unas esperas: el testigo va ya
    /// encendido con la fase, y lo apaga el `defer` del principio de la segunda mitad.
    @Test func theWelcomeFreshStart_raisesTheWitnessWithThePhase() throws {
        let src = try Self.source("Yala/Services/CloudSync/CloudSessionSignOut.swift")
        #expect(src.contains("inPlaceSwapInFlight = true phase = .awaitingRelaunch return true }"))
        #expect(src.contains("func finishReturnToFreshInstallAfterWelcomeFreshStart() async -> Bool { "
                             + "defer { inPlaceSwapInFlight = false } guard phase == .awaitingRelaunch"))
    }
}
