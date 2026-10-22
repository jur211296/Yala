//
//  CloudConsentRegistrar.swift
//  Yala
//
//  La ESCRITURA del registro GDPR del consent de Nube (`cloudConsentAcceptedAt` +
//  `cloudConsentTextVersion`, familia `intPresence`), separada de la PANTALLA que lo pide.
//
//  Existe por el chip M0 de la ola M (§6.3 de [[MODO-NUBE-SPEC-M1-REVIVAL]]), y la razón es una sola:
//  **el destino de estas dos keys no es una propiedad del consent, es una propiedad del INSTANTE en que
//  se escriben.** `PreferenceSyncService` resuelve su `behavior` en CADA llamada —`.icloudKeyValue` (iKV
//  del Apple ID de este device) · `.cloudOutbox` (backend de la sesión viva) · `.localOnly` (secundaria
//  M1)— así que quien conoce la RUTA tiene que ser quien dispare la escritura. En la re-entrada del
//  Welcome la ruta la decide el guard cross-cuenta DESPUÉS del sign-in: escribir al aceptar dejaba el
//  epoch de la invitada en el iKV del DUEÑO, y el paso 5-bis del cutover lo habría subido un día como
//  registro GDPR de él (`MigrationWorkExecutor.adoptBackendAccount`).
//
//  **Append-only** (regla §prefs de `.claude/rules/swiftdata-cloudkit.md`): aquí solo se ESCRIBE. Ningún
//  `remove` de consent vive en este tipo y no debe añadirse — para `intPresence` un `0` ES «no aceptado»
//  y el wire de prefs no tiene tombstone, así que un borrado desde un camino con `.cloud` vivo retiraría
//  el consent de una cuenta que sigue viva.
//
//  Molde: `GroupsConsentState.register` (el mismo par de keys, para Grupos). Lo que NO viaja aquí es la
//  TELEMETRÍA: la emite la pantalla al aceptar (`MetricsService.cloudConsentAccepted(path:)`), porque
//  «el usuario aceptó» ocurrió ahí aunque la persistencia se difiera.
//

import Foundation

@MainActor
enum CloudConsentRegistrar {

    /// El escritor de PRODUCCIÓN. Expuesto para que un test pueda restaurarlo en su `defer` tras
    /// instalar el suyo — sin esto, un `defer` tendría que re-teclear el closure y una divergencia
    /// dejaría a las suites siguientes escribiendo en el sitio equivocado.
    static let liveWriter: (Int, String) -> Void = { value, key in
        PreferenceSyncService.shared.set(int: value, forKey: key)
    }

    /// Escritor de las dos keys. Producción: `PreferenceSyncService.set(int:forKey:)` — y es AHÍ donde se
    /// resuelve la rama en el instante de la llamada, que es justo lo que M0 mueve de sitio. Seam de test
    /// (molde `PreferenceSyncService.secondarySessionActiveProvider`): el pin del chip es CONTAR
    /// escrituras, y `PreferenceSyncService` es un singleton con `local` hardcodeado a `.standard`.
    static var writeInt: (Int, String) -> Void = liveWriter

    /// Registra la aceptación: epoch T0 + versión del contrato aceptado. `now` inyectable porque el epoch
    /// es la hora de la ACEPTACIÓN y el cutover lo RE-EMITE tal cual — recalcularlo en otro paso falsearía
    /// la traza con la hora de ese paso.
    static func register(now: Date = .now) {
        writeInt(Int(now.timeIntervalSince1970), PrefSyncKey.cloudConsentAcceptedAt.rawValue)
        writeInt(CloudConsentText.version, PrefSyncKey.cloudConsentTextVersion.rawValue)
    }
}
