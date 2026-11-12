//
//  GroupsEntryStartupWaitTests.swift
//  YalaTests
//
//  Card apsn · «Vengo por un grupo» dejaba ~10 s de pantalla negra en un iPhone recién instalado. Dos piezas:
//
//  1. **La espera se acorta**: el histórico de tasas (12 peticiones con 0,5 s de pausa entre cada una) ya no va en el
//     camino que el arranque espera, y el bloqueo `bootstrapPending` deja de retener la cadena de Grupos ese rato. El
//     simulador no lo puede medir —sin App Attest las 12 fallan al instante—, así que lo fija un scan del cuerpo.
//  2. **Lo que queda no es negro**: `ShellWaitingLogic` pone la pantalla de carga de la app en el sitio del fondo vacío.
//     El XCUITest `WelcomeChooserUITests.testGroupsOrganizer_withTheStartupStillRunning_showsTheLoadingScreenNotBlack`
//     recorre la pantalla con un arranque lento de verdad.
//

import Foundation
import Testing
@testable import Yala

struct ShellWaitingLogicTests {

    /// (cadena del organizador, un paso en pantalla, arranque asentado) → pantalla de carga.
    @Test(arguments: [
        (true, false, true, true),    // entre dos pasos de la cadena
        (true, true, true, false),    // con una hoja de la cadena arriba: el fondo de siempre detrás
        (false, false, true, false),  // nada que esperar
        (false, false, false, true),  // el arranque retiene lo que venga
        (true, true, false, true),
    ])
    func brandedWaiting_fillsTheGapBetweenSteps_andThePendingStartup(
        organizer: Bool, presentationUp: Bool, settled: Bool, expected: Bool
    ) {
        #expect(ShellWaitingLogic.showsBrandedWaiting(
            groupsOrganizerFlowActive: organizer, chainPresentationUp: presentationUp,
            isBootstrapSettled: settled) == expected)
    }
}

struct HistoricalRatesOffTheStartupPathTests {

    private static func source(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.hasPrefix("//") && !$0.isEmpty }
            .joined(separator: "\n")
    }

    private static func loadExchangeRatesBody() throws -> String {
        let src = try source("Yala/App/AppBootstrapper.swift")
        let start = try #require(src.range(of: "private func loadExchangeRates(context: ModelContext) async {"))
        let rest = src[start.upperBound...]
        let end = try #require(rest.range(of: "\nprivate var historicalRatesTask"))
        return String(rest[..<end.lowerBound])
    }

    /// La tasa de hoy se espera; el histórico y lo que depende de él van en una tarea que el arranque no espera, en orden.
    @Test func onlyTodaysRateIsAwaited_theHistoryRunsInItsOwnTask_inOrder() throws {
        let body = try Self.loadExchangeRatesBody()
        let marks = [
            "await ExchangeRateService.shared.updateTodayIfNeeded(context: context)",
            "guard historicalRatesTask == nil else { return }",
            "historicalRatesTask = Task { @MainActor in",
            "await ExchangeRateService.shared.preloadHistoricalIfNeeded(context: context)",
            "guard !Task.isCancelled else { return }",
            "TransactionUpdateService.repairLegacyOneToOneRatesIfNeeded(context: context)",
            "await TransactionUpdateService.updateProvisionalTransactions(context: context)",
        ]
        var positions: [String.Index] = []
        for mark in marks {
            let range = try #require(body.range(of: mark), "Falta «\(mark)» en loadExchangeRates")
            positions.append(range.lowerBound)
        }
        #expect(positions == positions.sorted(), "El orden de loadExchangeRates cambió")
        // El histórico va DENTRO de la tarea: antes de abrirla solo está la tasa de hoy.
        let beforeTask = try #require(body.range(of: "historicalRatesTask = Task {"))
        #expect(!body[..<beforeTask.lowerBound].contains("preloadHistoricalIfNeeded"))
    }

    /// El swap suelta los contextos: la tarea del histórico retiene el del contenedor que se va.
    @Test func theSwapCancelsTheHistoryTask() throws {
        let src = try Self.source("Yala/App/AppBootstrapper.swift")
        let start = try #require(src.range(of: "func releaseModelContextsForSwap() {"))
        let rest = src[start.upperBound...]
        let end = try #require(rest.range(of: "func rebootstrapAfterSwap("))
        let body = rest[..<end.lowerBound]
        #expect(body.contains("historicalRatesTask?.cancel()\nhistoricalRatesTask = nil"))
    }

    /// Debajo de las presentaciones, sin shell, la pantalla de carga con marca cuando toca; el fondo vacío solo si no.
    @Test func contentView_paintsTheLoadingScreenInsteadOfTheEmptyBackground() throws {
        let src = try Self.source("Yala/App/ContentView.swift")
        let start = try #require(src.range(of: "} else if ShellWaitingLogic.showsBrandedWaiting("))
        let rest = src[start.upperBound...]
        let end = try #require(rest.range(of: "} else {\ntheme.background"))
        let branch = rest[..<end.lowerBound]
        #expect(branch.contains("groupsOrganizerFlowActive: groupsOrganizerFlowActive"))
        #expect(branch.contains("chainPresentationUp: showGroupsEducational || showGroupsSignIn || showGroupsConsent"))
        #expect(branch.contains("|| showGroupsAccountIsCompleteBlock || showGroupsOrganizerName"))
        #expect(branch.contains("isBootstrapSettled: SessionState.shared.isBootstrapSettled"))
        #expect(branch.contains("SplashScreenView()"))
        #expect(branch.contains(".accessibilityIdentifier(\"shell_waiting_brand\")"))
    }
}
