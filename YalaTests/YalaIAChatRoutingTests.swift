//
//  YalaIAChatRoutingTests.swift
//  YalaTests
//
//  Por qué camino sale una pregunta de Yala IA según el modo (`docs/ai-cloud-vs-private-2026-10.md`):
//
//  1. En privado, siempre `chat.answer`, y sin leer ni el flag ni la sesión.
//  2. En la nube, `chat.explore` solo con el flag encendido, el texto N1 aceptado y un token; si falta algo, el camino
//     de siempre. Sin N1 aceptado ni se pide el token.
//  3. Las cabeceras del camino ampliado son las que lee el gateway.
//  4. El servicio del chat usa la ruta para la tarea, las cabeceras y el tiempo de espera.
//

import Foundation
import Testing
@testable import Yala

@MainActor
struct YalaIAChatRoutingTests {

    // MARK: - La decisión

    @Test("tabla: solo nube + flag + N1 aceptado + token da el camino ampliado", arguments: [
        (StorageMode.icloud, false, YalaIACloudExploreConsent?.some(.accepted), "jwt" as String?, false),
        (StorageMode.icloud, true, .accepted, "jwt", false),
        (StorageMode.cloud, false, .accepted, "jwt", false),
        (StorageMode.cloud, true, .accepted, nil, false),
        (StorageMode.cloud, true, .accepted, "   ", false),
        (StorageMode.cloud, true, nil, "jwt", false),
        (StorageMode.cloud, true, .declined, "jwt", false),
        (StorageMode.cloud, true, .accepted, "jwt", true),
    ])
    func decisionTable(mode: StorageMode, flagOn: Bool, consent: YalaIACloudExploreConsent?, token: String?, explores: Bool) {
        let route = YalaIAChatRouteLogic.decide(
            storageMode: mode, flagOn: flagOn, consent: consent, userToken: token, timeZone: "America/Lima"
        )
        #expect((route != .standard) == explores)
        if explores { #expect(route == .cloudExplore(userToken: "jwt", timeZone: "America/Lima")) }
    }

    @Test("cada modo de StorageMode está en la tabla (un modo nuevo no se queda fuera en silencio)")
    func everyStorageModeIsDecided() {
        #expect(StorageMode.allCases == [.icloud, .cloud])
    }

    // MARK: - El cableado: perezoso en privado

    @Test("privado: camino de siempre sin leer el flag, N1 ni el token")
    func privateModeReadsNothing() async {
        var flagReads = 0
        var consentReads = 0
        var tokenReads = 0
        let route = await YalaIAChatRouting.resolve(
            storageMode: .icloud,
            flagOn: { flagReads += 1; return true },
            consent: { consentReads += 1; return .accepted },
            timeZone: "UTC",
            userToken: { tokenReads += 1; return "jwt" }
        )
        #expect(route == .standard)
        #expect(flagReads == 0)
        #expect(consentReads == 0)
        #expect(tokenReads == 0)
    }

    @Test("nube con flag y N1 sin aceptar (sin preguntar o rechazado): camino de siempre y el token no se pide",
          arguments: [YalaIACloudExploreConsent?.none, .some(.declined)])
    func cloudWithoutN1DoesNotTouchTheSession(consent: YalaIACloudExploreConsent?) async {
        var tokenReads = 0
        let route = await YalaIAChatRouting.resolve(
            storageMode: .cloud, flagOn: { true }, consent: { consent }, timeZone: "UTC",
            userToken: { tokenReads += 1; return "jwt" }
        )
        #expect(route == .standard)
        #expect(tokenReads == 0)
    }

    @Test("nube con el flag apagado: camino de siempre y el token no se pide")
    func cloudFlagOffDoesNotTouchTheSession() async {
        var tokenReads = 0
        let route = await YalaIAChatRouting.resolve(storageMode: .cloud, flagOn: { false }, consent: { .accepted }, timeZone: "UTC", userToken: { tokenReads += 1; return "jwt" })
        #expect(route == .standard)
        #expect(tokenReads == 0)
    }

    @Test("nube con flag, N1 aceptado y sesión: camino ampliado con el token y la zona del teléfono")
    func cloudFlagOnWithSessionExplores() async {
        let route = await YalaIAChatRouting.resolve(storageMode: .cloud, flagOn: { true }, consent: { .accepted }, timeZone: "Europe/Madrid", userToken: { "jwt-de-supabase" })
        #expect(route == .cloudExplore(userToken: "jwt-de-supabase", timeZone: "Europe/Madrid"))
    }

    @Test("nube con flag y sin token (sesión caducada o sin red): camino de siempre, nunca un error")
    func cloudFlagOnWithoutTokenFallsBack() async {
        let route = await YalaIAChatRouting.resolve(storageMode: .cloud, flagOn: { true }, consent: { .accepted }, timeZone: "UTC", userToken: { nil })
        #expect(route == .standard)
    }

    @Test("bajo test el flag real está apagado (falla cerrado; ningún test enciende la nube por accidente)")
    func realFlagIsOffUnderTests() {
        CloudRemoteFlags._testResetOverrides()
        #expect(CloudRemoteFlags.aiCloudExploreEnabled == false)
    }

    // MARK: - Lo que cambia la ruta

    @Test("la ruta de siempre: chat.answer, sin cabeceras extra, 20 s")
    func standardRouteIsTodaysRequest() {
        #expect(YalaIAChatRoute.standard.task == .chatAnswer)
        #expect(YalaIAChatRoute.standard.extraHeaders.isEmpty)
        #expect(YalaIAChatRoute.standard.timeout == 20)
    }

    @Test("la ruta ampliada: chat.explore, JWT y zona en sus cabeceras, 30 s")
    func exploreRoute() {
        let route = YalaIAChatRoute.cloudExplore(userToken: "jwt", timeZone: "America/Lima")
        #expect(route.task == .chatExplore)
        #expect(route.task.category == .chat)
        #expect(route.extraHeaders == ["X-Yala-User-Token": "jwt", "X-Yala-Time-Zone": "America/Lima"])
        #expect(route.timeout == 30)
    }

    // MARK: - Contrato con el gateway

    @Test("las cabeceras son las que lee el gateway")
    func headersMatchTheGateway() throws {
        let ts = try String(contentsOf: repoURL("gateway/src/ai/explore/index.ts"), encoding: .utf8)
        #expect(ts.contains("export const USER_TOKEN_HEADER = \"\(YalaIAExploreHeader.userToken)\";"))
        #expect(ts.contains("export const TIME_ZONE_HEADER = \"\(YalaIAExploreHeader.timeZone)\";"))
    }

    @Test("el plazo de la app (30 s) deja sitio al plazo blando del gateway (12 s) y a la última llamada")
    func appTimeoutLeavesRoomForTheGatewayDeadline() throws {
        let ts = try String(contentsOf: repoURL("gateway/src/ai/explore/loop.ts"), encoding: .utf8)
        let match = try #require(ts.range(of: #"softDeadlineMs: (\d[\d_]*)"#, options: .regularExpression))
        let digits = ts[match].split(separator: " ").last.map { $0.replacingOccurrences(of: "_", with: "") } ?? ""
        let softMs = try #require(Double(digits))
        #expect(YalaIAChatRoute.cloudExplore(userToken: "x", timeZone: "UTC").timeout * 1000 >= softMs + 10_000)
    }

    // MARK: - El servicio del chat

    /// El chat no se puede lanzar sin montar media app (contexto, clasificador, red): se fija su cuerpo, como hace
    /// `ProxyTaskHeaderTests.everyCallSiteNamesItsTask` con el resto de servicios.
    @Test("processQuestion decide la ruta y la usa para la tarea, las cabeceras y la espera")
    func chatServiceUsesTheRoute() throws {
        let source = try String(contentsOf: repoURL("Yala/Services/ChatAssistantService.swift"), encoding: .utf8)
        let start = try #require(source.range(of: "func processQuestion("))
        let rest = source[start.upperBound...]
        let end = try #require(rest.range(of: "\n    // MARK: - Ask flow"))
        let body = String(rest[..<end.lowerBound])
        #expect(body.contains("let route = await YalaIAChatRouting.resolve()"))
        #expect(body.contains("case .standard:\n                client = try await ProxyClientFactory.makeOpenAI(task: .chatAnswer)\n"))
        #expect(body.contains("task: .chatExplore,\n                    extraHeaders: route.extraHeaders,\n                    timeout: route.timeout"))
        #expect(body.contains("timeout: route.timeout\n            )\n            return ChatAssistantResponse(text: text, attachments: nil, intent: .ask)"))
        // La espera del servicio sale del argumento, no de una constante de 20 s.
        #expect(source.contains("try await Task.sleep(for: .seconds(timeout))"))
        #expect(!source.contains("Self.timeoutSeconds"))
    }

    private func repoURL(_ relative: String) -> URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent(relative)
    }
}
