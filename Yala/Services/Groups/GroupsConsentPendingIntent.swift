//
//  GroupsConsentPendingIntent.swift
//  Yala
//
//  El intent DURABLE de «este usuario aceptó el consent de Grupos y su cuenta todavía no lo sabe» (C1).
//
//  ## Por qué es un intent y no un reintento en memoria
//
//  Regla de la casa (`.claude/rules/swiftdata-cloudkit.md`): lo que se difiere se recupera solo si es un
//  EVENTO con cola detrás; si es una INTENCIÓN, no la re-entrega nadie. Aquí no hay cola de ningún tipo —
//  el consent lo produce un tap, una sola vez— así que perderlo es definitivo: el usuario aceptó de verdad
//  y su registro legal no existiría en ninguna parte. Molde vivo: `GroupsPendingBridgeIntent`
//  (`GroupsIdentityPurgeIntent`, que la regla todavía cita como canónico, fue borrado el 2026-08-06).
//
//  ## Las cuatro diferencias deliberadas respecto del molde
//
//  | | Intent del bridge | Éste |
//  |---|---|---|
//  | Almacén | `UserDefaults` | igual — la escritura no puede depender de un `save()` de SwiftData |
//  | TTL | ninguno | **ninguno**: caducar aquí es perder la prueba legal |
//  | Tope de intentos | 3 por ID | **ninguno**. Allí el tope evita trabajo Y un `save()` en cada arranque para siempre; aquí es un request. A cambio, `GroupsConsentRetryBackoffLogic` + canario |
//  | Identidad | `Channel` por ID | **el `sub` DENTRO del payload**, obligatorio |
//
//  ## El `sub` en el payload es el invariante que no se puede romper (R9)
//
//  Un intent que sobreviva a un relevo de sesión —el usuario cierra, entra otro en el mismo device— NO
//  puede registrarse contra la cuenta equivocada: sería atribuirle a B el consentimiento de A, que es
//  peor que no registrar nada. Por eso el retome, cuando el `sub` vivo no casa, **ni intenta ni descarta**:
//  se queda esperando a su dueño. Y por eso ninguna frontera de sesión lo borra (ver
//  `GroupsConsentState.clear`).
//
//  ## Arm-then-attempt-then-disarm, con el desarme SOLO en 2xx
//
//  Se ARMA antes de intentar nada —`GroupsConsentRegistrar.register` lo escribe antes de tocar la red y
//  antes del `onAccept()` que cierra el sheet— y se DESARMA únicamente con una respuesta 200 del RPC. Así
//  quedan cubiertos por el mismo mecanismo: el fallo de red, el 403 del kill-switch, un `throw` a mitad,
//  y que el proceso muera entre el tap y el request.
//

import Foundation

/// Payload persistido. UNA sola entrada y no una lista: el device tiene una sesión a la vez y una
/// aceptación posterior de la MISMA cuenta con una versión más alta simplemente pisa la anterior (el
/// servidor las conserva las dos — la PK es `(user_id, text_version)`).
private struct StoredPendingConsent: Codable {
    var userID: String
    var textVersion: Int
    var acceptedAt: Date
    var path: String?
    /// DIAGNÓSTICO (la edad del intent, que es lo que emite el canario), jamás un criterio de caducidad.
    var armedAt: Date
    var attempts: Int
    var lastAttemptAt: Date?
}

/// La intención viva, ya decodificada.
struct PendingGroupsConsent: Equatable, Sendable {
    var userID: String
    var textVersion: Int
    var acceptedAt: Date
    var path: String?
    var armedAt: Date
    var attempts: Int
    var lastAttemptAt: Date?
}

@MainActor
enum GroupsConsentPendingIntent {

    static let userDefaultsKey = "yala.groups.pendingConsentRegistration"

    /// `nonisolated(unsafe)` para inyección en tests (molde `GroupsPendingBridgeIntent.defaults`): el host
    /// de los unit tests es la propia app, así que su `.standard` es el del simulador y un intent escrito
    /// ahí sobreviviría a la corrida.
    nonisolated(unsafe) static var defaults: UserDefaults = .standard

    // MARK: - API

    /// Arma la intención. Se llama ANTES de intentar nada.
    ///
    /// Re-armar con la MISMA versión conserva `armedAt`, los intentos y la fecha de aceptación ORIGINAL:
    /// el dato accionable es desde cuándo se arrastra, y re-fechar convertiría un intent viejo en uno
    /// nuevo cada vez que alguien vuelve a pasar por la pantalla. Re-armar con una versión SUPERIOR (o con
    /// otra cuenta) empieza de cero: es otra aceptación, y su hora es la suya.
    static func arm(
        userID: String, textVersion: Int, acceptedAt: Date, path: String?, at now: Date = .now
    ) {
        if let existing = load(), existing.userID == userID, existing.textVersion >= textVersion {
            return
        }
        persist(StoredPendingConsent(
            userID: userID, textVersion: textVersion, acceptedAt: acceptedAt, path: path,
            armedAt: now, attempts: 0, lastAttemptAt: nil))
    }

    static var pending: PendingGroupsConsent? {
        guard let s = load() else { return nil }
        return PendingGroupsConsent(
            userID: s.userID, textVersion: s.textVersion, acceptedAt: s.acceptedAt, path: s.path,
            armedAt: s.armedAt, attempts: s.attempts, lastAttemptAt: s.lastAttemptAt)
    }

    static var isArmed: Bool { load() != nil }

    /// Desarme. SOLO con 2xx confirmado, y solo si lo confirmado es lo que está armado: una respuesta que
    /// llega tarde, de una versión anterior o de otra cuenta, no puede desarmar la intención vigente.
    static func confirm(userID: String, textVersion: Int) {
        guard let s = load(), s.userID == userID, s.textVersion <= textVersion else { return }
        defaults.removeObject(forKey: userDefaultsKey)
    }

    /// Un intento que no llegó a 2xx: sube la racha y sella la hora, que es lo que lee la escalera. NO
    /// descarta nunca — no hay tope a propósito (ver el docblock del fichero).
    static func noteFailedAttempt(at now: Date = .now) {
        guard var s = load() else { return }
        s.attempts += 1
        s.lastAttemptAt = now
        persist(s)
    }

    /// Wipe total. Hoy **sin ningún call-site, y es deliberado**: ninguna frontera de sesión lo borra,
    /// porque el `sub` sellado ya impide que se registre contra la cuenta equivocada y borrarlo destruiría
    /// la prueba de una aceptación real. Se conserva porque es la primitiva correcta si aparece una
    /// frontera que sí la necesite (p. ej. el borrado de la propia cuenta, donde ya no hay a quién
    /// registrar); quien la llame debe justificar por qué su caso no es el de arriba.
    static func clearAll() {
        defaults.removeObject(forKey: userDefaultsKey)
    }

    // MARK: - Persistencia

    private static func load() -> StoredPendingConsent? {
        guard let data = defaults.data(forKey: userDefaultsKey) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(StoredPendingConsent.self, from: data)
        } catch {
            // Payload ilegible (formato viejo, escritura truncada): se descarta. Conservarlo dejaría el
            // retome ciego para siempre sin forma de repararse.
            #if DEBUG
            print("GroupsConsentPendingIntent: Error decoding: \(error)")
            #endif
            defaults.removeObject(forKey: userDefaultsKey)
            return nil
        }
    }

    private static func persist(_ stored: StoredPendingConsent) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        do {
            defaults.set(try encoder.encode(stored), forKey: userDefaultsKey)
        } catch {
            #if DEBUG
            print("GroupsConsentPendingIntent: Error encoding: \(error)")
            #endif
        }
    }
}
