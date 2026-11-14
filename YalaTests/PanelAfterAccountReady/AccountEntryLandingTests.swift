//
//  AccountEntryLandingTests.swift
//  YalaTests
//
//  Lote del recorrido de la bienvenida (iPhone 14, 13-nov; ticket `panel-and-groups-show-data-on-entry`):
//  - card x5tm: quien entra por «Entra aquí» de Grupos aterriza en Grupos;
//  - card zkyg: quien ya tiene grupos no ve la intro de Grupos ni vuelve a aceptar el consentimiento;
//  - card 3f57: al sacar «Tu saldo se mueve solo», el Panel sube hasta lo que señala;
//  - card c8i9: el aviso del motor de la nube pasa por `RemoteChangesFanOut`.
//  Lo que vive en vistas se fija por source-scan del cableado.
//

import Foundation
import Testing

@testable import Yala

@MainActor
@Suite("Bienvenida · al entrar, cada puerta aterriza donde toca", .serialized)
struct AccountEntryLandingTests {

    // MARK: - Puerta de Grupos (x5tm)

    @Test("«Entra aquí» de Grupos aterriza en Grupos una sola vez")
    func groupsDoor_armedOnce_consumedOnce() {
        WelcomeGroupsDoorLanding.disarm()
        defer { WelcomeGroupsDoorLanding.disarm() }
        #expect(!WelcomeGroupsDoorLanding.consume(), "Sin entrar por Grupos, «Empezar» va al Panel como siempre")
        WelcomeGroupsDoorLanding.arm()
        #expect(WelcomeGroupsDoorLanding.consume())
        #expect(!WelcomeGroupsDoorLanding.consume(), "Consumida: la entrada siguiente vuelve al Panel")
    }

    @Test("Otra entrada desde la vitrina retira la puerta de Grupos")
    func groupsDoor_disarmedByAnotherEntry() {
        WelcomeGroupsDoorLanding.arm()
        WelcomeGroupsDoorLanding.disarm()
        #expect(!WelcomeGroupsDoorLanding.consume())
    }

    // MARK: - Intro de Grupos (zkyg)

    @Test("Con grupos no hay intro; sin grupos, la de siempre")
    func groupsIntro_notShownWithGroups() {
        #expect(!GroupsOnboardingLogic.shouldShow(hasSeenEducational: false, hasPendingGroupDeeplink: false,
                                                  hasGroups: true))
        #expect(GroupsOnboardingLogic.shouldShow(hasSeenEducational: false, hasPendingGroupDeeplink: false,
                                                 hasGroups: false))
    }

    @Test("Con sesión y canal, sin grupos aún: se decide tras el primer tirón")
    func groupsIntro_waitsForFirstPullOnlyWhenGroupsCanArrive() {
        #expect(GroupsOnboardingLogic.decidesAfterFirstPull(hasGroups: false, channelCanBringGroups: true))
        #expect(!GroupsOnboardingLogic.decidesAfterFirstPull(hasGroups: true, channelCanBringGroups: true))
        #expect(!GroupsOnboardingLogic.decidesAfterFirstPull(hasGroups: false, channelCanBringGroups: false))
    }

    // MARK: - Cableado

    private static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()   // …/PanelAfterAccountReady
        .deletingLastPathComponent()   // …/YalaTests
        .deletingLastPathComponent()   // raíz

    /// Texto sin comentarios y con los espacios colapsados a uno.
    private static func code(_ path: String) throws -> String {
        var raw = try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
        raw = raw.replacingOccurrences(of: #"/\*[\s\S]*?\*/"#, with: " ", options: .regularExpression)
        raw = raw.replacingOccurrences(of: #"(?m)//.*$"#, with: " ", options: .regularExpression)
        return raw.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }

    @Test("El aviso del motor aplica en el acto con la app delante")
    func fanOutObserver_goesThroughRemoteChangesFanOut() throws {
        let source = try Self.code("Yala/App/AppBootstrapper.swift")
        #expect(source.contains(
            "forName: .cloudSyncAppliedRemoteChanges, object: nil, queue: .main ) { _ in Task { @MainActor in "
            + "RemoteChangesFanOut.receive(isApplicationActive: UIApplication.shared.applicationState == .active) } }"))
    }

    @Test("«Empezar» consume la puerta de Grupos y elige su pestaña; «Entra aquí» la apunta y la vitrina la retira")
    func groupsDoor_wiring() throws {
        let content = try Self.code("Yala/App/ContentView.swift")
        // Barrido del 14-nov (c8i9): entre elegir Grupos y cerrar el cover, «Empezar» sube `dataVersion`.
        #expect(content.contains("if WelcomeGroupsDoorLanding.consume() { navigation.selectMainTab(.groups) } "
                                 + "SessionState.shared.incrementDataVersion() showWelcomeCloudSignIn = false"))
        let flow = try Self.code("Yala/App/Views/Onboarding/WelcomeFlowContainer.swift")
        #expect(flow.contains("onSignIn: { WelcomeGroupsDoorLanding.arm() handleExistingBranch() }"))
        #expect(flow.contains("from door: WelcomeShowcaseLogic.Door) { WelcomeGroupsDoorLanding.disarm() switch (access, door)"))
    }

    @Test("Grupos decide la intro con los grupos y vuelve a decidir tras el primer tirón, con la pestaña a la vista")
    func groupsIntro_wiring() throws {
        let source = try Self.code("Yala/App/Views/Groups/GroupsContainerView.swift")
        #expect(source.contains("let hasGroups = !viewModel.activeGroups.isEmpty || !viewModel.archivedGroups.isEmpty"))
        #expect(source.contains("|| navigation.pendingExpenseAfterNewGroup, hasGroups: hasGroups )"))
        #expect(source.contains("groupsOnboardingAwaitsPull = !afterFirstPull && GroupsOnboardingLogic.decidesAfterFirstPull("))
        #expect(source.contains("if groupsOnboardingAwaitsPull { return }"))
        // Solo la intro que se aplazó se vuelve a decidir: una aplazada con la X no vuelve al terminar el tirón.
        #expect(source.contains("await viewModel.refreshFromCloud(force: false) refreshAttestTerminalNotice() "
                                + "if groupsOnboardingAwaitsPull, isRootPageShown { evaluateGroupsOnboarding(afterFirstPull: true) }"))
    }

    @Test("Al sacar «Tu saldo se mueve solo», el Panel sube hasta la píldora que señala")
    func todayFXGuide_scrollsToItsAnchor() throws {
        let panel = try Self.code("Yala/App/Views/Panel/PanelView.swift")
        #expect(panel.contains(".onChange(of: showTodayFXCoachMark) { _, showing in if showing { scrollToTodayFXHint(scrollProxy) } }"))
        #expect(panel.contains("proxy.scrollTo(ProTourSteps.todayFXAnchor, anchor: .center)"))
        // La guía y la píldora usan la misma ancla.
        #expect(ProTourSteps.todayFXSteps.map(\.id) == [ProTourSteps.todayFXAnchor])
        let chart = try Self.code("Yala/App/Views/Panel/TrendChartView.swift")
        #expect(chart.contains(".coachMarkAnchor(\"\(ProTourSteps.todayFXAnchor)\")"))
    }
}
