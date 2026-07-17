//
//  PrefsCutoverDrain.swift
//  Yala
//
//  Lógica PURA del drenaje único iKV → outbox de prefs en el cutover (§g.4 refinamiento S8,
//  DIFERIDOS #30 — I10-wiring w8). El escenario que cierra: mientras el device LÍDER cruzaba el
//  cutover, otro device AÚN `.icloud` (el iPad de S8) pudo escribir una preferencia a iCloud KV; sin
//  este drenaje, ese valor jamás viaja a `user_preferences` (la rama `.cloud` no lee iKV) → se pierde
//  una preferencia. El drenaje encola las keys PRESENTES en la réplica iKV del líder al entrar a
//  `.cloud`, y el push real lo hace el ciclo de prefs del runtime.
//
//  DECISIONES (documentadas — el HLC del enqueue es FRESCO, no el "HLC original" que iKV no tiene):
//   - **LÍDER-only** (gate del caller por journal en `cutover(.mirrorOff)`/`.done`): en el primer boot
//     `.cloud` del líder el backend de prefs está VACÍO → un HLC fresco no puede pisar nada. Un
//     ADOPTADOR/FOLLOWER tardío NO drena: su iKV puede ser más viejo que el backend y el HLC fresco lo
//     haría GANAR (regresión de prefs). Su delta de iKV queda como residual S8 declarado (igual que
//     I13 lo declaró para todo el canal antes de este drenaje).
//   - **Skip si la key ya tiene entry pendiente en el outbox** (belt): un write local del usuario entre
//     el relaunch y el drenaje es MÁS nuevo que la réplica iKV — no se pisa.
//   - **Ausente ≠ ""** (semántica I13): solo se drenan keys PRESENTES en iKV; nada se inventa.
//   - El SENTINEL (una vez por userID) lo estampa el caller SOLO si el drenaje completó sin fallos de
//     I/O del outbox — un fallo parcial reintenta al próximo boot (enqueue es idempotente-por-LWW).
//
//  `nonisolated` puro: sin I/O — el caller (`PreferenceSyncService`) le da el estado y ejecuta el plan.
//

import Foundation

nonisolated enum PrefsCutoverDrain {

    /// ¿La fase journaleada corresponde al LÍDER de una migración en su ventana post-relaunch?
    /// (`cutover(.mirrorOff)` = boot del relaunch asistido con el `done` aún no sintetizado; `.done` =
    /// migración cerrada). Cualquier otra fase (incl. `.notStarted` de un adoptador/follower) NO drena.
    static func isLeaderPostRelaunchPhase(_ phase: MigrationPhase) -> Bool {
        switch phase {
        case .cutover(.mirrorOff), .done:
            return true
        default:
            return false
        }
    }

    /// Plan puro del drenaje: de `allKeys`, las que están PRESENTES en iKV (`presentInIKV`) y NO tienen
    /// ya una entry pendiente del owner en el outbox (`pendingInOutbox`). Orden estable (el de `allKeys`).
    static func plan(
        allKeys: [String],
        presentInIKV: Set<String>,
        pendingInOutbox: Set<String>
    ) -> [String] {
        allKeys.filter { presentInIKV.contains($0) && !pendingInOutbox.contains($0) }
    }

    // MARK: - Sentinel (DIFERIDOS #37 — la reversa/el sign-out deben poder retirarlo)

    /// Prefijo SSOT del sentinel "drenaje ya corrió" (`cloudSync.prefsCutoverDrained.<userID>`,
    /// `UserDefaults.standard`). Lo estampa `PreferenceSyncService.drainiKVToOutboxOnceIfNeeded` y lo
    /// retiran la REVERSA (`.persistICloudMode`, §h cuarteto de cierre) y el wipe del sign-out `.cloud`
    /// (`performSignOutWipeIfArmed`) — sin ese retiro, una RE-migración de la misma instalación haría
    /// skip del drenaje y las keys iKV de la época `.icloud` intermedia jamás llegarían a
    /// `user_preferences` (H3 de la corrida device I14, 2026-07-12: `consent_keys=null` tras re-migrar).
    static let sentinelPrefix = "cloudSync.prefsCutoverDrained."

    /// Filtro puro: de `allKeys` (p.ej. `dictionaryRepresentation().keys`), las que son sentinels del
    /// drenaje (CUALQUIER userID — tras volver a `.icloud` toda re-migración futura debe re-drenar, y
    /// un sentinel de otro sub es basura inerte). El prefijo termina en "." → exige el separador.
    static func sentinelKeys(in allKeys: [String]) -> [String] {
        allKeys.filter { $0.hasPrefix(sentinelPrefix) }
    }
}
