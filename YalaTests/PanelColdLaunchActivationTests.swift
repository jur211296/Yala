//
//  PanelColdLaunchActivationTests.swift
//  YalaTests
//
//  El Panel no se queda en el esqueleto cuando la carga se pide con la app aún sin activar.
//  Barrido final 2.2 (2026-11-05): en el arranque en frío del iPad el `onAppear` y el cambio de fase llegaban antes de
//  que UIKit marcara la app activa; el freno de recálculo descartaba la petición y nada la repetía.
//
//  Dos piezas, porque la cadena tiene dos eslabones:
//  1. el ViewModel: la petición descartada se repite al activarse, con su recarga, y solo si la hubo;
//  2. la vista: `UIApplication.didBecomeActiveNotification` llega a `applicationDidBecomeActive()` (source-scan).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Panel · la carga pedida antes de activarse la app no se pierde", .serialized)
struct PanelColdLaunchActivationTests {

    /// El ViewModel guarda `sessionState` en `weak`: el test la retiene.
    private let session = SessionState()

    private func makePanel(active: @escaping @MainActor () -> Bool) throws -> PanelViewModel {
        let context = try makeTestContext()
        let viewModel = PanelViewModel()
        viewModel.isApplicationActive = active
        viewModel.setContext(context, defaultCurrencyCode: "PEN", sessionState: session)
        return viewModel
    }

    /// Sondea hasta que el Panel esté listo, con tope: la carga llega tras el freno de 150 ms.
    private func waitForReady(_ viewModel: PanelViewModel) async throws {
        for _ in 0..<50 where !viewModel.isReady {
            try await Task.sleep(for: .milliseconds(20))
        }
    }

    @Test("Carga pedida sin activar → al activarse, el Panel carga")
    func reloadMissedWhileInactive_runsOnActivation() async throws {
        var active = false
        let viewModel = try makePanel(active: { active })

        viewModel.reloadAndRecalculate()
        try await Task.sleep(for: .milliseconds(300))
        #expect(!viewModel.isReady, "Con la app sin activar el freno no carga (es lo que pasaba en el iPad)")
        #expect(viewModel.missedWhileInactive)

        active = true
        viewModel.applicationDidBecomeActive()
        try await waitForReady(viewModel)

        #expect(viewModel.isReady)
        #expect(!viewModel.missedWhileInactive)
    }

    @Test("Control: sin la repetición, el Panel se queda sin cargar aunque la app ya esté activa")
    func withoutActivationHook_staysUnready() async throws {
        var active = false
        let viewModel = try makePanel(active: { active })

        viewModel.reloadAndRecalculate()
        active = true
        try await Task.sleep(for: .milliseconds(400))

        #expect(!viewModel.isReady)
    }

    @Test("Activarse sin nada pendiente no recalcula")
    func activationWithNothingMissed_doesNothing() async throws {
        let viewModel = try makePanel(active: { true })
        viewModel.reloadAndRecalculate()
        try await waitForReady(viewModel)
        let before = viewModel.debugCalculationRuns

        viewModel.applicationDidBecomeActive()
        try await Task.sleep(for: .milliseconds(400))

        #expect(viewModel.debugCalculationRuns == before)
    }

    @Test("Pasar a segundo plano olvida lo pendiente: la vuelta a primer plano ya recarga")
    func background_clearsTheMissedRequest() throws {
        let viewModel = try makePanel(active: { false })
        viewModel.reloadAndRecalculate()
        #expect(viewModel.missedWhileInactive)

        viewModel.setBackground(true)

        #expect(!viewModel.missedWhileInactive)
    }
}

@Suite("Panel · cableado de la activación (source-scan)")
struct PanelActivationObserverWiringTests {

    private static func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    /// Cuerpo normalizado: sin comentarios, líneas recortadas y unidas por espacio.
    private static func normalized(_ text: Substring) -> String {
        text.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("//") && !$0.hasPrefix("///") }
            .joined(separator: " ")
    }

    @Test("El observador recibe `didBecomeActiveNotification` y llama a `applicationDidBecomeActive()`")
    func observerBody_isExactlyTheWiring() throws {
        let source = try Self.source("Yala/App/Views/Panel/PanelDataObservers.swift")
        let start = try #require(source.range(of: "struct PanelActivationObserver: ViewModifier {"))
        let body = Self.normalized(source[start.lowerBound...])

        #expect(
            body.hasPrefix(
                "struct PanelActivationObserver: ViewModifier { let viewModel: PanelViewModel "
                    + "func body(content: Content) -> some View { content "
                    + ".onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) "
                    + "{ _ in viewModel.applicationDidBecomeActive() } } }"))
    }

    @Test("El Panel monta el observador")
    func panelShell_mountsTheObserver() throws {
        let shell = try Self.source("Yala/App/Views/Panel/PanelShell.swift")
        #expect(shell.contains(".modifier(PanelActivationObserver(viewModel: viewModel))"))
    }
}
