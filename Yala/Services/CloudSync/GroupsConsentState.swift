//
//  GroupsConsentState.swift
//  Yala
//
//  Estado del consentimiento informado de GRUPOS (G4, contrato C5). Molde §2.8 EXACTO de
//  `cloudConsent*` (`CloudConsentView.registerConsent`): dos `PrefSyncKey` de la familia
//  `intPresence` (`groupsConsentAcceptedAt` epoch + `groupsConsentTextVersion`).
//
//  DARKNESS: las keys SOLO se escriben vía `register()`, que la pantalla de consent (A2) invoca al
//  aceptar — un flujo que solo se presenta con `groupsBackendEnabled` ON. Con el flag OFF nunca se
//  setean → nil → skip en el merge/outbox de prefs, cero tráfico nuevo (§C5).
//
//  A1 provee este helper (estado + registro) para desbloquear el flujo del handler; A2 añade la VISTA
//  (`GroupsConsentView`) y su telemetría (`cloudConsentAccepted(path:"groups")`).
//

import Foundation

@MainActor
enum GroupsConsentState {

    /// Versión del texto de consent (para trazabilidad GDPR — como `CloudConsentText.version`). A2 la
    /// bumpéa si el copy cambia materialmente.
    static let textVersion = 1

    /// `UserDefaults` de lectura. `nonisolated(unsafe)` para inyección en tests (molde `PendingJoinStore`).
    /// Las ESCRITURAS van por `PreferenceSyncService` (dual-write local + iKV/outbox según storageMode).
    nonisolated(unsafe) static var defaults: UserDefaults = .standard

    /// `true` si el usuario ya aceptó el consent de grupos (epoch > 0).
    static var isAccepted: Bool {
        defaults.integer(forKey: PrefSyncKey.groupsConsentAcceptedAt.rawValue) > 0
    }

    /// Registra el consentimiento (persistencia GDPR §C5). En `.icloud` va a iKV y el drenaje del
    /// cutover lo lleva al backend; en `.cloud` va directo al outbox de prefs. La telemetría del consent
    /// la emite la VISTA de A2 (`cloudConsentAccepted(path:"groups")`, [R7]) — este helper solo persiste.
    static func register(now: Date = .now) {
        PreferenceSyncService.shared.set(
            int: Int(now.timeIntervalSince1970),
            forKey: PrefSyncKey.groupsConsentAcceptedAt.rawValue)
        PreferenceSyncService.shared.set(
            int: textVersion,
            forKey: PrefSyncKey.groupsConsentTextVersion.rawValue)
    }

    /// Limpia el consent de grupos. Usa `PreferenceSyncService.remove` para las 2 keys → cubre las 3
    /// ramas de storageMode (CR-2: en `.icloud` DEBE limpiar el iKV o `applyRemoteValues()` del próximo
    /// boot resucitaría el consent). Idempotente.
    ///
    /// EL MODO EN QUE SE INVOCA IMPORTA, y por eso los callers son los que son. Ninguno alcanza el
    /// backend, pero por dos vías distintas:
    /// - `.icloud` (`behavior == .icloudKeyValue`) → local + iKV, cero backend. Es el caso de los cierres
    ///   solo-grupos (`finalizeGroupsOnlyClose`, `closeLocalAfterAccountDeletionGroupsOnly`,
    ///   `exitYalaOnThisDevice`) y del boot-cleanup del wipe personal
    ///   (`SwiftDataConfiguration.performSignOutWipeIfArmed`, que la invoca DESPUÉS de escribir `.icloud`
    ///   justamente para caer en esta rama).
    /// - Frontera M1 (`SecondarySessionBoundaryPurge`) → con el descriptor secundario activo el behavior
    ///   es `.localOnly`: SOLO UserDefaults, ni iKV ni outbox. Es lo correcto ahí y no una carencia — el
    ///   iKV presente es el del DUEÑO (decisión 7 del diseño M1), y limpiarlo le retiraría a él un consent
    ///   que sigue siendo suyo.
    /// - `.cloud` (`behavior == .cloudOutbox`) → encola `.int(0)`, que para la familia `intPresence`
    ///   equivale a "no aceptado" y **borraría por LWW el registro GDPR de la cuenta en el backend**,
    ///   propagándolo a sus otros devices. Un sign-out es "hasta luego", no una retirada de
    ///   consentimiento: NO llamar a este helper desde un camino que corra con el modo `.cloud` vivo
    ///   (pinneado por `SignOutNotificationWiringTests.inSessionConsentClears_neverOnCloudModePaths`).
    static func clear() {
        PreferenceSyncService.shared.remove(forKey: PrefSyncKey.groupsConsentAcceptedAt.rawValue)
        PreferenceSyncService.shared.remove(forKey: PrefSyncKey.groupsConsentTextVersion.rawValue)
    }
}
