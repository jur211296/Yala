//
//  SecondarySessionStore.swift
//  Yala
//
//  Descriptor persistido de la SESIÓN SECUNDARIA (M1 multi-cuenta en device — diseño
//  MODO-NUBE-M1-DISENO-MULTICUENTA, decisiones owner 2026-07-13): tras el sign-out del dueño,
//  otra cuenta nube monta un store personal SECUNDARIO por archivo (`YalaModel-Secondary`,
//  mirror CloudKit JAMÁS adjunto). 1 slot: la presencia del descriptor ES la sesión activa;
//  el `userID` (sub de Supabase) dice QUIÉN lo ocupa, y lo compara `SecondarySlotOccupancyLogic`
//  en la ENTRADA (`WelcomeCloudSignInView.confirmSecondaryEntry`) — hasta el chip M1 esa validación
//  la prometía este comentario y no la hacía nadie: `activeUserID` no tenía un solo consumidor de
//  producción, así que una cuenta B entraba al slot de A con los archivos de A vivos en disco.
//  **El mount NO pregunta quién** (solo `isActive()`), y eso es deliberado — ver el párrafo del flag.
//  Persistente hasta el sign-out explícito (decisión 5 — supersede la regla efímera de
//  ENLACE-OPCIONAL §5.2: cold-launch REANUDA la sesión activa, no la descarta).
//
//  Molde `StorageModePersistence`: `nonisolated enum` + UserDefaults inyectable (regla del
//  repo: jamás `.standard` directo en tests). El flag de feature (`CloudSyncFlags.
//  secondarySessionEnabled`) gatea SOLO la ENTRADA — el mount y el wipe honran el descriptor
//  incondicionalmente para no brickear una sesión ya activa si el flag se apagara.
//

import Foundation

nonisolated enum SecondarySessionStore {

    /// Descriptor de la sesión (el `sub` de la cuenta nube). Presencia = sesión activa (1 slot).
    static let userIDKey = "cloudSync.secondarySession.userID"

    /// Flag "wipe secundario ARMADO" — lo escribe el sign-out secundario DESPUÉS de subir todo el
    /// outbox; el BOOT siguiente (pre-mount) borra los ARCHIVOS secundarios y limpia el descriptor.
    /// Paralelo a `signOutWipeArmed` pero JAMÁS toca los archivos ni las keys del dueño.
    static let wipeArmedKey = "cloudSync.secondaryWipeArmed"

    /// Marker "purga de entrada ejecutada" — la purga de superficies App Group + cancelación de
    /// notifs del dueño corre UNA vez al primer boot de la sesión (kill a mitad ⇒ re-purga completa,
    /// todo idempotente; el marker se escribe AL FINAL).
    static let entryPurgeDoneKey = "cloudSync.secondarySession.entryPurgeDone"

    // MARK: - Descriptor (1 slot)

    static func activate(userID: String, _ defaults: UserDefaults = .standard) {
        guard !userID.isEmpty else { return }
        defaults.set(userID, forKey: userIDKey)
    }

    static func activeUserID(_ defaults: UserDefaults = .standard) -> String? {
        guard let raw = defaults.string(forKey: userIDKey), !raw.isEmpty else { return nil }
        return raw
    }

    /// ¿Hay sesión secundaria activa? Es la señal que consumen el mount (`personalConfiguration`/
    /// `syncMetaConfiguration`), el modo efectivo (`CloudSyncFlags.storageMode`) y los gates.
    static func isActive(_ defaults: UserDefaults = .standard) -> Bool {
        if let override = activeTestOverride { return override }
        return activeUserID(defaults) != nil
    }

    static func clear(_ defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: userIDKey)
    }

    // MARK: - Wipe de salida (armado por el sign-out secundario, consumido por el boot)

    static func armWipe(_ defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: wipeArmedKey)
    }

    static func isWipeArmed(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: wipeArmedKey)
    }

    /// Desarmar — SIEMPRE el ÚLTIMO paso del boot-cleanup (re-entrada idempotente tras kill).
    static func clearWipeArm(_ defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: wipeArmedKey)
    }

    // MARK: - Purga de entrada (one-shot idempotente)

    static func markEntryPurgeDone(_ defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: entryPurgeDoneKey)
    }

    static func isEntryPurgeDone(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: entryPurgeDoneKey)
    }

    static func clearEntryPurgeMark(_ defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: entryPurgeDoneKey)
    }

    // MARK: - Test seam

    /// Solo tests: fuerza el resultado de `isActive()` sin tocar `.standard` (los consumidores de
    /// producción — getter de modo efectivo, gates — leen `.standard`; el override permite ejercitar
    /// esas ramas con `defer { _testSetActiveOverride(nil) }` bajo `@Suite(.serialized)`).
    static func _testSetActiveOverride(_ value: Bool?) {
        activeTestOverride = value
    }

    nonisolated(unsafe) private static var activeTestOverride: Bool?
}
