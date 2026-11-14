//
//  EmpezarEntersTheAppTests.swift
//  YalaTests
//
//  Barrido del iPhone 14 (14-nov), lote A, cards c8i9 y x5tm: en la primera entrada tras instalar, «Empezar» de «¡Tu cuenta
//  está lista!» devolvía a la bienvenida. Medido con trazas en el teléfono: el respaldo del `onDismiss` del cover leyó el
//  onboarding como no completado (`onb=false`) con `true` en disco, porque su `@Binding` era el de cuando se presentó el
//  cover y `onAdoptStarted` lo marca con el cover abierto. Y el Panel se quedaba en S/ 0 porque nada lo recalculaba al
//  entrar.
//

import Foundation
import Testing
@testable import Yala

@Suite("Lote A · «Empezar» entra en la app (c8i9, x5tm)")
struct EmpezarEntersTheAppTests {

    /// Con el onboarding ya completo en disco no se vuelve al elector, aunque nada más esté pedido: es el caso del barrido.
    @Test func completedOnboarding_neverReopensTheChooser() {
        #expect(!WelcomeCoverContentLogic.reopensChooserAfterCloudSignIn(
            onboardingCompletedNow: true, inviteOnboardingShown: false, onboardingShown: false, welcomeFlowShown: false))
    }

    /// El respaldo de siempre sigue: el cover que UIKit tumba sin terminal, sin onboarding, vuelve al elector.
    @Test func withoutOnboarding_andNothingElseShown_reopensTheChooser() {
        #expect(WelcomeCoverContentLogic.reopensChooserAfterCloudSignIn(
            onboardingCompletedNow: false, inviteOnboardingShown: false, onboardingShown: false, welcomeFlowShown: false))
        for (invite, onboarding, flow) in [(true, false, false), (false, true, false), (false, false, true)] {
            #expect(!WelcomeCoverContentLogic.reopensChooserAfterCloudSignIn(
                onboardingCompletedNow: false, inviteOnboardingShown: invite, onboardingShown: onboarding,
                welcomeFlowShown: flow))
        }
    }

    private static func flatContentView() throws -> String {
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        let text = try String(contentsOf: repo.appendingPathComponent("Yala/App/ContentView.swift"), encoding: .utf8)
        return text.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.hasPrefix("//") }.joined(separator: " ")
    }

    /// El respaldo lee el onboarding de disco, no del `@Binding` que el `onDismiss` se quedó.
    @Test func dismissFallback_readsTheOnboardingFromDisk() throws {
        let src = try Self.flatContentView()
        let start = try #require(src.range(of: "private func welcomeCoverDidDismiss() {"))
        let body = String(src[start.upperBound...].prefix(900))
        #expect(body.contains(
            "let onboardingCompletedNow = UserDefaults.standard.bool(forKey: AppPreferences.Keys.hasCompletedOnboarding)"))
        #expect(body.contains("WelcomeCoverContentLogic.reopensChooserAfterCloudSignIn( onboardingCompletedNow: onboardingCompletedNow,"))
        #expect(!body.contains("!hasCompletedOnboarding"), "la lectura del binding es la que se quedaba vieja")
    }

    /// «Empezar» hace recalcular las pantallas montadas bajo la bienvenida, que calcularon antes de entrar.
    @Test func empezar_bumpsTheDataVersion() throws {
        let src = try Self.flatContentView()
        let start = try #require(src.range(of: "onFinishedToApp: {"))
        let body = String(src[start.upperBound...].prefix(700))
        let bump = try #require(body.range(of: "SessionState.shared.incrementDataVersion()"))
        let close = try #require(body.range(of: "showWelcomeCloudSignIn = false"))
        #expect(bump.lowerBound < close.lowerBound)
        #expect(body.contains("if WelcomeGroupsDoorLanding.consume() { navigation.selectMainTab(.groups) }"))
    }
}
