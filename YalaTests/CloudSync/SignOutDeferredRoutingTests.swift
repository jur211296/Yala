//
//  SignOutDeferredRoutingTests.swift
//  YalaTests
//
//  Card 7e60 (Jürgen, 2026-10-28): tras cerrar sesión aceptando perder los cambios, la app «se cerró». El cierre que no
//  pide reabrir cambia el almacén en caliente y monta un `ContentView` nuevo con la fase aún en `.awaitingRelaunch`: su
//  arranque callaba el Welcome y nadie lo retomaba al volver la fase a `.idle`. Sin un solo botón en pantalla.
//
//  El cambio en caliente no se puede ejercitar en el simulador (monta con espejo y se salta: lo midió el XCUITest de la
//  celda F, que acaba en la pantalla de reabrir). Lo que se fija es CUÁNDO se retoma y que el cableado lo haga.
//

import Foundation
import Testing
@testable import Yala

@MainActor
struct SignOutDeferredRoutingTests {

    @Test("MUTACIÓN: se retoma solo con algo aplazado y la fase de vuelta en reposo")
    func resumesOnlyWhenDeferredAndIdle() {
        #expect(SignOutDeferredRoutingLogic.resumes(deferred: true, phase: .idle))
        #expect(!SignOutDeferredRoutingLogic.resumes(deferred: false, phase: .idle))
        // El cambio abortó: manda el cover terminal y el destino del arranque siguiente queda intacto.
        #expect(!SignOutDeferredRoutingLogic.resumes(deferred: true, phase: .awaitingRelaunch))
        #expect(!SignOutDeferredRoutingLogic.resumes(deferred: true, phase: .working))
        #expect(!SignOutDeferredRoutingLogic.resumes(deferred: true,
                                                     phase: .blocked(pendingCount: 1, reason: .transient)))
    }

    private static func source(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line in line.range(of: "//").map { String(line[..<$0.lowerBound]) } ?? String(line) }
            .joined(separator: " ")
            .split(whereSeparator: { $0 == " " || $0 == "\t" }).joined(separator: " ")
    }

    @Test("MUTACIÓN: el arranque apunta lo que calla y el cambio de fase lo retoma con el onboarding sin hacer")
    func contentViewDefersAndResumes() throws {
        let src = try Self.source("Yala/App/ContentView.swift")
        #expect(src.contains("""
            guard CloudSessionSignOut.shared.phase != .awaitingRelaunch else { \
            onboardingRoutingDeferredForRelaunch = true return }
            """))
        #expect(src.contains("""
            drainContentViewIntents() } resumeOnboardingRoutingDeferredForRelaunch() }
            """))
        #expect(src.contains("""
            guard SignOutDeferredRoutingLogic.resumes(deferred: onboardingRoutingDeferredForRelaunch, \
            phase: CloudSessionSignOut.shared.phase) else { return } onboardingRoutingDeferredForRelaunch = false \
            guard !hasCompletedOnboarding, !showWelcomeFlow, !showGroupInviteOnboarding else { return } \
            presentNextOnboardingScreen() }
            """))
        // La fase vuelve a reposo SOLO cuando el cambio salió: es lo que hace seguro retomar en `.idle`.
        let signOut = try Self.source("Yala/Services/CloudSync/CloudSessionSignOut.swift")
        #expect(signOut.contains("if await PersonalContainerSwap.attemptSignOutSwap() == .swapped { phase = .idle }"))
    }
}
