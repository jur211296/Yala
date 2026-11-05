//
//  ShellIntegrityNoticeClosesSettingsTests.swift
//  YalaTests
//
//  Card ulks (lote N1 de la 2.3), decisión de Jürgen del 2026-11-04 (opción A): con Ajustes abierto, un aviso de
//  integridad del shell cierra Ajustes y sale al momento. El XCUITest `ShellNoticeOverSettingsUITests` fija el desenlace,
//  pero no distingue el mecanismo: medido el mismo día en iOS 27.2, sin el cierre explícito UIKit tumba Ajustes al
//  presentar encima y el aviso también sale. El cierre explícito quita esa dependencia (no se presenta mientras otra hoja
//  se va) y estos tests son su red.
//

import Foundation
import Testing

@testable import Yala

@Suite("Avisos de integridad · cierran Ajustes antes de salir")
struct ShellIntegrityNoticeClosesSettingsTests {

    @Test("Los cinco avisos de integridad cierran Ajustes; lo que contesta a un toque desde Ajustes, no")
    func classification() {
        for intent: RouterIntent in [.remoteWipe(skipOnboarding: false), .presentRemoteWipeNotice,
                                     .appleIDChangedClosePrivate, .iCloudMismatch] {
            #expect(RouterConsumerGateLogic.closesSettingsFirst(intent), "\(intent.id)")
        }
        // «Activar Yala completo» se toca DESDE Ajustes y sale encima a propósito; cerrarlo dejaría el toque sin respuesta.
        #expect(!RouterConsumerGateLogic.closesSettingsFirst(.presentFullModeActivation))
        #expect(!RouterConsumerGateLogic.closesSettingsFirst(.presentGroupsSignIn(pendingJoin: "")))
        #expect(!RouterConsumerGateLogic.closesSettingsFirst(.showInviteError("")))
        #expect(!RouterConsumerGateLogic.closesSettingsFirst(.remoteOnboardingCompleted))
    }

    @Test("MUTACIÓN: retiene solo con la matriz libre, Ajustes delante y algo presentado de verdad")
    func holdNeedsAllFourTerms() {
        let notice = RouterIntent.appleIDChangedClosePrivate
        #expect(RouterConsumerGateLogic.contentViewClosesSettingsFirst(
            notice, shellClear: true, settingsPresented: true, windowPresentationVisible: true))
        // Una bandera de Ajustes pegada sin nada presentado no retiene: no puede tapar la cola.
        #expect(!RouterConsumerGateLogic.contentViewClosesSettingsFirst(
            notice, shellClear: true, settingsPresented: true, windowPresentationVisible: false))
        // Otra hoja delante (un formulario a medias): el crítico sale como el 11-oct.
        #expect(!RouterConsumerGateLogic.contentViewClosesSettingsFirst(
            notice, shellClear: true, settingsPresented: false, windowPresentationVisible: true))
        // Con la matriz tapada el consumidor ya no drena: la retención no es suya.
        #expect(!RouterConsumerGateLogic.contentViewClosesSettingsFirst(
            notice, shellClear: false, settingsPresented: true, windowPresentationVisible: true))
        #expect(!RouterConsumerGateLogic.contentViewClosesSettingsFirst(
            .presentFullModeActivation, shellClear: true, settingsPresented: true, windowPresentationVisible: true))
    }

    // MARK: - Cableado

    private static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()

    /// Sin las líneas de comentario: un `// hasShownWelcomeChooser = false` no puede contar como el arreglo.
    private static func source(_ path: String) throws -> String {
        try String(contentsOf: root.appending(path: path), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    @Test("Ajustes lleva el modificador en la raíz de su hoja, y el modificador publica y se cierra")
    func settingsAppliesTheModifier() throws {
        let profile = try Self.source("Yala/App/Views/Profile/ProfileView.swift")
        #expect(profile.contains(".modifier(ClosesForShellIntegrityNotice(navigation: navigation) { dismiss() })"))
        let modifier = try Self.source("Yala/App/Views/Profile/ClosesForShellIntegrityNotice.swift")
        #expect(modifier.contains(".onAppear { navigation.isSettingsSheetPresented = true }"))
        #expect(modifier.contains(".onDisappear { navigation.isSettingsSheetPresented = false }"))
        #expect(modifier.contains(".onChange(of: navigation.settingsCloseRequest) { _, _ in close() }"))
    }

    @Test("El drenaje del shell pide el cierre y retiene ANTES de drenar")
    func drainRequestsTheCloseBeforeDraining() throws {
        let view = try Self.source("Yala/App/ContentView.swift")
        let drain = try #require(view.range(of: "private func drainContentViewIntents() {"))
        let body = view[drain.upperBound...]
        let hold = try #require(body.range(of: "RouterConsumerGateLogic.contentViewClosesSettingsFirst("))
        let request = try #require(body.range(of: "navigation.settingsCloseRequest &+= 1", range: hold.upperBound..<body.endIndex))
        let retry = try #require(body.range(of: "scheduleForeignPresentationRedrain()", range: request.upperBound..<body.endIndex))
        let drainNext = try #require(body.range(of: "AppRouter.shared.drainNext(", range: hold.upperBound..<body.endIndex))
        #expect(retry.lowerBound < drainNext.lowerBound)
    }
}
