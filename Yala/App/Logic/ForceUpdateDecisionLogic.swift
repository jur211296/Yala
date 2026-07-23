//
//  ForceUpdateDecisionLogic.swift
//  Yala
//
//  Decisión PURA del forzado de actualización (min-version). El umbral llega en el snapshot de
//  remote-config (`GET /config`, campo `forceUpdate.minSupportedBuild`) y se compara contra el
//  número de build local (`CFBundleVersion`). Separada de `RemoteFlagDecisionLogic` (que es
//  percent-bucket de rollout) — aquí la decisión es determinista, no un bucket.
//
//  DARK: en prod el fetch de `/config` no corre (`CloudBackendConfig.isConfigured == false`), así
//  que el snapshot nunca trae `minSupportedBuild` → `isUpdateRequired` = false (fail-open: usuario
//  jamás bloqueado sin una señal explícita del server). Se activará al encender el fetch (D9).
//

import Foundation

nonisolated enum ForceUpdateDecisionLogic {

    /// `true` sii el build local está por DEBAJO del mínimo soportado declarado por el server.
    /// FAIL-OPEN en todo lo demás: `minSupportedBuild` nil/≤0 (desactivado / sin config) o build
    /// local no determinable → false. Nunca se bloquea sin una señal positiva y válida.
    static func isUpdateRequired(currentBuild: Int?, minSupportedBuild: Int?) -> Bool {
        guard let minSupportedBuild, minSupportedBuild > 0, let currentBuild else { return false }
        return currentBuild < minSupportedBuild
    }
}
