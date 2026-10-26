//
//  SharedImageRecoveryGateTests.swift
//  YalaTests
//

import Foundation
import Testing
@testable import Yala

@Suite("SharedImageRecoveryGate")
struct SharedImageRecoveryGateTests {

    @Test func allReady_reEmits() {
        #expect(SharedImageRecoveryGate.shouldReEmit(
            hasPendingImage: true, isInitialized: true, hasCompletedOnboarding: true, isHeldForProGate: false))
    }

    @Test func noPendingImage_doesNotReEmit() {
        #expect(!SharedImageRecoveryGate.shouldReEmit(
            hasPendingImage: false, isInitialized: true, hasCompletedOnboarding: true, isHeldForProGate: false))
    }

    @Test func notInitialized_doesNotReEmit() {
        // El caso del bug: pre-`isInitialized` el submit se diferiría y el intent
        // no-serializable se descartaría → NO re-emitir, esperar a la ventana ready.
        #expect(!SharedImageRecoveryGate.shouldReEmit(
            hasPendingImage: true, isInitialized: false, hasCompletedOnboarding: true, isHeldForProGate: false))
    }

    @Test func onboardingIncomplete_doesNotReEmit() {
        #expect(!SharedImageRecoveryGate.shouldReEmit(
            hasPendingImage: true, isInitialized: true, hasCompletedOnboarding: false, isHeldForProGate: false))
    }

    /// Card fazw: con la tanda retenida por «Función Pro», volver a primer plano (la hoja de compra de la App Store)
    /// no saca otra puerta encima.
    @Test func heldForTheProGate_doesNotReEmit() {
        #expect(!SharedImageRecoveryGate.shouldReEmit(
            hasPendingImage: true, isInitialized: true, hasCompletedOnboarding: true, isHeldForProGate: true))
    }
}

@MainActor
@Suite("La foto compartida que choca con «Función Pro»", .serialized)
struct SharedImageProGateHoldTests {

    private let photo = URL(fileURLWithPath: "/tmp/PendingImages/recibo-1.jpg")

    @Test func purchase_handsThePhotoToTheImageEntry_once() {
        defer { _ = SharedImageProGateHold.takeForUnlock() }
        SharedImageProGateHold.hold(photo)
        #expect(SharedImageProGateHold.isHolding)
        #expect(SharedImageProGateHold.takeForUnlock() == photo)
        #expect(!SharedImageProGateHold.isHolding)
        // Una segunda compra (o abrir Foto desde el Panel) ya no trae una foto vieja.
        #expect(SharedImageProGateHold.takeForUnlock() == nil)
    }

    @Test func closingWithoutBuying_discardsTheBatch_asBefore() {
        var removed: [URL] = []
        SharedImageProGateHold.hold(photo)
        SharedImageProGateHold.discard { removed.append($0) }
        #expect(removed == [photo])
        #expect(!SharedImageProGateHold.isHolding)
        // Cerrar una hoja que no venía de una foto compartida no borra nada.
        SharedImageProGateHold.discard { removed.append($0) }
        #expect(removed == [photo])
    }

    /// El cableado: la puerta retiene en vez de borrar, la recuperación lo respeta y el Panel entrega o descarta.
    @Test func wiring_holdsAtTheGate_andThePanelResolvesIt() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let boot = try String(contentsOf: root.appendingPathComponent("Yala/App/AppBootstrapper.swift"), encoding: .utf8)
        let gate = boot.components(separatedBy: "private func enqueueSharedImage(_ url: URL) {").dropFirst().first ?? ""
        let gateBranch = gate.components(separatedBy: "SceneRegistry.shared.routingNavigation?.pendingSharedImageURL").first ?? ""
        #expect(gateBranch.contains("SharedImageProGateHold.hold(url)"))
        #expect(gateBranch.contains("guard !SharedImageProGateHold.isHolding else {"))
        #expect(boot.contains("isHeldForProGate: SharedImageProGateHold.isHolding"))

        let panel = try String(
            contentsOf: root.appendingPathComponent("Yala/App/Views/Panel/PanelSheetsModifier.swift"), encoding: .utf8)
        #expect(panel.contains("onClosedWithoutUnlock: { SharedImageProGateHold.discard() }"))
        #expect(panel.contains("if let shared = SharedImageProGateHold.takeForUnlock() {\n                        navigation.pendingSharedImageURL = shared"))
    }
}
