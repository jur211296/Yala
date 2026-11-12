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
//  - **Sin el texto N1 aceptado**, también el camino de siempre (decisión 1A de Jürgen, 2026-10-18): la pregunta de
//    N1 sale una vez en el chat (`ChatAssistantViewModel`), pero quien decide es esta lógica, así que una pregunta que
//    no pasa por el chat (Siri) tampoco sale ampliada sin él.
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

/// La respuesta de la persona al texto N1 (`aiConsent.cloudExploreMessage`). Ausente = todavía no se le preguntó.
/// `rawValue` es formato persistido en `UserDefaults` (`AppPreferences.Keys.aiCloudExploreConsent`): no se renombra.
nonisolated enum YalaIACloudExploreConsent: String, Equatable, Sendable {
    case accepted
    case declined
}

/// Dónde vive la respuesta a N1. Del teléfono y sin sincronizar, como `aiChatConsentAccepted`: un consentimiento no viaja
/// por el canal de preferencias, y el reset de preferencias de cada cambio de persona lo retira
/// (`DataWipeService.removeUserPreferenceKeys`).
nonisolated enum YalaIACloudExploreConsentStore {
    static func read(_ defaults: UserDefaults = .standard) -> YalaIACloudExploreConsent? {
        defaults.string(forKey: AppPreferences.Keys.aiCloudExploreConsent).flatMap(YalaIACloudExploreConsent.init(rawValue:))
    }

    static func write(_ consent: YalaIACloudExploreConsent?, _ defaults: UserDefaults = .standard) {
        if let consent {
            defaults.set(consent.rawValue, forKey: AppPreferences.Keys.aiCloudExploreConsent)
        } else {
            defaults.removeObject(forKey: AppPreferences.Keys.aiCloudExploreConsent)
        }
    }
}

/// La decisión, pura.
nonisolated enum YalaIAChatRouteLogic {
    /// ¿Existe el camino ampliado para este teléfono? Solo en la nube y con el flag encendido. Es la condición de que
    /// la pregunta de N1 tenga sentido, y la fila de Ajustes › Privacidad de la IA sale con ella.
    static func cloudExploreAvailable(storageMode: StorageMode, flagOn: Bool) -> Bool {
        storageMode == .cloud && flagOn
    }

    /// ¿Hace falta pedir el token? Con el camino disponible y N1 aceptado: en privado no se toca la sesión, y sin N1
    /// tampoco.
    static func wantsCloudExplore(storageMode: StorageMode, flagOn: Bool, consent: YalaIACloudExploreConsent?) -> Bool {
        cloudExploreAvailable(storageMode: storageMode, flagOn: flagOn) && consent == .accepted
    }

    /// ¿Se le enseña N1 antes de enviar? Solo si el camino existe y la persona aún no contestó: aceptado o rechazado,
    /// no vuelve a salir (se cambia desde Ajustes).
    /// `available` es `cloudExploreAvailable` ya resuelto (`YalaIAChatRouting.cloudExploreAvailableNow`).
    static func needsCloudExploreConsentPrompt(available: Bool, consent: YalaIACloudExploreConsent?) -> Bool {
        available && consent == nil
    }

    static func decide(
        storageMode: StorageMode,
        flagOn: Bool,
        consent: YalaIACloudExploreConsent?,
        userToken: String?,
        timeZone: String
    ) -> YalaIAChatRoute {
        guard wantsCloudExplore(storageMode: storageMode, flagOn: flagOn, consent: consent) else { return .standard }
        guard let token = userToken?.trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty else { return .standard }
        return .cloudExplore(userToken: token, timeZone: timeZone)
    }
}

/// El cableado: lee el modo, el flag y, solo si hace falta, el token de la sesión.
@MainActor
enum YalaIAChatRouting {
    /// El flag, N1 y el token se piden perezosos: en privado no se lee ninguno, y sin N1 aceptado no se toca la sesión.
    static func resolve(
        storageMode: StorageMode = CloudSyncFlags.storageMode,
        flagOn: () -> Bool = { CloudRemoteFlags.aiCloudExploreEnabled },
        consent: () -> YalaIACloudExploreConsent? = { YalaIACloudExploreConsentStore.read() },
        timeZone: String = TimeZone.current.identifier,
        userToken: () async -> String? = { await CloudAuthService.shared.accessToken() }
    ) async -> YalaIAChatRoute {
        guard storageMode == .cloud else { return .standard }
        let on = flagOn()
        guard on else { return .standard }
        let answer = consent()
        guard YalaIAChatRouteLogic.wantsCloudExplore(storageMode: storageMode, flagOn: on, consent: answer) else {
            return .standard
        }
        return YalaIAChatRouteLogic.decide(
            storageMode: storageMode, flagOn: on, consent: answer, userToken: await userToken(), timeZone: timeZone
        )
    }

    /// ¿Existe el camino ampliado ahora? Lo leen el chat (antes de enviar) y Ajustes › Privacidad de la IA. En XCUITest,
    /// `-uitest-ai-cloud-explore` finge la ENTRADA (nube y flag), no la decisión: qué pasa lo decide la lógica de arriba.
    static func cloudExploreAvailableNow() -> Bool {
        #if DEBUG
        if UITestHooks.fakeAICloudExplore { return true }
        #endif
        let mode = CloudSyncFlags.storageMode
        guard mode == .cloud else { return false }
        return YalaIAChatRouteLogic.cloudExploreAvailable(storageMode: mode, flagOn: CloudRemoteFlags.aiCloudExploreEnabled)
    }
}
