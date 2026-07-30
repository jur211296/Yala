//
//  ForceUpdateDecisionLogic.swift
//  Yala
//
//  Decisión PURA del forzado de actualización (min-version). El umbral llega en el snapshot de
//  remote-config (`GET /config`, campo `forceUpdate.minSupportedBuild`) y se compara contra el
//  número de build local (`CFBundleVersion`). Separada de `RemoteFlagDecisionLogic` (que es
//  percent-bucket de rollout) — aquí la decisión es determinista, no un bucket.
//
//  VIVO en producción desde D-R1 paso 1: el fetch de `/config` YA corre y el snapshot sí trae
//  `minSupportedBuild`. Hoy el server declara `0` (`MIN_SUPPORTED_BUILD = "0"` en
//  `[env.production.vars]`, vigilado por `gateway/test/wrangler.forceupdate.test.ts`) ⇒
//  `isUpdateRequired` es `false` para todo el mundo. Lo que protege al usuario ya NO es la ausencia de
//  fetch —esa red desapareció—, sino ese valor desplegado y el fail-open de abajo.
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
