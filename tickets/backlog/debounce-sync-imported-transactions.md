---
id: debounce-sync-imported-transactions
status: backlog
priority: low
area: groups-bridge
created: 2026-05-25
updated: 2026-08-26
source: YalaWiki/Backlog/debounce-transactions-imported-from-sync-observer.md
---


# Debounce al observer `transactionsImportedFromSync`

## Problema

`AppBootstrapper.observeTransactionsImportedFromSync` (`Yala/App/AppBootstrapper.swift:499-511`) escucha `.transactionsImportedFromSync` y dispara `GroupBridgeRaceCleaner.cleanupPendingDraftsWithMatchingTX(in:)` en cada disparo, sin debounce ni cancelación:

```swift
private func observeTransactionsImportedFromSync(context: ModelContext) {
    raceCleanerModelContext = context
    NotificationCenter.default.addObserver(
        forName: .transactionsImportedFromSync,
        object: nil,
        queue: .main
    ) { _ in
        MainActor.assumeIsolated {
            guard let context = AppBootstrapper.shared.raceCleanerModelContext else { return }
            _ = GroupBridgeRaceCleaner.cleanupPendingDraftsWithMatchingTX(in: context)
        }
    }
}
```

**Confirmado (2026-07-01): la notification se posta en `iCloudSyncService.swift:283-289`, dentro de `apply(eventType:.importEvent, ...)`, cada vez que un batch de import completa con éxito** — a diferencia de `.iCloudFirstImportCompleted` (one-shot, gateado por `hasCompletedFirstImport`), esta SÍ se repite: el comentario inline en el propio código lo dice explícitamente ("cada import successful dispara este event (no solo el primero)"). `NSPersistentCloudKitContainer` reporta el import en varios lotes en cold launch con cuenta poblada (y más en un restore real de iCloud) — cada lote dispara su propio evento con `endDate`, y por tanto su propia notification. El diseño de todo el sistema de quiescencia del proyecto (`isImportQuiescent`, `SubcategoryDedupGate`, ventanas 8s/60s) existe precisamente porque este NO es un evento único sino una ráfaga — no hay un número fijo documentado de lotes, pero el patrón es "varios por sesión, más en restore".

## Por qué es baja prioridad

Se mantiene: el costo interno de `GroupBridgeRaceCleaner.cleanupPendingDraftsWithMatchingTX` (`Yala/Services/Groups/GroupBridgeRaceCleaner.swift`, 87 líneas) ya es razonable para una sola ejecución — 2 fetches (`InboxDraft` groupExpense pendientes + `TransactionItem` bridgeadas) + un `Set` build + un loop con lookup O(1), sin N+1 (el propio doc del archivo lo llama "Single-fetch + Set lookup"). Además, la función arranca con `guard iCloudSyncService.shared.isImportQuiescent else { return 0 }` — si el import sigue activo en el momento exacto del disparo, no hace nada. El problema NO es que cada ejecución sea cara, es que se **repite completa N veces** por ráfaga cuando bastaría una vez al final.

## Solución propuesta

**Copiar literal el patrón trailing-only ya establecido en el mismo archivo**, `observeRemoteStoreChanges` (`AppBootstrapper.swift:537-575`), que resuelve exactamente este problema para una notification hermana (`.NSPersistentStoreRemoteChange`):

```swift
private func observeTransactionsImportedFromSync(context: ModelContext) {
    raceCleanerModelContext = context
    NotificationCenter.default.addObserver(
        forName: .transactionsImportedFromSync,
        object: nil,
        queue: .main
    ) { _ in
        MainActor.assumeIsolated {
            let bootstrapper = AppBootstrapper.shared
            bootstrapper.pendingRaceCleanerTask?.cancel()
            bootstrapper.pendingRaceCleanerTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                guard let context = bootstrapper.raceCleanerModelContext else { return }
                _ = GroupBridgeRaceCleaner.cleanupPendingDraftsWithMatchingTX(in: context)
            }
        }
    }
}
```

Nueva propiedad de instancia, junto a `raceCleanerModelContext` (línea 61-64) y a las otras `Task<Void, Never>?` ya existentes en la clase (`subscriptionCheckTask`, `remoteChangeTask`, líneas 55-57):
```swift
private var pendingRaceCleanerTask: Task<Void, Never>?
```

**Sin leading-edge** (a diferencia de `observeRemoteStoreChanges`, que sí dispara inmediato en el primer evento de la ráfaga para `markRemoteChangePending()`) — el cleanup no necesita reaccionar al primer evento, solo correr una vez al final de la ráfaga. Es la forma trailing-only más simple.

**Delay sugerido: 1s** (coincide con el TODO original, más generoso que el 150ms de Panel o el 3s de `observeRemoteStoreChanges` — no hay urgencia de UI en este cleanup, es limpieza en background).

## Plan técnico

### Archivos involucrados

| Archivo | Acción | Qué cambia |
|---|---|---|
| `Yala/App/AppBootstrapper.swift:499-511` | Editar | Envolver la llamada a `cleanupPendingDraftsWithMatchingTX` en el `Task` cancelable |
| `Yala/App/AppBootstrapper.swift` (junto a línea 57) | Editar | Nueva propiedad `private var pendingRaceCleanerTask: Task<Void, Never>?` |

**Sin cambios** en `GroupBridgeRaceCleaner.swift` (la función en sí no cambia, solo la cadencia de invocación) ni en `iCloudSyncService.swift` (el posteo de la notification no cambia — sigue disparándose por cada batch, el coalescing pasa a vivir en el consumidor).

## Acceptance Criteria

- [ ] El observer usa un `Task<Void, Never>?` cancelable con delay de 1s, replicando el patrón trailing-only de `observeRemoteStoreChanges`.
- [ ] Con un cold launch de una cuenta con historial grande (varios lotes de import), `cleanupPendingDraftsWithMatchingTX` corre una sola vez al final de la ráfaga, no una vez por lote (verificar con un log DEBUG temporal contando invocaciones reales).
- [ ] El cleanup sigue corriendo eventualmente incluso si la app se cierra a mitad de una ráfaga (el próximo launch reintenta — comportamiento ya garantizado por el diseño idempotente del cleaner, no requiere cambio).
- [ ] Build verde + test-smart (no hay tests unitarios de este observer específico — es orquestación de `AppBootstrapper`, no lógica pura; no se espera añadir tests nuevos para este ticket puntual).

migrated from YalaWiki Backlog/debounce-transactions-imported-from-sync-observer.md @ 1934e8ad
