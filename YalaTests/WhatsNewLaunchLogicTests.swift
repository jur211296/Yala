//
//  WhatsNewLaunchLogicTests.swift
//  YalaTests
//
//  Cuándo sale la hoja de Novedades: solo al actualizar (decisión de Jürgen, 16-oct-2026).
//  Cada caso recorre el arranque entero tal como lo hace `ContentView`: primero la marca de
//  instalación nueva (`versionToMarkSeenAtLaunch`), después la decisión (`shouldPresent`).
//

import Foundation
import Testing

@testable import Yala

struct WhatsNewLaunchLogicTests {

    /// Simula un arranque: aplica la marca de instalación nueva y devuelve si la hoja sale,
    /// junto con el `lastSeenAppVersion` que queda tras el arranque (la hoja guarda la versión al cerrarse).
    private func launch(
        current: String, lastSeen: String, hasCompletedOnboarding: Bool
    ) -> (presents: Bool, lastSeenAfter: String) {
        var lastSeen = lastSeen
        if let mark = WhatsNewLaunchLogic.versionToMarkSeenAtLaunch(
            hasCompletedOnboarding: hasCompletedOnboarding, currentVersion: current
        ) {
            lastSeen = mark
        }
        let presents = WhatsNewLaunchLogic.shouldPresent(
            currentVersion: current, lastSeenVersion: lastSeen,
            hasFeatures: WhatsNewConfig.features(for: current) != nil
        )
        return (presents, presents ? current : lastSeen)
    }

    @Test func instalacionNueva_noSaleNiTrasElOnboardingNiEnElArranqueSiguiente() {
        // Primer arranque: onboarding sin hacer, sin versión vista.
        let first = launch(current: "2.1", lastSeen: "", hasCompletedOnboarding: false)
        #expect(!first.presents)
        #expect(first.lastSeenAfter == "2.1", "La instalación nueva tiene que dejar la versión como vista.")
        // Arranque siguiente, ya con el onboarding hecho.
        let second = launch(current: "2.1", lastSeen: first.lastSeenAfter, hasCompletedOnboarding: true)
        #expect(!second.presents)
    }

    @Test func actualizacionDesde2_0_saleUnaVezYNoVuelve() {
        let first = launch(current: "2.1", lastSeen: "2.0.4", hasCompletedOnboarding: true)
        #expect(first.presents)
        let second = launch(current: "2.1", lastSeen: first.lastSeenAfter, hasCompletedOnboarding: true)
        #expect(!second.presents)
    }

    @Test func usuarioDe2_0QueNuncaVioUnaHoja_laVeAlActualizar() {
        // Onboarding hecho en 2.0 y `lastSeenAppVersion` vacío: es quien SÍ actualiza.
        #expect(launch(current: "2.1", lastSeen: "", hasCompletedOnboarding: true).presents)
    }

    @Test func yaVista_noSale() {
        #expect(!launch(current: "2.1", lastSeen: "2.1", hasCompletedOnboarding: true).presents)
    }

    @Test func hotfixSobre2_1_noVuelveASalir() {
        #expect(!launch(current: "2.1.1", lastSeen: "2.1", hasCompletedOnboarding: true).presents)
        #expect(!launch(current: "2.1.2", lastSeen: "2.1.1", hasCompletedOnboarding: true).presents)
    }

    @Test func hotfixQueLlegaDesde2_0_siSale() {
        // Quien salta de 2.0.4 directo a 2.1.1 no ha visto las de 2.1.
        #expect(launch(current: "2.1.1", lastSeen: "2.0.4", hasCompletedOnboarding: true).presents)
    }

    @Test func versionSinEntrada_noSale() {
        #expect(!launch(current: "9.9", lastSeen: "2.1", hasCompletedOnboarding: true).presents)
    }

    @Test func entradaDe2_1_tresTarjetasEnOrden() throws {
        let features = try #require(WhatsNewConfig.features(for: "2.1"))
        #expect(features.map(\.icon) == ["person.2.fill", "mic.fill", "lock.fill"])
        #expect(features.map(\.title) == [
            L10n.WhatsNew.v21GroupsTitle, L10n.WhatsNew.v21LoggingTitle, L10n.WhatsNew.v21DataTitle,
        ])
        #expect(WhatsNewConfig.features(for: "2.1.3") == features)
    }

    @Test func majorMinor() {
        #expect(WhatsNewLaunchLogic.majorMinor("2.1.1") == "2.1")
        #expect(WhatsNewLaunchLogic.majorMinor("2.1") == "2.1")
        #expect(WhatsNewLaunchLogic.majorMinor("") == "")
    }

    // MARK: - Qué hoja enseña el arranque de quien vuelve (ticket `whats-new-yields-to-a-pending-trial-offer-after-updating`)

    @Test("MUTACIÓN: con Novedades y la oferta de prueba pendientes, sale Novedades (la oferta, en el arranque siguiente)")
    func returningUser_whatsNewBeatsAPendingTrialOffer() {
        #expect(WhatsNewLaunchLogic.returningUserSheet(
            hasPrivateSession: true, whatsNewPending: true, trialOfferPending: true, isPro: false) == .whatsNew)
    }

    @Test("Controles: lo que el arranque viejo ya hacía bien")
    func returningUser_controls() {
        // Solo la oferta pendiente: sale la oferta.
        #expect(WhatsNewLaunchLogic.returningUserSheet(
            hasPrivateSession: true, whatsNewPending: false, trialOfferPending: true, isPro: false) == .trialOffer)
        // Solo Novedades: salen Novedades.
        #expect(WhatsNewLaunchLogic.returningUserSheet(
            hasPrivateSession: true, whatsNewPending: true, trialOfferPending: false, isPro: false) == .whatsNew)
        // Pro no ve la oferta.
        #expect(WhatsNewLaunchLogic.returningUserSheet(
            hasPrivateSession: true, whatsNewPending: false, trialOfferPending: true, isPro: true) == .none)
        // Sin sesión privada (solo Grupos), ninguna de las dos.
        #expect(WhatsNewLaunchLogic.returningUserSheet(
            hasPrivateSession: false, whatsNewPending: true, trialOfferPending: true, isPro: false) == .none)
        #expect(WhatsNewLaunchLogic.returningUserSheet(
            hasPrivateSession: true, whatsNewPending: false, trialOfferPending: false, isPro: false) == .none)
    }

    @Test("El arranque de quien vuelve decide con la tabla y encola lo que dice")
    func returningUser_wiring() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let src = try String(contentsOf: root.appendingPathComponent("Yala/App/ContentView.swift"), encoding: .utf8)
        // Desde la card y2vg la decisión vive en su propia función, que llaman el arranque y la primera activación.
        let start = try #require(src.range(of: "private func presentReturningUserSheetIfPending() {"))
        let end = try #require(src.range(of: "private func runReturningUserPostChecks() {", range: start.upperBound..<src.endIndex))
        let body = src[start.upperBound..<end.lowerBound].components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty && !$0.hasPrefix("//") }
            .joined(separator: "\n")
        #expect(body.contains("""
            switch WhatsNewLaunchLogic.returningUserSheet(
            hasPrivateSession: !SessionState.shared.isGroupsFocusedShell,
            whatsNewPending: whatsNew != nil,
            trialOfferPending: SessionState.shared.needsPostOnboardingTrial,
            isPro: FeatureGateService.shared.isProUser) {
            case .whatsNew:
            if let whatsNew {
            RouterEntryGate.shared.submit(.presentWhatsNew(features: whatsNew.features, version: whatsNew.version))
            }
            case .trialOffer:
            Task {
            await waitForBootstrap()
            TrialOfferMoments.note(.launch)
            }
            case .none:
            break
            }
            """))
        #expect(!body.contains("} else if let data = whatsNewDataIfPending() {"), "el orden viejo (oferta primero) volvió")
    }

    /// Card y2vg: un arranque en segundo plano no decide la hoja; uno normal (`.inactive` o `.active`) sí.
    @Test func backgroundLaunch_defersTheSheet_andANormalOneDoesNot() {
        #expect(WhatsNewLaunchLogic.defersReturningUserSheet(applicationInBackground: true))
        #expect(!WhatsNewLaunchLogic.defersReturningUserSheet(applicationInBackground: false))
    }

    /// Card y2vg: el arranque aplaza con la app en segundo plano y la primera activación decide lo aplazado. Los dos
    /// tramos, enteros: un `else` perdido o la activación que no lo consume dejarían Novedades para el arranque siguiente.
    @Test func backgroundLaunch_wiring_defersAndTheFirstActivationPresents() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let src = try String(contentsOf: root.appendingPathComponent("Yala/App/ContentView.swift"), encoding: .utf8)
        func code(from startMarker: String, to endMarker: String) throws -> String {
            let start = try #require(src.range(of: startMarker))
            let end = try #require(src.range(of: endMarker, range: start.upperBound..<src.endIndex))
            return src[start.upperBound..<end.lowerBound].components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty && !$0.hasPrefix("//") }
                .joined(separator: "\n")
        }
        let launch = try code(from: "private func runReturningUserPostChecks() {",
                              to: "Task { await AppUpdateService.shared.checkForUpdate() }")
        #expect(launch.hasSuffix("""
            if WhatsNewLaunchLogic.defersReturningUserSheet(applicationInBackground:
            UIApplication.shared.applicationState == .background) {
            ReturningUserSheetDeferral.pendingUntilActive = true
            } else {
            presentReturningUserSheetIfPending()
            }
            """), "El arranque ya no aplaza la hoja con la app en segundo plano: \(launch)")
        let activation = try code(from: "private func handleAppBecameActive() {",
                                  to: "UserSegmentService.shared.recalculate()")
        #expect(activation == """
            if ReturningUserSheetDeferral.pendingUntilActive {
            ReturningUserSheetDeferral.pendingUntilActive = false
            presentReturningUserSheetIfPending()
            }
            """, "La primera activación no decide la hoja aplazada: \(activation)")
    }
}
