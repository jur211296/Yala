//
//  WelcomeAdoptSlowHintWiringTests.swift
//  YalaTests
//
//  «Conectando con tu cuenta…» solo añade «Esto puede tardar unos minutos» si la conexión ya está tardando (card hov2 del
//  QA guiado del 19-oct). La pantalla es una vista de SwiftUI con su `.task`: se fija por source-scan el texto dentro de
//  su `if`, la espera antes de encenderlo y el apagado al desmontarse.
//

import Foundation
import Testing

@testable import Yala

@Suite("Bienvenida — la pista de minutos sale solo si la conexión tarda (hov2)")
struct WelcomeAdoptSlowHintWiringTests {

    private static func source() throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent("Yala/App/Views/Onboarding/WelcomeCloudSignInView.swift"),
                          encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.hasPrefix("//") }
            .joined(separator: " ")
    }

    @Test func theHintLivesInsideItsIf_andIsTheOnlyPlaceItIsShown() throws {
        let src = try Self.source()
        #expect(src.components(separatedBy: "Text(L10n.Welcome.Cloud.adoptingHint)").count == 2, "un solo sitio pinta la pista")
        #expect(src.contains("if adoptSlowHintVisible { Text(L10n.Welcome.Cloud.adoptingHint)"))
    }

    @Test func theHintTurnsOnAfterTheDelay_andOffWhenTheScreenGoes() throws {
        let src = try Self.source()
        #expect(src.contains("try await Task.sleep(for: WelcomeAdoptSlowHint.delay) } catch { return } adoptSlowHintVisible = true"))
        #expect(src.contains(".onDisappear { adoptSlowHintVisible = false }"))
        #expect(WelcomeAdoptSlowHint.delay == .seconds(8))
    }
}
