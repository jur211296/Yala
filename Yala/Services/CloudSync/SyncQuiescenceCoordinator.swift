//
//  SyncQuiescenceCoordinator.swift
//  Yala
//
//  SSOT de la QUIESCENCIA del store personal para el motor Modo Nube (incremento I9, §i.2). Traduce
//  "¿es seguro que un save de autor NORMAL toque el store personal AHORA?" a UNA respuesta, enrutando
//  por `StorageMode` vía `StorageModeSignalRouter`:
//    - `.icloud` (HOY, SIEMPRE): la autoridad es el import de CloudKit — `isImportQuiescent` devuelve
//      EXACTAMENTE lo que devuelve `iCloudSyncService.isImportQuiescent` (paridad testeada). Ningún
//      consumidor existente cambia de fuente en este incremento (regla DARK).
//    - `.cloud` (I10/I11): la autoridad es el propio motor — `isImportQuiescent` == `isPersonalApply
//      Quiescent` (no hay un batch de apply de deltas remotos en curso).
//
//  DOS señales de lectura, no una (SERIO-1 del review):
//    - `isImportQuiescent`: para consumidores AJENOS al motor (boot-saves del wrapper de arranque, y en
//      el futuro los saves gateados de CLAUDE.md). En `.cloud` incluye el batch propio en vuelo.
//    - `isQuiescentForEngineSaves`: para los saves POST-batch del PROPIO motor (reconcilers post-pull).
//      En `.cloud` es `true` (el batch propio ya commiteó cuando corren) — usar `isImportQuiescent` ahí
//      produciría deferral perpetuo (el gate se evalúa DENTRO de la ventana markApplyBegan/Ended).
//
//  Consumidores (I9): el gate de los reconciliadores post-pull (`CloudSyncEngine.reconcilerQuiescence
//  Gate` ← `isQuiescentForEngineSaves`) y el wrapper de arranque `AppBootstrapper.awaitPersonalStore
//  Ready()` (que en `.cloud` espera `hasCompletedFirstPull && isPersonalApplyQuiescent`). En `.icloud`
//  esos consumidores siguen viendo la fuente de siempre → cero cambio de comportamiento.
//
//  `@MainActor final class`: mantiene estado mutable del motor (`isApplyingRemoteBatch`,
//  `hasCompletedFirstPull`) tocado desde el ciclo `@MainActor` del runtime. `shared` para el wiring de
//  producción; init inyectable para tests (fuente icloud + modo stubbeables).
//

import Foundation

@MainActor
final class SyncQuiescenceCoordinator {

    /// Instancia de producción (consumida por `CloudSyncRuntime` y el wrapper de arranque).
    static let shared = SyncQuiescenceCoordinator()

    /// Fuente de quiescencia del import de CloudKit (prod: `iCloudSyncService.shared.isImportQuiescent`).
    /// Inyectable para tests (paridad + escenarios de defer/retry de reconcilers). `@MainActor`: la
    /// fuente de prod lee estado aislado al main actor.
    private let icloudQuiescent: @MainActor () -> Bool

    /// Proveedor del modo actual (prod: `CloudSyncFlags.storageMode`; inyectable para probar el `.cloud`).
    private let modeProvider: () -> StorageMode

    /// `true` mientras un batch de `pullAndApplyOnce` está en vuelo (lo marca el runtime alrededor del
    /// apply). En `.cloud` esto es la señal de quiescencia del propio motor; en `.icloud` NO afecta al
    /// enrutado (la fuente es `icloudQuiescent`).
    private var isApplyingRemoteBatch = false

    /// `true` una vez que el motor completó su primer ciclo de pull `.completed` en esta sesión de
    /// proceso. Lo consume el wrapper de arranque en `.cloud` (nadie debe hacer boot-save antes del
    /// primer pull asentado, espejo de `hasCompletedFirstImport` en `.icloud`).
    private(set) var hasCompletedFirstPull = false

    init(
        icloudQuiescent: @escaping @MainActor () -> Bool = { iCloudSyncService.shared.isImportQuiescent },
        modeProvider: @escaping () -> StorageMode = { CloudSyncFlags.storageMode }
    ) {
        self.icloudQuiescent = icloudQuiescent
        self.modeProvider = modeProvider
    }

    // MARK: - Lecturas

    /// ¿Es seguro que un save de autor NORMAL toque el store personal AHORA? Enrutado por el modo.
    /// En `.icloud` == exactamente `iCloudSyncService.isImportQuiescent` (paridad); en `.cloud` ==
    /// `isPersonalApplyQuiescent`.
    var isImportQuiescent: Bool {
        switch StorageModeSignalRouter.quiescenceSource(mode: modeProvider()) {
        case .icloudImport:
            return icloudQuiescent()
        case .cloudEngine:
            return isPersonalApplyQuiescent
        }
    }

    /// Quiescencia del apply del propio motor: `true` si NO hay un batch de deltas remotos aplicándose.
    var isPersonalApplyQuiescent: Bool { !isApplyingRemoteBatch }

    /// Señal DEDICADA para los saves POST-batch del PROPIO motor (reconcilers post-pull) — SERIO-1 del
    /// review de I9. NO usar `isImportQuiescent` para eso: queda `false` durante TODA la ventana
    /// `markApplyBegan/Ended` que envuelve a `pullAndApplyOnce`... que es exactamente donde corren los
    /// reconcilers → en `.cloud` se diferirían SIEMPRE (deferral perpetuo).
    ///
    /// Semántica por modo:
    ///  - `.icloud`: `icloudQuiescent()` — el peligro real es el import de CloudKit AJENO al motor
    ///    (regla anti-crash-loop de CLAUDE.md); el estado del batch propio es irrelevante para él.
    ///  - `.cloud`: `true` SIEMPRE — cuando los reconcilers corren, el save de página del propio batch
    ///    YA commiteó (todo secuencial en el mismo actor) y no existe un import ajeno que pueda dejar
    ///    el grafo a medio hidratar.
    var isQuiescentForEngineSaves: Bool {
        switch StorageModeSignalRouter.quiescenceSource(mode: modeProvider()) {
        case .icloudImport:
            return icloudQuiescent()
        case .cloudEngine:
            return true
        }
    }

    // MARK: - Mutadores (los llama el runtime alrededor del apply / primer pull)

    func markApplyBegan() { isApplyingRemoteBatch = true }
    func markApplyEnded() { isApplyingRemoteBatch = false }
    func markFirstPullCompleted() { hasCompletedFirstPull = true }
}
