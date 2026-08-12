//
//  StorageRowGateLogic.swift
//  Yala
//
//  Pure-logic de visibilidad de la fila "Almacenamiento" de Profile (DIFERIDOS #34).
//
//  Decisión owner (2026-07-17): el kill-switch remoto `cloudModeEnabled=OFF` corta solo la
//  ENTRADA — un usuario "engaged" (ya `.cloud`, o con migración/reversa en vuelo o fallida)
//  CONSERVA la fila SIEMPRE: es su panel de gestión, resume y REVERSA (el escape ante incidente).
//  OFF + no-engaged ⇒ oculta. Sigue siendo el estado de producción HOY, pero por otra razón que antes:
//  el backend ya está configurado (D-R1 paso 1) y lo que apaga la fila es el flag remoto, porque el
//  gateway sirve `CLOUD_MODE_ROLLOUT_PERCENT = "0"`.
//

import Foundation

nonisolated enum StorageRowGateLogic {

    /// **CHIP M3 · la única llave del panel DEBUG en sesión secundaria, y solo en builds DEV.**
    ///
    /// El `#if` vive AQUÍ y en ningún otro sitio para que la puerta sea una expresión medible: en un
    /// binario de producción esta constante es `false` literal ⇒ la tabla de abajo se comporta byte-idéntica
    /// a antes de M3, y un source-scan puede afirmar que ProfileView pasa ESTO y no un `true` a mano.
    ///
    /// Lo que desbloquea: `StorageSettingsView` ya degrada su contenido en secundaria (pinta el aviso en vez
    /// de la migración del dueño) pero su `cloudDebugPanel` cuelga FUERA de ese `if`, así que llegar a la
    /// fila es llegar al panel — y el panel es la única salida por producto de una sesión FAKE (`guest-debug`
    /// no tiene sesión de backend con la que drenar un sign-out secundario). Sin esto, M1-4 dejaba el QA de
    /// sim soft-lockeado: descriptor puesto, panel inalcanzable y solo lldb para salir.
    static let devPanelOverrideAvailable: Bool = {
        #if DEV_BUILD
        return true
        #else
        return false
        #endif
    }()

    /// - Parameters:
    ///   - isConfigured: backend configurado (`CloudBackendConfig.isConfigured`).
    ///   - isSecondaryActive: sesión secundaria M1 (la fila describe la migración del DUEÑO).
    ///   - remoteEnabled: flag remoto `CloudRemoteFlags.cloudModeEnabled`.
    ///   - isEngaged: el usuario ya está dentro (modo persistido `.cloud` o
    ///     `CloudMigrationController.uiState` más allá de `.idle` — journal transicional,
    ///     relaunch pendiente, cloudActive, waitingForLeader o terminal de fallo).
    ///   - devPanelOverride: M3 · `devPanelOverrideAvailable` en el call-site de producción. **Solo abre la
    ///     celda de secundaria** y no toca ninguna otra: en un build DEV con sesión secundaria la fila es
    ///     visible SIN mirar `isConfigured`, `remoteEnabled` ni `isEngaged`, porque los tres describen la
    ///     migración del DUEÑO y aquí la fila no es su panel de gestión — es la puerta de servicio al panel
    ///     DEBUG. Default `false` ⇒ la tabla 2⁴ de `StorageRowGateLogicTests` sigue midiendo lo mismo.
    static func isVisible(
        isConfigured: Bool,
        isSecondaryActive: Bool,
        remoteEnabled: Bool,
        isEngaged: Bool,
        devPanelOverride: Bool = false
    ) -> Bool {
        // El override se resuelve ANTES que `isConfigured` a propósito: el panel sirve para manipular el
        // descriptor y armar el wipe secundario, cosas que no dependen de que el backend esté configurado.
        if isSecondaryActive { return devPanelOverride }
        guard isConfigured else { return false }
        return remoteEnabled || isEngaged
    }
}
