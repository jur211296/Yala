//
//  YalaIAChatRouting.swift
//  Yala
//
//  Por qué camino sale una pregunta de Yala IA, según dónde viven los datos (`docs/ai-cloud-vs-private-2026-10.md`).
//
//  - **Privado** (`StorageMode.icloud`): el camino de siempre, `chat.answer`. Ni se mira el flag ni se pide nada más:
//    la petición sale byte a byte como antes de este fichero.
//  - **Nube** con el flag `aiCloudExploreRolloutPercent` encendido y una sesión con token: `chat.explore`. La misma
//    pregunta y el mismo resumen, y el gateway le da al modelo herramientas que leen las tablas del usuario con su JWT.
//    Si falta el token, el camino de siempre: nunca un error nuevo.
//

import Foundation

/// Las cabeceras del camino ampliado. Contrato con `gateway/src/ai/explore/index.ts` (`USER_TOKEN_HEADER`,
/// `TIME_ZONE_HEADER`); lo fija `YalaIAChatRoutingTests`.
nonisolated enum YalaIAExploreHeader {
    /// JWT de Supabase del usuario. `Authorization` ya lo ocupa el token de sesión de App Attest.
    static let userToken = "X-Yala-User-Token"
    /// Zona horaria IANA del teléfono: decide qué día es hoy y dónde empieza cada mes en las herramientas.
    static let timeZone = "X-Yala-Time-Zone"
}

nonisolated enum YalaIAChatRoute: Equatable {
    case standard
    case cloudExplore(userToken: String, timeZone: String)

    var task: ProxyTask {
        switch self {
        case .standard: .chatAnswer
        case .cloudExplore: .chatExplore
        }
    }

    /// Cabeceras además de las de la tarea. Vacío en el camino de siempre.
    var extraHeaders: [String: String] {
        switch self {
        case .standard:
            return [:]
        case let .cloudExplore(userToken, timeZone):
            return [YalaIAExploreHeader.userToken: userToken, YalaIAExploreHeader.timeZone: timeZone]
        }
    }

    /// Lo que espera la app la respuesta. El camino ampliado hace varias llamadas al modelo dentro de una petición, y
    /// el gateway deja de pedir herramientas a los 12 s (`EXPLORE_LIMITS.softDeadlineMs`).
    var timeout: TimeInterval {
        switch self {
        case .standard: ProxyClientFactory.defaultTimeout
        case .cloudExplore: 30
        }
    }
}

/// La decisión, pura.
nonisolated enum YalaIAChatRouteLogic {
    /// ¿Hace falta pedir el token? Solo en la nube y con el flag encendido: en privado no se toca la sesión.
    static func wantsCloudExplore(storageMode: StorageMode, flagOn: Bool) -> Bool {
        storageMode == .cloud && flagOn
    }

    static func decide(storageMode: StorageMode, flagOn: Bool, userToken: String?, timeZone: String) -> YalaIAChatRoute {
        guard wantsCloudExplore(storageMode: storageMode, flagOn: flagOn) else { return .standard }
        guard let token = userToken?.trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty else { return .standard }
        return .cloudExplore(userToken: token, timeZone: timeZone)
    }
}

/// El cableado: lee el modo, el flag y, solo si hace falta, el token de la sesión.
@MainActor
enum YalaIAChatRouting {
    /// El flag y el token se piden perezosos: en privado no se lee ninguno de los dos.
    static func resolve(
        storageMode: StorageMode = CloudSyncFlags.storageMode,
        flagOn: () -> Bool = { CloudRemoteFlags.aiCloudExploreEnabled },
        timeZone: String = TimeZone.current.identifier,
        userToken: () async -> String? = { await CloudAuthService.shared.accessToken() }
    ) async -> YalaIAChatRoute {
        guard storageMode == .cloud else { return .standard }
        let on = flagOn()
        guard YalaIAChatRouteLogic.wantsCloudExplore(storageMode: storageMode, flagOn: on) else { return .standard }
        return YalaIAChatRouteLogic.decide(storageMode: storageMode, flagOn: on, userToken: await userToken(), timeZone: timeZone)
    }
}
