//
//  GroupsTabStartsChannelWiringTests.swift
//  YalaTests / CloudSync
//
//  Al volver a tu cuenta de Grupos por «Ya tengo una cuenta», tus grupos aparecen sin cerrar la app (QA guiado del
//  2026-10-19, C · D5 paso 1). La sesión nace con la app abierta y el canal de Grupos solo lo arrancaban el arranque
//  en frío, la vuelta a primer plano y el cierre de `GroupsSignInView`; ninguno pasa en ese camino. Ahora lo arranca
//  también la pestaña Grupos al aparecer. El comportamiento del canal lo fijan los `tabStart_*` de
//  `GroupsSyncClientTests`; aquí, que la pestaña lo llame y antes de pedir su pull.
//

import Foundation
import Testing

@testable import Yala

@Suite("Grupos · la pestaña arranca el canal (cableado)")
struct GroupsTabStartsChannelWiringTests {

    @Test func theTab_startsTheChannel_onlyOutsideTestsAndExits() {
        #expect(GroupsLoopRestartLogic.tabStartsChannel(isUITesting: false, exitInFlight: false))
        // Control: con un cierre o un desasociar en curso, NO arrancar —el comportamiento de antes— es lo correcto.
        #expect(!GroupsLoopRestartLogic.tabStartsChannel(isUITesting: false, exitInFlight: true))
        #expect(!GroupsLoopRestartLogic.tabStartsChannel(isUITesting: true, exitInFlight: false))
    }

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/CloudSync/
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    /// Líneas de código recortadas, sin comentarios.
    private static func codeLines(_ path: String) throws -> [String] {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("//") }
    }

    @Test func theTab_startsTheChannel_beforeAskingForItsPull() throws {
        let lines = try Self.codeLines("Yala/App/Views/Groups/GroupsContainerView.swift")
        let start = try #require(lines.firstIndex(
            of: "GroupsSyncClient.shared.startIfEligible(context: modelContext, trigger: \"groups-tab\")"))
        // Detrás de su decisión, con el cierre en curso leído del coordinador (no un `!= nil` cualquiera).
        try #require(start >= 4 && start + 1 < lines.count)
        #expect(Array(lines[(start - 4)..<start]) == [
            "if GroupsLoopRestartLogic.tabStartsChannel(",
            "isUITesting: UITestHooks.isActive,",
            "exitInFlight: CloudSessionSignOut.shared.phase != .idle || CloudSessionSignOut.shared.isDetaching",
            ") {",
        ])
        #expect(lines[start + 1] == "}")
        let pull = try #require(lines.firstIndex(of: "await viewModel.refreshFromCloud(force: false)"))
        #expect(start < pull)
        // Dentro del `onAppear` de la pestaña, el mismo que pide el pull.
        let appear = try #require(lines[..<start].lastIndex(of: ".onAppear {"))
        #expect(lines[appear...start].contains("viewModel.setContext(modelContext)"))
        #expect(lines.filter { $0.contains("trigger: \"groups-tab\"") }.count == 1)
    }
}
