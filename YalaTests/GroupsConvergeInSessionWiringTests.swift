//
//  GroupsConvergeInSessionWiringTests.swift
//  YalaTests
//
//  Ticket `wipe-data-group-rows-return-only-on-the-next-cold-launch`: tras «Vaciar datos», «Empezar de cero» al volver de
//  «Solo grupos» y el borrado por la señal de otro dispositivo que deja a la persona dentro, los gastos de grupo vuelven a
//  Registros y al Panel en la MISMA sesión. La convergencia ya estaba probada contra el bridge real
//  (`GroupsBridgeRestoreConvergenceTests`); lo que faltaba era quien la llamara con la app montada, y eso es cableado.
//

import Foundation
import Testing

@testable import Yala

@Suite("Grupos · convergencia en la sesión tras vaciar (cableado, source-scan)")
struct GroupsConvergeInSessionWiringTests {

    private static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()  // YalaTests/
        .deletingLastPathComponent()  // raíz del repo

    private static func source(_ relativePath: String) throws -> String {
        try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// El cuerpo de la función que empieza en `marker`, hasta la llave que lo cierra.
    private static func body(of marker: String, in source: String) throws -> String {
        let start = try #require(source.range(of: marker), "no se encontró `\(marker)`")
        var parens = 0
        var index = start.lowerBound
        while index < source.endIndex {
            let ch = source[index]
            if ch == "(" { parens += 1 }
            if ch == ")" { parens -= 1 }
            if ch == "{" && parens == 0 { break }
            index = source.index(after: index)
        }
        var depth = 0
        var end = index
        while end < source.endIndex {
            let ch = source[end]
            if ch == "{" { depth += 1 }
            if ch == "}" {
                depth -= 1
                if depth == 0 { break }
            }
            end = source.index(after: end)
        }
        return String(source[start.lowerBound...end])
    }

    private static let call = "await AppBootstrapper.shared.convergeGroupsBridgeInSession(context: "

    @Test("la función de la sesión pasa por los mismos gates que el arranque y avisa a las pantallas al converger")
    func inSessionConvergence_usesTheBootGates_andBumpsDataVersion() throws {
        let src = try Self.source("Yala/App/AppBootstrapper.swift")
        let fn = try Self.body(of: "func convergeGroupsBridgeInSession(", in: src)
        let steps = [
            "GroupsRemoteWipeDivision.resolveIfArrived()",
            "guard GroupsBridgeRestoreConvergenceStore.isPending() else { return }",
            "guard await awaitPersonalStoreReady() else {",
            "guard GroupsBridgeRestoreConvergence.convergeIfPending(context: context) else { return }",
            "SessionState.shared.incrementDataVersion()",
        ]
        var cursor = fn.startIndex
        for step in steps {
            let found = try #require(fn.range(of: step, range: cursor..<fn.endIndex),
                                     "falta, o va fuera de orden: `\(step)`")
            cursor = found.upperBound
        }
    }

    @Test("«Vaciar datos» converge en la sesión solo cuando la persona se queda en el Panel, y después del borrado")
    func wipeData_convergesInSession_onlyOnThePanelLanding() throws {
        let src = try Self.source("Yala/App/Views/Settings/UserDataResetView.swift")
        let fn = try Self.body(of: "private func handleWipeAllData(", in: src)
        // Partido a propósito: `SharedStateIsolationTests` trata como «ejecuta el wipe» todo fichero con la llamada literal.
        let wipe = try #require(fn.range(of: "try DataWipeService.wipePersonalDataKeepingGroups" + "("))
        let gate = try #require(fn.range(of: "if case .panel = landing {"))
        let call = try #require(fn.range(of: Self.call + "modelContext)"))
        #expect(wipe.upperBound < gate.lowerBound && gate.upperBound < call.lowerBound)
        let catchRange = try #require(fn.range(of: "} catch {"))
        #expect(call.upperBound < catchRange.lowerBound, "tras un borrado que falla no se converge")
        #expect(fn.components(separatedBy: Self.call).count - 1 == 1)
    }

    @Test("«Empezar de cero» al volver de «Solo grupos» converge después de volver a Yala completo")
    func startFresh_convergesInSession_afterReturningToFull() throws {
        let src = try Self.source("Yala/App/Services/UsageModeService.swift")
        let fn = try Self.body(of: "static func startFresh(", in: src)
        let back = try #require(fn.range(of: "await returnToFull(context: context)"))
        let call = try #require(fn.range(of: "Task { @MainActor in " + Self.call + "context) }"))
        #expect(back.upperBound < call.lowerBound)
    }

    @Test("el receptor de la señal converge solo en la rama que deja a la persona dentro")
    func remoteWipeReceiver_convergesInSession_onlyWhenItKeepsSetup() throws {
        let src = try Self.source("Yala/App/ContentView.swift")
        let fn = try Self.body(of: "private func performLocalWipeForRemoteSync(", in: src)
        let keep = try #require(fn.range(of: "if skipOnboarding {\n                hasCompletedOnboarding = true"))
        let call = try #require(fn.range(of: Self.call + "modelContext)"))
        let elseBranch = try #require(fn.range(of: "} else {", range: keep.upperBound..<fn.endIndex))
        #expect(keep.upperBound < call.lowerBound && call.upperBound < elseBranch.lowerBound,
                "con onboarding por delante no hay sesión que repintar: la convergencia espera al arranque")
        #expect(fn.components(separatedBy: Self.call).count - 1 == 1)
    }
}
