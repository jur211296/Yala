//
//  WelcomeCoverFallbackAfterAdoptTests.swift
//  YalaTests
//
//  Card zrya (Jürgen, 13-nov): tras «¡Tu cuenta está lista!» → «Empezar», Yala volvía a la bienvenida con la cuenta ya
//  dentro. Medido en el iPhone 14 con logs: `onFinishedToApp` leía `hasCompletedOnboarding = true` y el `onDismiss` del
//  cover, una línea después, `false`. UIKit guarda el cierre de cuando se presentó el cover, y su `@AppStorage` era el
//  de antes del adopt. El respaldo lee ahora el almacén en el momento.
//
//  Lo que no se puede probar aquí: que SwiftUI entregue el valor viejo al `onDismiss` (necesita el cover presentado en
//  un aparato). Lo fijan la decisión pura, la lectura del almacén y el cableado del respaldo.
//

import Foundation
import Testing

@testable import Yala

@MainActor
@Suite("Tras «¡Tu cuenta está lista!», el respaldo del cover no devuelve a la bienvenida")
struct WelcomeCoverFallbackAfterAdoptTests {

    typealias Logic = WelcomeCoverContentLogic

    // MARK: - Decisión

    @Test("con el onboarding completo, el respaldo no vuelve al elector aunque nada más esté pedido")
    func onboardingCompleted_neverReopens() {
        #expect(!Logic.dismissFallbackReopensChooser(
            onboardingCompleted: true, showsGroupInvite: false, showsOnboarding: false, showsFlow: false))
    }

    @Test("sin onboarding y sin nada pedido, vuelve al elector: es la red contra la pantalla vacía")
    func nothingFinished_reopens() {
        #expect(Logic.dismissFallbackReopensChooser(
            onboardingCompleted: false, showsGroupInvite: false, showsOnboarding: false, showsFlow: false))
    }

    @Test("cualquier otra pantalla ya pedida gana al respaldo, una a una")
    func anyOtherScreen_wins() {
        #expect(!Logic.dismissFallbackReopensChooser(
            onboardingCompleted: false, showsGroupInvite: true, showsOnboarding: false, showsFlow: false))
        #expect(!Logic.dismissFallbackReopensChooser(
            onboardingCompleted: false, showsGroupInvite: false, showsOnboarding: true, showsFlow: false))
        #expect(!Logic.dismissFallbackReopensChooser(
            onboardingCompleted: false, showsGroupInvite: false, showsOnboarding: false, showsFlow: true))
    }

    // MARK: - Lectura del almacén

    @Test("lee el onboarding del almacén en el momento: lo que el adopt escribió después de presentar el cover cuenta")
    func readsTheStoreNow() throws {
        let defaults = try #require(testDefaults(suiteName: "WelcomeCoverFallbackAfterAdoptTests.\(UUID().uuidString)"))
        #expect(!Logic.onboardingCompletedNow(defaults))
        // Lo que hace `onAdoptStarted` con el cover ya presentado.
        defaults.set(true, forKey: AppPreferences.Keys.hasCompletedOnboarding)
        #expect(Logic.onboardingCompletedNow(defaults))
        // Y la clave es la del `@AppStorage` de `ContentView`: si divergieran, leería otra cosa.
        #expect(AppPreferences.Keys.hasCompletedOnboarding == "hasCompletedOnboarding")
    }

    // MARK: - Cableado

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // WelcomeNoRelaunchAfterAdopt/
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // raíz del repo
    }

    /// El cuerpo de `welcomeCoverDidDismiss`, sin comentarios y en una línea.
    private static func dismissBody() throws -> String {
        let source = try String(contentsOf: repoRoot.appendingPathComponent("Yala/App/ContentView.swift"), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
        let marker = "private func welcomeCoverDidDismiss() {"
        let start = try #require(source.range(of: marker), "no encuentro welcomeCoverDidDismiss en ContentView")
        let chars = Array(source[start.upperBound...])
        var depth = 1, i = 0
        while i < chars.count {
            if chars[i] == "{" { depth += 1 }
            if chars[i] == "}" { depth -= 1; if depth == 0 { break } }
            i += 1
        }
        return String(chars[0..<i]).split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    @Test("el respaldo decide con el almacén leído ahora, no con el @AppStorage que guardó al presentar el cover")
    func fallbackReadsTheStoreNow() throws {
        let body = try Self.dismissBody()
        #expect(body.contains(
            "WelcomeCoverContentLogic.dismissFallbackReopensChooser( onboardingCompleted: WelcomeCoverContentLogic.onboardingCompletedNow(),"),
            "el respaldo ya no lee el onboarding en el momento: \(body)")
        // Ninguna lectura de la propiedad de la vista, en ninguna forma: es la que llegaba con el valor de antes del adopt.
        let tokens = body.components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_")).inverted)
        #expect(!tokens.contains("hasCompletedOnboarding"),
                "welcomeCoverDidDismiss vuelve a leer hasCompletedOnboarding de la vista: \(body)")
    }
}
