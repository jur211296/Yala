//
//  ReopenOnlyForPrivateICloudWiringTests.swift
//  YalaTests
//
//  Card ypit · decisión de Jürgen del 22-oct: «Reabre Yala» solo al entrar en el iCloud privado. Los dos sitios que ya
//  montan sin espejo cierran con el cambio en caliente del cierre de sesión en la nube (`PersonalContainerSwap`), con la
//  misma red: el borrado se arma ANTES y, si el cambio no puede, el arranque siguiente hace lo de siempre.
//
//    · la celda solo-grupos del cierre de sesión (Ajustes y la puerta de Grupos del Welcome);
//    · «Borrar mi cuenta» en la nube y en solo-grupos sin sesión privada (los dos por `closeLocalAfterAccountDeletionCloud`).
//
//  El cambio en sí no se puede ejercitar en un test: necesita soltar el contenedor de la app (lo midió el spike R3 en
//  device) y una sesión real. Lo que se fija es el ORDEN contra el arm, que es lo que hace que fallar sea seguro, y que
//  el destino del Welcome se escriba antes del cambio. El resto va al device-QA de la card.
//

import Foundation
import Testing
@testable import Yala

@MainActor
struct ReopenOnlyForPrivateICloudWiringTests {

    private static func source(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/CloudSync/
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// El cuerpo de una función: desde su firma hasta la siguiente declaración de función del mismo nivel.
    private static func body(of signature: String, in src: String) -> String? {
        guard let start = src.range(of: signature) else { return nil }
        let rest = src[start.upperBound...]
        let next = rest.range(of: "\n    func ") ?? rest.range(of: "\n    private func ")
        let nextPrivate = rest.range(of: "\n    private func ")
        let nextStatic = rest.range(of: "\n    private static func ")
        let ends = [next, nextPrivate, nextStatic].compactMap { $0?.lowerBound }
        guard let end = ends.min() else { return String(rest) }
        return String(rest[..<end])
    }

    /// Las posiciones de cada marca, en el orden en que deben aparecer. `nil` si falta alguna.
    private static func offsets(_ marks: [String], in text: String) -> [String.Index]? {
        var result: [String.Index] = []
        for mark in marks {
            guard let r = text.range(of: mark) else { return nil }
            result.append(r.lowerBound)
        }
        return result
    }

    private static let coordinator = "Yala/Services/CloudSync/CloudSessionSignOut.swift"

    @Test func groupsOnlyCell_swapsAfterTheArm_andOnlyThatCell() throws {
        let src = try Self.source(Self.coordinator)
        let cuerpo = try #require(Self.body(of: "private func armAfterCredentials(", in: src))
        let marcas = [
            "StorageModePersistence.armSignOutWipe()",
            "persistDestinationOnArm()",
            "phase = .awaitingRelaunch",
            "guard kind == .groupsOnly else { return }",
            "await PersonalContainerSwap.attemptSignOutSwap() == .swapped",
            "phase = .idle",
        ]
        let pos = try #require(Self.offsets(marcas, in: cuerpo), "Falta una pieza del cierre en caliente de solo-grupos")
        #expect(pos == pos.sorted(), "El orden arm → destino → fase → solo-grupos → cambio en caliente se rompió")
    }

    @Test func cloudSignOut_writesTheWelcomeDestinationBeforeTheSwap() throws {
        let src = try Self.source(Self.coordinator)
        let cuerpo = try #require(Self.body(of: "private func performCloudSecureSignOut(", in: src))
        let marcas = [
            "StorageModePersistence.armSignOutWipe()",
            "persistDestinationOnArm()",
            "phase = .awaitingRelaunch",
            "await PersonalContainerSwap.attemptSignOutSwap() == .swapped",
        ]
        let pos = try #require(Self.offsets(marcas, in: cuerpo))
        #expect(pos == pos.sorted())
    }

    @Test func accountDeletion_swapsAfterTheArm() throws {
        let src = try Self.source(Self.coordinator)
        let cuerpo = try #require(Self.body(of: "func closeLocalAfterAccountDeletionCloud()", in: src))
        let marcas = [
            "StorageModePersistence.armSignOutWipe()",
            "phase = .awaitingRelaunch",
            "await PersonalContainerSwap.attemptSignOutSwap() == .swapped",
            "phase = .idle",
            "return true",
        ]
        let pos = try #require(Self.offsets(marcas, in: cuerpo))
        #expect(pos == pos.sorted())
    }

    /// El borrado solo-grupos CON sesión privada monta el espejo: se queda con el relanzamiento, a propósito.
    @Test func groupsOnlyDeletionWithAPrivateSession_keepsTheRelaunch() throws {
        let src = try Self.source(Self.coordinator)
        let cuerpo = try #require(Self.body(of: "func closeLocalAfterAccountDeletionGroupsOnly(", in: src))
        #expect(!cuerpo.contains("attemptSignOutSwap"))
    }

    @Test func welcomeGroupsGate_handsItsDestinationToTheCoordinator() throws {
        let gate = try Self.source("Yala/App/Views/Onboarding/WelcomeGroupsGateView.swift")
        #expect(gate.contains("destinationOnArm: purpose.destinationAfterNeutralReturn,"))
        let shell = try Self.source("Yala/App/ContentView.swift")
        #expect(shell.contains("if let destination = purpose.destinationAfterNeutralReturn {"),
                "ContentView debe decidir el destino con la misma regla que el coordinador")
    }

    /// Un destino de un cierre bloqueado no lo hereda el siguiente: reconocer el bloqueo lo retira.
    @Test func blockedExit_dropsTheDestination() throws {
        let src = try Self.source(Self.coordinator)
        let cuerpo = try #require(Self.body(of: "func acknowledgeBlocked()", in: src))
        #expect(cuerpo.contains("destinationOnArm = nil"))
    }
}

extension ReopenOnlyForPrivateICloudWiringTests {

    /// El cover terminal se retira cuando el cierre se consuma en caliente, y no se arma mientras el remonte sigue. Sin las
    /// dos, el `ContentView` nuevo veía `.awaitingRelaunch` al aparecer y se quedaba con «cierra Yala» para siempre.
    @Test func relaunchCover_standsDownOnIdle_andDoesNotArmDuringTheInPlaceRemount() throws {
        let src = try Self.source("Yala/App/ContentView.swift")
        let start = try #require(src.range(of: "private struct SignOutRelaunchNetModifier: ViewModifier {"))
        let rest = src[start.upperBound...]
        let end = try #require(rest.range(of: "private struct ForceUpdateNetModifier"))
        let net = String(rest[..<end.lowerBound])
        #expect(net.contains("if newPhase == .idle { standDown() }"))
        let arm = try #require(Self.body(of: "private func arm() {", in: net))
        let guardRange = try #require(arm.range(of: "guard !PersonalContainerSwap.inPlaceRemountInFlight else { return }"))
        let showRange = try #require(arm.range(of: "showRelaunchCover = true"))
        #expect(guardRange.lowerBound < showRange.lowerBound, "El cover se arma antes de mirar el remonte en caliente")
        let standDown = try #require(Self.body(of: "private func standDown() {", in: net))
        #expect(standDown.contains("showRelaunchCover = false"))
    }

    /// Con un cierre que espera relanzar, el `ContentView` remontado (swap abortado) no presenta ni consume el destino.
    @Test func awaitingRelaunch_keepsTheWelcomeDestinationForTheNextLaunch() throws {
        let src = try Self.source("Yala/App/ContentView.swift")
        let cuerpo = try #require(Self.body(of: "private func presentNextOnboardingScreen() {", in: src))
        let lines = cuerpo.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        // Desde la card 7e60 (2026-10-28) el `guard` apunta lo que calla —para retomarlo si el cambio en caliente sale y la
        // fase vuelve a reposo— y no hace NADA más: ni consume el destino ni presenta.
        #expect(Array(lines.prefix(4)) == [
            "guard CloudSessionSignOut.shared.phase != .awaitingRelaunch else {",
            "onboardingRoutingDeferredForRelaunch = true",
            "return",
            "}",
        ])
    }

    /// El cambio en caliente no hereda la cancelación de quien lo pide (la puerta del Welcome lo pide desde un `.task`
    /// que el propio cambio desmonta), y marca la ventana del remonte.
    @Test func swap_runsDetachedFromTheCaller_andMarksTheRemount() throws {
        let src = try Self.source("Yala/Services/CloudSync/PersonalContainerSwap.swift")
        let entrada = try #require(Self.body(of: "static func attemptSignOutSwap() async -> Outcome {", in: src))
        #expect(entrada.contains("await Task { @MainActor in await performSignOutSwap() }.value"))
        let marks = [
            "inPlaceRemountInFlight = true",
            "defer { inPlaceRemountInFlight = false }",
            "PersonalContainerHost.shared.adoptAfterSwap(fresh)",
            "await AppBootstrapper.shared.rebootstrapAfterSwap(container: fresh)",
        ]
        let pos = try #require(Self.offsets(marks, in: src))
        #expect(pos == pos.sorted())
    }
}

/// La regla del destino tras la vuelta al neutro, que comparten el coordinador y `ContentView`.
@MainActor
@Suite(.serialized)
struct WelcomeGroupsGateDestinationTests {

    private func withIsolatedResumeStore(_ body: () -> Void) {
        let suite = "WelcomeGroupsGateDestinationTests.\(UUID().uuidString)"
        let previous = GroupInviteResumeStore.defaults
        let defaults = UserDefaults(suiteName: suite)!
        GroupInviteResumeStore.defaults = defaults
        defer {
            GroupInviteResumeStore.defaults = previous
            defaults.removePersistentDomain(forName: suite)
        }
        body()
    }

    @Test func organizer_goesBackToCreatingTheGroup() {
        withIsolatedResumeStore {
            #expect(WelcomeGroupsGateView.Purpose.createGroup.destinationAfterNeutralReturn == .groupsOrganizer)
        }
    }

    @Test func invite_withItsEnvelope_goesBackToTheInvite() {
        withIsolatedResumeStore {
            GroupInviteResumeStore.set(groupID: "zona-a", token: "tok")
            #expect(WelcomeGroupsGateView.Purpose.acceptInvite(groupID: "zona-a").destinationAfterNeutralReturn == .groupsInvite)
        }
    }

    @Test func invite_withoutItsEnvelope_hasNowhereToGo() {
        withIsolatedResumeStore {
            #expect(WelcomeGroupsGateView.Purpose.acceptInvite(groupID: "zona-a").destinationAfterNeutralReturn == nil)
            GroupInviteResumeStore.set(groupID: "zona-b", token: "tok")
            #expect(WelcomeGroupsGateView.Purpose.acceptInvite(groupID: "zona-a").destinationAfterNeutralReturn == nil)
        }
    }
}
