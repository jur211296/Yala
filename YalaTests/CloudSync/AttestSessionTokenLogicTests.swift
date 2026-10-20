//
//  AttestSessionTokenLogicTests.swift
//  YalaTests / CloudSync
//
//  Ticket `cloud-activation-stalls-without-uploading-until-relaunch`: el techo de la espera a un refresh de App Attest en
//  vuelo, el olvido del token que el gateway rechaza, y el cableado de los dos en `AppAttestClient` y en los ocho sitios
//  que leen el 401 `yala_attest_required`.
//

import Foundation
import Testing

@testable import Yala

@Suite("App Attest · techo del refresh y token rechazado")
struct AttestSessionTokenLogicTests {

    // MARK: - Techo

    @Test("Recién arrancado, se espera el techo entero; a los 89 s queda 1 s; a los 90 s se abandona")
    func remainingWait_countsDownToTheCeiling() {
        #expect(AttestSessionTokenLogic.remainingRefreshWait(elapsed: .zero) == .seconds(90))
        #expect(AttestSessionTokenLogic.remainingRefreshWait(elapsed: .seconds(89)) == .seconds(1))
        #expect(AttestSessionTokenLogic.remainingRefreshWait(elapsed: .seconds(90)) == .zero)
        #expect(AttestSessionTokenLogic.remainingRefreshWait(elapsed: .seconds(3600)) == .zero)
    }

    @Test("Control: un registro lento pero sano (60 s) sigue esperando a la MISMA tarea, no arranca otra")
    func remainingWait_aSlowHealthyRefreshIsNotAbandoned() {
        #expect(AttestSessionTokenLogic.remainingRefreshWait(elapsed: .seconds(60)) == .seconds(30))
    }

    @Test("Un transcurrido negativo (no debería pasar con reloj monotónico) espera el techo entero")
    func remainingWait_negativeElapsed_waitsTheWholeCeiling() {
        #expect(AttestSessionTokenLogic.remainingRefreshWait(elapsed: .seconds(-5)) == .seconds(90))
    }

    // MARK: - Token rechazado

    @Test("Se olvida el guardado solo si es el que viajó")
    func discards_onlyTheTokenThatTravelled() {
        #expect(AttestSessionTokenLogic.discardsCachedToken(cached: "tokA", rejected: "tokA"))
        // Control: uno distinto ya es más nuevo y tirarlo gastaría una assertion sin motivo.
        #expect(!AttestSessionTokenLogic.discardsCachedToken(cached: "tokB", rejected: "tokA"))
        #expect(!AttestSessionTokenLogic.discardsCachedToken(cached: nil, rejected: "tokA"))
        #expect(!AttestSessionTokenLogic.discardsCachedToken(cached: "tokA", rejected: nil))
        #expect(!AttestSessionTokenLogic.discardsCachedToken(cached: "", rejected: ""))
    }

    @Test("El token que viajó se lee de la cabecera, sin el prefijo")
    func sentToken_readsTheHeader() {
        var request = URLRequest(url: URL(string: "https://example.invalid/sync/push")!)
        #expect(AttestSessionProvider.sentToken(in: request) == nil)
        request.setValue("Bearer tokA", forHTTPHeaderField: "X-Yala-Attest-Session")
        #expect(AttestSessionProvider.sentToken(in: request) == "tokA")
        request.setValue("tokB", forHTTPHeaderField: "X-Yala-Attest-Session")
        #expect(AttestSessionProvider.sentToken(in: request) == "tokB")
    }
}

@Suite("App Attest · cableado del techo y del token rechazado (source-scan)")
struct AttestSessionTokenWiringTests {

    private static func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    private static func lines(_ text: String) -> [String] {
        text.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("//") }
    }

    /// Los ocho sitios que leen el 401 `yala_attest_required`. Un sitio nuevo que lo lea sin olvidar el token reabre el
    /// ticket `attest-session-token-rejected-by-the-gateway-stays-cached`; el conteo hace que no se escape.
    @Test func everyAttestRequired401_reportsTheSentToken() throws {
        // Barre `Yala/` entero, no una lista escrita a mano: un cliente nuevo con la rama tiene que entrar en la cuenta.
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        let files = try #require(FileManager.default.enumerator(at: root.appendingPathComponent("Yala"),
                                                                 includingPropertiesForKeys: nil))
            .compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
            .map { String($0.path.dropFirst(root.path.count + 1)) }
        var sites = 0
        for path in files {
            let code = Self.lines(try Self.source(path))
            for (i, line) in code.enumerated() where line == "case 401 where GatewayErrorEnvelope.isAttestRequired(data):" {
                sites += 1
                #expect(i + 1 < code.count && code[i + 1] == "AttestSessionProvider.reportRejected(sentIn: request)",
                        "\(path): la rama del 401 de attest no olvida el token que viajó")
            }
        }
        #expect(sites == 8, "Se esperaban 8 ramas `yala_attest_required` y hay \(sites): ¿una nueva o una renombrada?")
    }

    /// El cuerpo de la espera con techo, entero: el `TaskGroup` (que esperaría al hijo colgado) o un `refreshTask.value` a
    /// pelo devolverían la espera infinita sin que ningún test de comportamiento lo viera (no hay App Attest en el host).
    @Test func appAttestClient_waitsWithTheCeiling_andAbandonsTheStalledRefresh() throws {
        let src = try Self.source("Yala/App/Services/AppAttestClient.swift")
        let code = Self.lines(src).joined(separator: "\n")
        #expect(!code.contains("return try await refreshTask.value"), "la espera al single-flight vuelve a no tener techo")
        #expect(!code.contains("let token = try await task.value"), "la espera del dueño vuelve a no tener techo")
        #expect(code.contains("return try await awaitRefresh(refreshTask, startedAt: refreshStartedAt)"))
        #expect(code.contains("let token = try await awaitRefresh(task, startedAt: startedAt)"))
        #expect(code.contains("AttestSessionTokenLogic.remainingRefreshWait(elapsed: ContinuousClock.now - startedAt)"))
        #expect(code.contains("if refreshTask == task {\nCloudSyncBreadcrumb.attestRefreshAbandoned(stage: refreshStage)"))
        #expect(code.contains("MetricsService.canary(.attestRefreshAbandoned, detail: refreshStage)\nclearRefresh(task)"))
        #expect(!code.contains("withThrowingTaskGroup") && !code.contains("withTaskGroup"),
                "un TaskGroup espera a todos sus hijos al cerrar, también al que espera a la tarea colgada")
        #expect(code.contains("guard AttestSessionTokenLogic.discardsCachedToken(cached: cached?.token, rejected: rejected) else { return }\ncached = nil"))
    }
}
