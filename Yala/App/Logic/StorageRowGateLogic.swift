//
//  StorageRowGateLogic.swift
//  Yala
//
//  Pure-logic de visibilidad de la fila "Almacenamiento" de Profile (DIFERIDOS #34).
//
//  Decisión owner (2026-07-17): el kill-switch remoto `cloudModeEnabled=OFF` corta solo la
//  ENTRADA — un usuario "engaged" (ya `.cloud`, o con migración/reversa en vuelo o fallida)
//  CONSERVA la fila SIEMPRE: es su panel de gestión, resume y REVERSA (el escape ante incidente).
//  OFF + no-engaged ⇒ oculta (= prod de hoy con backend placeholder).
//

import Foundation

nonisolated enum StorageRowGateLogic {

    /// - Parameters:
    ///   - isConfigured: backend configurado (`CloudBackendConfig.isConfigured`).
    ///   - isSecondaryActive: sesión secundaria M1 (la fila describe la migración del DUEÑO).
    ///   - remoteEnabled: flag remoto `CloudRemoteFlags.cloudModeEnabled`.
    ///   - isEngaged: el usuario ya está dentro (modo persistido `.cloud` o
    ///     `CloudMigrationController.uiState` más allá de `.idle` — journal transicional,
    ///     relaunch pendiente, cloudActive, waitingForLeader o terminal de fallo).
    static func isVisible(
        isConfigured: Bool,
        isSecondaryActive: Bool,
        remoteEnabled: Bool,
        isEngaged: Bool
    ) -> Bool {
        guard isConfigured, !isSecondaryActive else { return false }
        return remoteEnabled || isEngaged
    }
}
