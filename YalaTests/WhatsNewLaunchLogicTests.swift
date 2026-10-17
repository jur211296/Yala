//
//  WhatsNewLaunchLogicTests.swift
//  YalaTests
//
//  Cuándo sale la hoja de Novedades: solo al actualizar (decisión de Jürgen, 16-oct-2026).
//  Cada caso recorre el arranque entero tal como lo hace `ContentView`: primero la marca de
//  instalación nueva (`versionToMarkSeenAtLaunch`), después la decisión (`shouldPresent`).
//

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
}
