//
//  InviteOpeningTests.swift
//  YalaTests / Groups
//
//  Abrir un enlace de invitación en una instalación nueva (card z81w del QA guiado del TF19, 2026-10-20): la bienvenida
//  salía 10-15 s, interactiva, antes de «Conecta tu cuenta». Decisión de Jürgen: «Abriendo tu invitación…» desde el
//  primer instante y sin botones, y no esperar a la importación de iCloud para encaminar.
//

import Foundation
import Testing

@testable import Yala

@Suite("Abriendo tu invitación · la decisión (z81w)")
@MainActor
struct InviteOpeningLogicTests {

    /// Solo con la bienvenida delante. Control: con la app en uso, la invitación sigue su camino sobre la pestaña.
    @Test func laPantallaSoloSaleSinOnboarding() {
        #expect(InviteOpeningLogic.showsOpeningScreen(hasCompletedOnboarding: false))
        #expect(!InviteOpeningLogic.showsOpeningScreen(hasCompletedOnboarding: true))
    }

    /// El caso de la card: enlace en este arranque, montaje sin espejo y modo `.icloud` ⇒ encamina ya.
    @Test func sinEspejo_conEnlace_encaminaSinEsperarAlImport() {
        #expect(InviteOpeningLogic.routesWithoutImportWait(
            mountAttachesMirror: false, storageMode: .icloud, tappedBackendInviteThisLaunch: true))
    }

    /// Controles: donde esperar era lo correcto, sigue esperando.
    @Test func losControles_siguenEsperando() {
        // Con el espejo montado hay un import que puede chocar con el guardado del contexto compartido.
        #expect(!InviteOpeningLogic.routesWithoutImportWait(
            mountAttachesMirror: true, storageMode: .icloud, tappedBackendInviteThisLaunch: true))
        // En la nube la quiescencia es la del motor, otra cosa.
        #expect(!InviteOpeningLogic.routesWithoutImportWait(
            mountAttachesMirror: false, storageMode: .cloud, tappedBackendInviteThisLaunch: true))
        // Sin enlace en este arranque nadie mira la pantalla: el arranque no cambia.
        #expect(!InviteOpeningLogic.routesWithoutImportWait(
            mountAttachesMirror: false, storageMode: .icloud, tappedBackendInviteThisLaunch: false))
    }

    /// El techo existe y es corto: una pantalla sin botones no puede durar.
    @Test func elTecho() {
        #expect(InviteOpeningLogic.ceiling == 20)
    }

    /// Solo se sustituyen los pasos sin trabajo en vuelo; una puerta midiendo o borrando no se desmonta.
    @Test func quePasosSeSustituyen() {
        for step in [WelcomeFlowStep.hero, .chooser, .existingChooser, .newChooser, .groupsChooser] {
            #expect(step.isPlainNavigation, "\(step)")
        }
        for step in [WelcomeFlowStep.privateICloudGate, .freshStartDeviceWipe, .mirrorRelaunch,
                     .groupsGate(purpose: .createGroup)] {
            #expect(!step.isPlainNavigation, "\(step)")
        }
    }
}

@Suite("Abriendo tu invitación · el estado del proceso (z81w)", .serialized)
@MainActor
struct InviteOpeningStateTests {

    @Test func empiezaUnaVez_yTerminaConQuienLaRelevaba() {
        // Instancia propia: la app anfitriona pinta la pantalla con `.shared`, y su `onAppear` arrancaría el techo.
        let state = InviteOpeningState()

        #expect(!state.isOpening)
        state.begin(origin: "cold")
        #expect(state.isOpening)
        state.begin(origin: "warm")       // idempotente
        #expect(state.isOpening)
        state.finish(.handedOver)
        #expect(!state.isOpening)
        state.finish(.ceiling)            // sin efecto si ya terminó
        #expect(!state.isOpening)
    }

    /// El techo devuelve la bienvenida aunque nadie releve: no hay camino muerto.
    @Test func elTechoLaApaga() async throws {
        // Instancia propia: la app anfitriona pinta la pantalla con `.shared`, y su `onAppear` arrancaría el techo.
        let state = InviteOpeningState()
        state.ceiling = 0.05

        state.begin(origin: "cold")
        #expect(state.isOpening)
        // Sin pantalla, el techo no corre: en frío el enlace llega antes de que haya bienvenida que tapar.
        try await Task.sleep(for: .milliseconds(150))
        #expect(state.isOpening)
        state.screenAppeared()
        for _ in 0..<40 where state.isOpening {
            try await Task.sleep(for: .milliseconds(25))
        }
        #expect(!state.isOpening)
    }
}

/// El cableado, por source-scan: los sitios que la encienden y la apagan, y el encaminamiento del arranque. Las líneas se
/// comparan recortadas y unidas por `\n`, para que la sangría no decida.
@Suite("Abriendo tu invitación · cableado (z81w)")
struct InviteOpeningWiringTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/Groups/
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    /// El fichero sin comentarios y con cada línea recortada.
    private static func code(_ path: String) throws -> String {
        let source = try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
        return source.split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.hasPrefix("//") }
            .joined(separator: "\n")
    }

    private static func lines(_ lines: String...) -> String { lines.joined(separator: "\n") }

    @Test func elEnlaceLaEnciende_yElQueNoSePuedeAbrirLaApaga() throws {
        let boot = try Self.code("Yala/App/AppBootstrapper.swift")
        #expect(boot.contains(Self.lines(
            "case .backend, .refreshFlagsThenRetry:",
            "if InviteOpeningLogic.showsOpeningScreen(")))
        #expect(boot.contains("InviteOpeningState.shared.begin(origin: isInitialized ? \"warm\" : \"cold\")"))
        #expect(boot.contains(Self.lines(
            "case .ckShare, .backendUnavailable:",
            "InviteOpeningState.shared.finish(.linkFailed)")))
    }

    @Test func laCadenaDelInvitado_laApagaAlDrenar() throws {
        let content = try Self.code("Yala/App/ContentView.swift")
        #expect(content.contains(Self.lines(
            "if intent.supersedesWelcomeChain {",
            "InviteOpeningState.shared.finish(.handedOver)",
            "}")))
        let handler = try Self.code("Yala/App/Services/GroupBackendInviteEntryHandler.swift")
        #expect(handler.contains(Self.lines(
            "await attemptJoin(groupID: groupID, token: token, source: source)",
            "InviteOpeningState.shared.finish(.joinAttempted)")))
    }

    @Test func elReconcilerDelArranque_noEsperaAlImportConUnEnlaceSinEspejo() throws {
        let boot = try Self.code("Yala/App/AppBootstrapper.swift")
        #expect(boot.contains("let routesInviteNow = InviteOpeningLogic.routesWithoutImportWait("))
        #expect(boot.contains("mountAttachesMirror: CloudSessionSignOut.personalMountAttachesMirror,"))
        // Y sigue siendo el reconciler del arranque el que encamina, detrás de esa puerta.
        #expect(boot.contains(Self.lines("if routesInviteNow {", "storeReady = true", "} else {",
                                          "storeReady = await awaitPersonalStoreReady()", "}")))
        let gate = try #require(boot.range(of: "if routesInviteNow {"))
        let reconcile = try #require(boot.range(of: "await GroupJoinReconciler.reconcile(trigger: .boot, context: context)"))
        #expect(gate.lowerBound < reconcile.lowerBound)
    }

    @Test func laBienvenida_tapaElStepSinBotones() throws {
        let container = try Self.code("Yala/App/Views/Onboarding/WelcomeFlowContainer.swift")
        // Sustituye a los pasos de pura navegación…
        #expect(container.contains("if InviteOpeningState.shared.isOpening && step.isPlainNavigation {"))
        // …y tapa los demás sin desmontarlos.
        #expect(container.contains(".allowsHitTesting(!coversStepWithInviteOpening)"))
        #expect(container.contains(".accessibilityHidden(coversStepWithInviteOpening)"))
        #expect(container.components(separatedBy: "WelcomeInviteOpeningView()").count - 1 == 2)
        let view = try Self.code("Yala/App/Views/Onboarding/WelcomeInviteOpeningView.swift")
        #expect(!view.contains("Button"), "la pantalla de apertura no lleva botones (decisión de Jürgen)")
        #expect(!view.contains("welcomeBackButton"))
    }
}
