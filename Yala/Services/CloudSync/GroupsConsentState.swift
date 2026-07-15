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
}
