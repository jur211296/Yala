//
//  ConnectedBrowsersPresence.swift
//  Yala
//
//  ¿Tiene la cuenta sesiones de Yala web abiertas? Lo que apuntas en la web entra en la cola común de borradores del
//  gateway (la del correo del banco), y el iPhone solo pregunta a esa cola si alguien la usa: hasta el lote 1, solo con
//  el correo del banco preparado (`BankEmailSetupStore`). Esto añade «o hay sesiones web» sin que cada teléfono en la
//  nube pregunte a la cola en cada vuelta a primer plano (decisión P5 del lote 1).
//
//  Cómo: al volver a primer plano se pregunta a la web, como mucho cada 2 minutos, y se guarda la respuesta. Si la web
//  no contesta, vale la última respuesta guardada. La pantalla «Navegadores conectados» también la guarda.
//
//  Y no basta «hay sesiones ahora»: quien apunta en un equipo compartido y sale deja el borrador en la cola sin ninguna
//  sesión abierta. Por eso cuenta «hubo sesiones web en los últimos 30 días», lo mismo que la cola guarda un borrador.
//

import Foundation

nonisolated enum ConnectedBrowsersPresence {
    static let hasSessionsKey = "connectedBrowsers.hasWebSessions"
    static let lastCheckKey = "connectedBrowsers.lastCheckAt"
    static let lastSeenWithSessionsKey = "connectedBrowsers.lastSeenWithSessionsAt"
    /// Lo que la cola del gateway guarda un borrador (`DRAFT_TTL_MS`): después de eso ya no hay nada que recoger.
    static let recentWindow: TimeInterval = 30 * 86_400
    /// Cada cuánto, como mucho, se pregunta a la web.
    static let checkInterval: TimeInterval = 120

    /// ¿Toca preguntar? Pura, para los tests.
    static func isDue(lastCheck: Date?, now: Date) -> Bool {
        guard let lastCheck else { return true }
        // Un reloj que retrocede no deja la pregunta parada hasta que vuelva a alcanzar la marca.
        return now.timeIntervalSince(lastCheck) >= checkInterval || now < lastCheck
    }

    /// ¿Se pregunta siquiera? Solo con web para este build, datos en la nube y sesión. Pura, para los tests.
    static func shouldCheck(webAvailable: Bool, storageIsCloud: Bool, hasSession: Bool) -> Bool {
        webAvailable && storageIsCloud && hasSession
    }

    /// ¿Hubo sesiones web en los últimos 30 días (o las hay ahora)? Es lo que decide si el iPhone pregunta a la cola.
    static func cachedHasSessions(now: Date = .now, defaults: UserDefaults = .standard) -> Bool {
        if defaults.bool(forKey: hasSessionsKey) { return true }
        guard let seen = defaults.object(forKey: lastSeenWithSessionsKey) as? Date else { return false }
        return now.timeIntervalSince(seen) < recentWindow
    }

    static func lastCheck(defaults: UserDefaults = .standard) -> Date? {
        defaults.object(forKey: lastCheckKey) as? Date
    }

    static func record(sessionCount: Int, at date: Date, defaults: UserDefaults = .standard) {
        defaults.set(sessionCount > 0, forKey: hasSessionsKey)
        defaults.set(date, forKey: lastCheckKey)
        if sessionCount > 0 { defaults.set(date, forKey: lastSeenWithSessionsKey) }
    }

    /// Pregunta a la web si toca y devuelve si hay sesiones web (la respuesta guardada si no tocaba o no contestó).
    @MainActor
    static func refreshIfDue(
        client: ConnectedBrowsersClient,
        webAvailable: Bool? = nil,
        storageIsCloud: Bool? = nil,
        hasSession: Bool? = nil,
        now: Date = .now,
        defaults: UserDefaults = .standard
    ) async -> Bool {
        // `nil`: lo de verdad. Se lee aquí dentro (en el actor principal), no en el valor por defecto del parámetro.
        guard shouldCheck(
            webAvailable: webAvailable ?? ConnectedBrowsersConfig.isAvailable,
            storageIsCloud: storageIsCloud ?? (CloudSyncFlags.storageMode == .cloud),
            hasSession: hasSession ?? CloudAuthService.shared.hasSession
        ) else { return false }
        guard isDue(lastCheck: lastCheck(defaults: defaults), now: now) else { return cachedHasSessions(now: now, defaults: defaults) }
        do {
            let sessions = try await client.sessions()
            record(sessionCount: sessions.count, at: now, defaults: defaults)
        } catch {
            #if DEBUG
            print("ConnectedBrowsersPresence: Error: \(error)")
            #endif
        }
        return cachedHasSessions(now: now, defaults: defaults)
    }
}
