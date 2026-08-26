---
id: groups-tab-missing-panel-perf
status: backlog
priority: high
area: "groups, performance, cloudkit"
created: 2026-04-17
updated: 2026-08-26
source: YalaWiki/Bugs/qa_groups-tab-no-perf-patterns.md
---


# Groups — Tab sin ninguno de los patrones de PanelView

## Problema

Lag perceptible en 3 escenarios:

1. **Al entrar a la tab Grupos** — `GroupsContainerView.onAppear` dispara `loadData()` **dos veces**: una síncrona (vía `viewModel.setContext(modelContext)`) y otra async justo después (vía `Task { await viewModel.refreshFromCloud(force: false) }`, que corre `SplitSyncManager.syncNow` y luego `loadData()` otra vez). Cada `loadData()` hace fetch + `calculateBalances` por cada grupo activo + `globalSummary` (que corre la simplificación de deudas) — todo síncrono en `@MainActor`, sin skeleton salvo en la lista principal.
2. **Al abrir un grupo específico** (`GroupDetailView`) — mismo patrón de doble-load: `setContext()` (síncrono) + `refreshFromCloud` (async). `loadData()` recalcula `calculateBalances` + `calculateDebts` (que invoca el algoritmo O(n²) de `DebtSimplificationService` cuando `group.simplifyDebts == true`, que es el default) en main thread, sin skeleton propio (a diferencia de la lista, `GroupDetailView` no tiene ningún gate de "primera carga").
3. **Al recibir cambios de CloudKit** (otro miembro agrega gasto, settlement, etc.) — cada bump de `sessionState.dataVersion` dispara `loadData()` directo en `GroupsContainerView` Y `GroupDetailView` simultáneamente (si ambas vistas están montadas). **Sin debounce, sin coalescing.** Si llegan 5 cambios seguidos = 5 recálculos completos en cada vista montada.

### Confirmado en esta sesión (contra el código real de `/Users/jur/Yala`, 2026-07-01)

Se investigó con 2 agentes de exploración en paralelo — uno extrajo el patrón exacto de `PanelViewModel`/`PanelView`/`PanelShell`, otro verificó línea por línea el estado actual de Groups. Esto es lo que confirma, corrige o agrega al análisis original del ticket:

- **Los paths de archivo del ticket original estaban desactualizados.** Los ViewModels de Groups NO viven en `Yala/App/ViewModels/Groups/` — viven directo en `Yala/App/ViewModels/` (`GroupsViewModel.swift`, `GroupDetailViewModel.swift`, `GroupStatsViewModel.swift`). Las Views y Services sí están donde el ticket decía (`Yala/App/Views/Groups/`, `Yala/Services/Groups/`).
- **`hasLoadedOnce` YA EXISTE** en `GroupsViewModel.swift:28` (`private(set) var hasLoadedOnce: Bool = false`), seteado a `true` en `loadData():103`, y gatea un `ProgressView()` en `GroupsContainerView.swift:42-46`. Es un fix real de 2026-06-30 (ver Decisiones Recientes de CLAUDE.md) para una carrera de arranque en "Solo Grupos". **Pero solo cubre la lista** — ni `GroupDetailView` ni `GroupStatsView` tienen un gate equivalente; ambas renderizan contenido inmediatamente sin distinguir "cargando" de "vacío".
- **El `onChange(of: sessionState.dataVersion)` vive en la VIEW, no en el ViewModel** — ninguno de los 2 ViewModels de Groups importa `SwiftUI` ni tiene lógica de `onChange`/`scenePhase` (solo `Foundation` + `SwiftData`). Los handlers reales son:
  - `GroupsContainerView.swift:193-195` → `.onChange(of: sessionState.dataVersion) { viewModel.loadData() }`
  - `GroupDetailView.swift:211-221` → `.onChange(of: sessionState.dataVersion) { viewModel.loadData(); /* + lógica de dismiss si el grupo se archivó o eliminó */ }` — **este handler no es solo un reload, también decide si debe cerrar el detalle**; cualquier fix de debounce tiene que preservar esa lógica de dismiss intacta y ejecutada tras el reload, no en paralelo.
- **`.onDisappear` NO está vacío como decía el ticket** — existe en ambas vistas (`GroupsContainerView.swift:190-192`, `GroupDetailView.swift:208-210`) pero solo resetea `showNudgeBanner = false`. No cancela ningún Task ni limpia estado del ViewModel — el efecto práctico (nada se cancela) es el mismo que "vacío", pero la afirmación literal era incorrecta.
- **`GroupStatsView` — el `onChange(selectedPeriod)` también vive en la View, no en el VM** — `GroupStatsView.swift:53-57` y `:58-62` (dos handlers, uno por `selectedPeriod` y otro por `currencySelection`), ambos llaman `viewModel.recalculate()` síncrono sin debounce. `GroupStatsViewModel.swift` no tiene ningún `onChange`.
- **`GroupService.fetchAllGroups()` (línea 904-910) confirmado sin predicate ni `fetchLimit`** — pero existe una función hermana `fetchActiveGroups()` (línea 894-901) que SÍ filtra `!$0.isArchived`. El VM usa `fetchAllGroups()` deliberadamente porque necesita AMBOS conjuntos (`activeGroups` y `archivedGroups` son computed properties sobre el mismo array `groups`) — cambiar a `fetchActiveGroups()` rompería `archivedGroups`. El fix de este punto no es "cambiar de función", es acotar el trabajo PESADO (fetch de expenses/shares/settlements + `calculateBalances`) solo a los grupos activos, que `GroupsViewModel.loadData():116` YA hace (`guard !group.isArchived else { continue }`) — el problema real es que el fetch de `SplitGroup` en sí (metadata liviana) trae archivados también, lo cual es aceptable; no hay `fetchLimit` en ningún fetch de Groups, lo cual sí es un problema si un usuario acumula cientos de grupos.
- **`GroupBalanceService.calculateBalances`/`calculateDebts` son funciones puras stateless por diseño** (comentario de cabecera: "Stateless enum — receives data as parameters, like SplitCalculator") — la ausencia de cache es arquitectura intencional, no un descuido. Cachear ahí violaría el diseño; el cache debe vivir en el VM (que sí tiene estado) o en un wrapper con key de invalidación.
- **`DebtSimplificationService.simplifyForCurrency` se autodocumenta como O(n²)** en su propio comentario (línea 41: `/// Greedy minimum cash flow O(n^2) for a single currency.`) — no es una inferencia del ticket, es texto literal en el código.
- **Hallazgo nuevo no documentado en el ticket original: `globalSummary` corre la simplificación de deudas INCONDICIONALMENTE, cruzando TODOS los grupos.** `GroupBalanceService.globalSummary(...)` (línea 237-244) llama `DebtSimplificationService.simplify(debts:)` sin gatear por el toggle `simplifyDebts` de cada grupo — esto corre en cada `GroupsViewModel.loadData()` (línea 146) sin importar si el usuario desactivó "simplificar deudas" en sus grupos individuales. Es el hot path más caro de la tab Grupos y no estaba en el análisis original.
- **Hallazgo nuevo: `viewModel.currentUserDebts(for: group)` se invoca en `groupCardRow(group:)`** (`GroupsContainerView.swift:270`), que se ejecuta por cada card dentro del `ForEach` de la lista. Esto significa que el cálculo de deudas (que internamente puede llamar el algoritmo O(n²)) se re-ejecuta en cada `body` evaluation de SwiftUI de cada card — no solo cuando `loadData()` corre, sino potencialmente en cada re-render causado por scroll, cambio de tema, o cualquier invalidación de `@Observable` ajena a los datos.
- **`GroupExpenseService.fetchExpenses/fetchAllShares/fetchSettlements` tienen predicate por zona pero sin `fetchLimit`** — traen el historial completo de un grupo sin límite, lo cual es razonable para el cálculo de balances (necesita TODO el historial, no solo los últimos N) pero significa que un grupo con miles de gastos acumulados escala linealmente sin cap.

## Solución propuesta

**Patrón exacto a replicar, extraído de `PanelViewModel.swift` / `PanelView.swift` / `PanelShell.swift` / `PanelDataObservers.swift`** (nota de arquitectura: el patrón vive repartido en 4 archivos, no 2 — `PanelShell` es el wrapper liviano que realmente monta el tab, y `PanelDataObservers.swift` es el `ViewModifier` que contiene el `.onChange(of: sessionState.dataVersion)`, separado del `body` pesado de `PanelView` a propósito, según el comentario de cabecera de `PanelShell.swift:5-9`: *"Hosts .sheet() and all SessionState onChange observers so that UISheetPresentationController.layoutBelowIfNeeded and observation cancel/re-register during tab switches hit PanelShell (trivial body) instead of PanelView (heavy body with NavigationStack + widgets)"*).

### 1. Debounce 150ms + Task cancelable (`scheduleRecalculation(reload:)`)

Copiar literal el patrón de `PanelViewModel.swift:2322-2337`:

```swift
/// Shared debounce (150ms). `pendingReload` ensures a reload request isn't lost
/// if a subsequent calculate-only call arrives within the debounce window.
/// Guarded by isInBackground to prevent 0x8BADF00D during snapshot capture.
private func scheduleRecalculation(reload: Bool) {
    guard !isInBackground else { return }
    guard UIApplication.shared.applicationState == .active else { return }
    if reload { pendingReload = true }
    recalculateTask?.cancel()
    recalculateTask = Task { @MainActor in
        do { try await Task.sleep(for: .milliseconds(150)) } catch { return }
        guard !Task.isCancelled else { return }
        let shouldReload = pendingReload
        pendingReload = false
        if shouldReload {
            loadData()
        }
        performCalculation()
    }
}
```

Propiedades backing necesarias (espejo de `PanelViewModel.swift:209-215`):
```swift
private var recalculateTask: Task<Void, Never>?
private var pendingReload = false
private(set) var isInBackground = false
```

**Adaptación a Groups**: `GroupsViewModel` y `GroupDetailViewModel` NO tienen hoy una función `performCalculation()` separada de `loadData()` — hoy `loadData()` hace fetch+calc todo junto (ver punto 2). Para replicar el patrón hay que primero partir `loadData()` en dos, y luego envolver ambas en el debounce.

### 2. Separación reload vs calc-only

Copiar el patrón de dos funciones públicas que delegan al debounce (`PanelViewModel.swift:2276-2280` y `:2314-2317`):

```swift
/// Debounced recalculation (150ms) — coalesces rapid onChange cascades.
/// Does NOT reload from SwiftData — filter changes only need recalculation.
func recalculateData() {
    scheduleRecalculation(reload: false)
}

/// Debounced reload + recalculation — used when actual data may have changed
func reloadAndRecalculate() {
    scheduleRecalculation(reload: true)
}
```

**Trabajo previo en Groups antes de poder aplicar esto**: hay que separar `GroupsViewModel.loadData()` (línea 93-160) en:
- `loadGroupsAndRelatedData()` — el fetch puro (grupos + members + expenses + shares + settlements por grupo), sin cálculo.
- `recalculateBalancesAndSummary()` — `calculateBalances` por grupo + `globalSummary`, operando sobre los arrays ya cacheados en memoria (`expensesByGroup`, `sharesByGroup`, `settlementsByGroup`, que YA existen como propiedades del VM — línea 36-38 — pobladas por el fetch).

Mismo split para `GroupDetailViewModel.loadData()` (línea 115-165): separar el fetch (members/expenses/shares/settlements/bridge maps) del cálculo (`calculateBalances` + `calculateDebts`).

### 3. Cancelación en `.onDisappear`

Copiar literal de `PanelView.swift:275-277`:
```swift
.onDisappear {
    viewModel.cancelRecalculation()
}
```
Función en el VM (`PanelViewModel.swift:2271-2274`):
```swift
func cancelRecalculation() {
    recalculateTask?.cancel()
}
```

Reemplaza el contenido actual de `GroupsContainerView.swift:190-192` y `GroupDetailView.swift:208-210` (que hoy solo hacen `showNudgeBanner = false`) — hay que AÑADIR la llamada de cancelación, no reemplazar el reset del nudge banner (ambas cosas deben coexistir en el mismo `.onDisappear`).

### 4. Background guard (scenePhase)

Copiar de `PanelView.swift:278-289` + `PanelViewModel.swift:2261-2269`:
```swift
// En la View:
.onChange(of: scenePhase) { _, newPhase in
    switch newPhase {
    case .background, .inactive:
        viewModel.setBackground(true)
    case .active:
        guard UIApplication.shared.applicationState == .active else { return }
        viewModel.setBackground(false)
        viewModel.reloadAndRecalculate()
    @unknown default:
        break
    }
}

// En el VM:
func setBackground(_ value: Bool) {
    isInBackground = value
    if value {
        recalculateTask?.cancel()
        recalculateTask = nil
        pendingReload = false
    }
}
```
`GroupsContainerView` y `GroupDetailView` necesitan añadir `@Environment(\.scenePhase) private var scenePhase` (no existe hoy en ninguna de las dos).

### 5. Debounce del `onChange(dataVersion)`

Reemplazar la llamada directa a `loadData()` en:
- `GroupsContainerView.swift:193-195` → `viewModel.reloadAndRecalculate()`.
- `GroupDetailView.swift:211-221` → cuidado: este handler tiene lógica de dismiss DESPUÉS del reload (líneas 213-220). Con debounce async, esa lógica de dismiss debe correr dentro del Task del debounce, después del `loadData()`, no fuera — de lo contrario el `dismiss()` se evaluaría contra el estado del grupo ANTES de que el reload haya corrido, con el debounce en curso.
- `GroupStatsView.swift:53-57` y `:58-62` → `viewModel.recalculate()` no tiene debounce propio hoy; como `GroupStatsViewModel` no está en el loop de sync CloudKit directo (recibe datos ya cargados por el padre `GroupDetailViewModel`, vía props `expenses`/`shares`/`members`/`settlements`), el debounce aquí es de menor prioridad que en los otros dos VMs — considerar si vale la pena replicar el patrón completo o basta con un debounce simple ad-hoc (ver Riesgos).

Espejar cómo el patrón de Panel separa esto en un `ViewModifier` dedicado (`PanelDataObservers.swift:51-59`, montado desde `PanelShell.swift:25-28`) si se decide extraer un wrapper liviano análogo a `PanelShell` para `GroupsContainerView`/`GroupDetailView` — opcional, no bloqueante para el fix.

### 6. Cache de `globalSummary`/`simplify()` por hash de inputs

`GroupBalanceService`/`DebtSimplificationService` son stateless por diseño (punto confirmado arriba) — el cache NO va ahí. Va en el VM: antes de llamar `GroupBalanceService.globalSummary(...)` (línea 146 de `GroupsViewModel`) o `GroupBalanceService.calculateDebts(...)` (línea 135 de `GroupDetailViewModel`), computar una key liviana (ej. `(allExpenses.count, allSettlements.count, allShares.count)` o un hash de IDs+`updatedAt` si el count no es suficientemente discriminante) y comparar contra la key del cálculo anterior; si es igual, reusar el resultado cacheado en vez de recalcular.

### 7. Equality guards antes de mutar `@Observable`

Copiar el patrón de `PanelViewModel.swift:336-337` (`if fetched != accounts { accounts = fetched }`, repetido para cada fetch) aplicado a:
- `GroupsViewModel.swift:97` → `groups = try GroupService.shared.fetchAllGroups()` sin guard.
- `GroupsViewModel.swift:146,153` → `globalSummary = ...` sin guard (requiere que `GroupGlobalSummary` sea `Equatable` — YA LO ES, confirmado en `GroupBalanceService.swift:22`: `struct GroupGlobalSummary: Equatable, Sendable`).
- `GroupDetailViewModel.swift:153-154` → `balances = ...` / `debts = ...` sin guard (`MemberBalance` y `Debt` también son `Equatable` — confirmado en `GroupBalanceService.swift:12` y `DebtSimplificationService.swift:12`).

### 8. `isReady` / skeleton en `GroupDetailView` y `GroupStatsView`

`GroupsContainerView` ya tiene esto vía `hasLoadedOnce` (confirmado arriba) — falta replicarlo en `GroupDetailView` (no tiene ningún gate de "primera carga", renderiza `tabContent` de inmediato) y en `GroupStatsView` (solo distingue `expenses.isEmpty`, que es un empty-state real, no un "todavía cargando"). Agregar `private(set) var isReady: Bool = false` en `GroupDetailViewModel`, seteado en la función de calc (punto 2) tras el primer cálculo exitoso, consumido con `.yalaSkeleton(!viewModel.isReady)` (mismo modifier que usa `PanelView.swift:209`).

### 9. Eliminar el doble-load en `.onAppear`

Hallazgo nuevo de esta sesión: tanto `GroupsContainerView.swift:175-182` como `GroupDetailView.swift:194-207` llaman `viewModel.setContext(modelContext)` (que dispara `loadData()` síncrono internamente — `GroupsViewModel.swift:86-89`, `GroupDetailViewModel.swift:100-103`) Y ADEMÁS `Task { await viewModel.refreshFromCloud(force: false) }` (que corre `SplitSyncManager.syncNow` y luego `loadData()` otra vez). Esto no estaba en el análisis original del ticket. Fix: que `setContext()` NO dispare `loadData()` automáticamente cuando se sabe que `refreshFromCloud` va a correr inmediatamente después — o que `refreshFromCloud` reciba una bandera para saltarse su `loadData()` final si el caller ya sabe que hará uno. Requiere decidir cuál de los dos loads es el que debe quedar (probablemente el de `refreshFromCloud`, porque incluye el fetch de CloudKit; el síncrono de `setContext` solo sirve para no dejar la vista vacía mientras el async corre — con el skeleton del punto 8, ese propósito ya queda cubierto sin necesidad de un load real).

## Plan técnico

### Archivos involucrados

| Archivo | Acción | Qué cambia |
|---|---|---|
| `Yala/App/ViewModels/GroupsViewModel.swift` | Editar | Split `loadData()` (93-160) en fetch-only + calc-only; añadir `scheduleRecalculation`/`recalculateData`/`reloadAndRecalculate`/`cancelRecalculation`/`setBackground` (patrón punto 1-4); equality guards en `groups` (97), `globalSummary` (146, 153); cache de `globalSummary` por hash de inputs (punto 6) |
| `Yala/App/ViewModels/GroupDetailViewModel.swift` | Editar | Mismo split en `loadData()` (115-165); mismas funciones de debounce; equality guards en `balances`/`debts` (153-154); `isReady` flag nueva; cache de `calculateDebts` por hash |
| `Yala/App/ViewModels/GroupStatsViewModel.swift` | Editar (menor) | Sin cambios estructurales grandes — evaluar si necesita debounce propio (ver Riesgos, punto 5 de la Solución) |
| `Yala/App/Views/Groups/GroupsContainerView.swift` | Editar | `.onChange(dataVersion)` (193-195) → `reloadAndRecalculate()`; `.onDisappear` (190-192) → añadir `viewModel.cancelRecalculation()`; añadir `@Environment(\.scenePhase)` + `.onChange(scenePhase)` (patrón punto 4); resolver doble-load de `.onAppear` (175-182, punto 9) |
| `Yala/App/Views/Groups/GroupDetailView.swift` | Editar | `.onChange(dataVersion)` (211-221) → `reloadAndRecalculate()` preservando la lógica de dismiss (213-220) DENTRO del Task post-reload; `.onDisappear` (208-210) → añadir `cancelRecalculation()`; añadir scenePhase; resolver doble-load de `.onAppear` (194-207); consumir `isReady` con `.yalaSkeleton` |
| `Yala/App/Views/Groups/GroupStatsView.swift` | Editar (menor) | `.onChange(selectedPeriod)` (53-57) y `.onChange(currencySelection)` (58-62) → evaluar debounce simple si el perfilado lo justifica |
| `Yala/Services/Groups/GroupBalanceService.swift` | Sin cambios de código | Confirmar que se mantiene stateless (el cache va en los VMs, no aquí) |
| `Yala/Services/Groups/DebtSimplificationService.swift` | Sin cambios de código | Idem — el algoritmo O(n²) se mantiene, solo se evita invocarlo redundantemente desde el VM |

### Incrementos de implementación

1. **Split fetch/calc en ambos VMs + equality guards + `isReady`** (sin debounce todavía). Archivos: `GroupsViewModel.swift`, `GroupDetailViewModel.swift`. Verificación: build verde (`/verify-ios`), `test-smart` sobre los VMs si hay tests existentes, y confirmar manualmente en simulador que la lista de grupos y el detalle siguen mostrando los mismos números que antes del refactor (mismo `globalSummary`, mismos balances por grupo) — este paso es un refactor puro, no debe cambiar ningún valor mostrado.
2. **Añadir el debounce (`scheduleRecalculation`/`recalculateData`/`reloadAndRecalculate`/`cancelRecalculation`/`setBackground`) sobre el split del paso 1.** Cablear `.onDisappear` y `.onChange(scenePhase)` en ambas Views. Verificación: en simulador, entrar y salir rápido de la tab Grupos / de un detalle varias veces seguidas sin que aparezcan crashes ni estados inconsistentes; confirmar con logs DEBUG que `loadData()` real (el fetch) no corre más de una vez por ráfaga de cambios en 150ms.
3. **Resolver el doble-load de `.onAppear` (punto 9) y debouncear `onChange(dataVersion)` en las Views (punto 5).** Cuidado especial en `GroupDetailView` con la lógica de dismiss condicional. Verificación: escenario de 2 dispositivos con el mismo grupo — agregar 3-5 gastos rápidos en uno, confirmar que el otro dispositivo no dispara 3-5 recálculos completos sino uno solo tras el debounce, y que el detalle no se cierra ni parpadea si el grupo NO se archivó.
4. **(Opcional, si el perfilado lo justifica) Cache de `globalSummary`/`calculateDebts` por hash de inputs (punto 6) y debounce en `GroupStatsView` (punto 5, última viñeta).** Verificación: con un grupo de prueba con 100+ gastos y 10+ miembros, medir con Instruments (Time Profiler) el tiempo de `loadData()` antes/después de introducir el cache — solo vale la pena si el perfilado muestra que la simplificación de deudas repetida es medible en el hot path real, no solo teóricamente costosa.

## Riesgos

- **Debounce demasiado agresivo puede introducir un delay perceptible en acciones del propio usuario** (ej. tras `deleteExpense`/`confirmSettlement`/`rejectSettlement` en `GroupDetailViewModel`, que hoy llaman `loadData()` directo y sin debounce — líneas 221, 245, 271, 285 — el usuario espera ver el resultado de su propia acción de inmediato). Si se envuelve TODO `loadData()` bajo el debounce de 150ms sin distinguir "acción local del usuario" de "cambio remoto de CloudKit", una acción propia del usuario quedaría con un retraso artificial de 150ms que no existe hoy. Mitigación: las acciones locales (`deleteExpense`, `confirmSettlement`, etc.) deben seguir llamando una versión SIN debounce (o con un debounce mínimo tipo 0ms/`Task.yield`), mientras que solo el trigger de `onChange(dataVersion)` (que sí puede llegar en ráfagas por sync remoto) pasa por el debounce de 150ms — igual que en Panel, donde `recalculateData()`/`reloadAndRecalculate()` son invocadas selectivamente según el origen del cambio, no ciegamente en cada mutación.
- **Un equality guard mal calibrado puede ocultar un cambio real.** `GroupGlobalSummary`, `MemberBalance` y `Debt` son `Equatable` porque comparan TODOS sus campos — esto es seguro (un cambio real en cualquier campo rompe la igualdad). El riesgo NO está en estos guards puntuales, sino en el cache de hash del punto 6: si la key de invalidación (ej. solo `count` de expenses/settlements) no captura una edición in-place (mismo count, pero un `amount` o `paidByMemberID` cambió), el cache devolvería un resultado stale. Mitigación: si se implementa el cache, la key debe incluir algo sensible a ediciones (hash de `updatedAt` más reciente entre todos los items, o simplemente no cachear y confiar en el debounce + equality guards de salida para absorber el costo — este es el enfoque más seguro y es exactamente lo que hace Panel, que NO cachea `performCalculation()` en sí, solo debouncea CUÁNDO se ejecuta).
- **El `.onChange(dataVersion)` de `GroupDetailView` tiene lógica de dismiss condicional (líneas 213-220) que depende del estado del grupo DESPUÉS del reload.** Si el debounce se implementa mal (ej. el `dismiss()` se evalúa antes de que el `Task` del debounce complete, o se evalúa sobre una copia stale de `group.isArchived`), el detalle podría no cerrarse cuando debería (si el grupo se archivó remotamente) o cerrarse de más. Este es el punto de mayor riesgo de regresión funcional del ticket — requiere test manual explícito en el escenario "grupo se archiva mientras el detalle está abierto" antes de dar por cerrado el incremento 3.
- **El doble-load de `.onAppear` (punto 9) puede tener una razón intencional no documentada** — el load síncrono de `setContext()` podría existir precisamente para que la vista no se vea vacía mientras el async de `refreshFromCloud` corre (que puede tardar segundos si hay red lenta). Eliminarlo sin el skeleton del punto 8 ya implementado dejaría la vista en blanco más tiempo del que está hoy. Por eso el plan técnico secuencia el `isReady`/skeleton (paso 1) ANTES de tocar el doble-load (paso 3).
- **`GroupStatsViewModel` es un caso aparte** — no está en el loop directo de `sessionState.dataVersion` (recibe sus datos ya cargados como props desde `GroupDetailView`, no hace su propio fetch de CloudKit). Aplicarle el patrón completo de Panel (con `isInBackground`/`scenePhase`/etc.) sería sobre-ingeniería si el VM padre (`GroupDetailViewModel`) ya debounce su propio reload — un cambio de `selectedPeriod` solo dispara `recalculate()` sobre datos ya en memoria, sin fetch, así que el costo real a mitigar aquí es mucho menor que en los otros dos VMs. Decidir en el incremento 4 si vale la pena tocarlo, o dejarlo como está y solo documentar la decisión.
- **Riesgo de que el ratchet de QA (`qa/coverage-index.json`) no tenga cobertura XCUITest para el área de Groups performance** — al tocar código bajo `Yala/` en el mismo commit hay que actualizar el área correspondiente del index según CLAUDE.md. Si el área es `agentic` (no `deterministic`), la verificación es vía `/device-qa`, no XCUITest — confirmar la clasificación actual antes de asumir qué tipo de test se espera.

## Implementación (código COMPLETO — 3 incrementos; pendiente solo validación de perf cross-device en TestFlight)

### 2026-07-03 — Inc.3/3 — `063f6aff` `perf(groups): debounce del sync remoto + dismiss-first + debounce en GroupStats`

**Resumen:** el fix de performance real. Las ráfagas de cambios de CloudKit ahora coalescen en un solo recálculo (antes: uno por cambio, cada uno con el O(n²) de simplificación de deudas).

**Archivos:**
- `GroupsContainerView`/`GroupDetailView` — `onChange(dataVersion)` → `reloadAndRecalculate()` (debounced). En el detalle, reorden **dismiss-first** (las condiciones leen el modelo `group` directo → decidir cerrar ANTES, sin carrera con el reload).
- Pull-to-refresh (`force:true`) y las mutaciones locales del usuario siguen SÍNCRONOS (`loadData()` directo).
- `GroupStatsView`/`GroupStatsViewModel` — debounce mínimo calc-only (`scheduleRecalculate`, 150ms) + `cancelRecalculation` en `onDisappear`.

**`/code-review high` (3 finders) → 3 fixes aplicados:**
1. `GroupDetailViewModel.fetchData` — fetch ATÓMICO (locales → asignar solo si todos tuvieron éxito; evita `members`-nuevo/`expenses`-viejo que `recalculate` computaría como estado mixto).
2. `GroupDetailViewModel.fetchData` — `defer { isReady = true }` tras el intento (no solo en éxito) → no deja skeleton eterno si un fetch falla (espeja el diseño temprano de `hasLoadedOnce`).
3. `GroupStatsView` — `syncCarouselPage()` movido a un `onChange` reactivo sobre los códigos de moneda (corre DESPUÉS del recalculate debounced, con datos frescos; antes leería `perCurrencyStats` stale → página de carrusel inválida).

**Refutados** (matchean Panel, auto-sanan): pérdida de `pendingReload` en background (se re-dispara en `scenePhase .active`); race de `applicationState` (doble-guard como Panel).

**Verificación:** `/verify-ios` verde; 82 tests verdes (3 suites de Grupos).

### 2026-07-03 — Inc.2/3 — `55e17488` `refactor(groups): infra de debounce + lifecycle scenePhase`

**Resumen:** maquinaria de debounce (espejo de `PanelViewModel`), sin cablear aún el `onChange(dataVersion)`.

**Archivos:**
- `GroupsViewModel`/`GroupDetailViewModel` — `import UIKit` + backing props (`recalculateTask`/`pendingReload`/`isInBackground`) + `scheduleRecalculation(reload:)` (150ms, guards `isInBackground` + `applicationState`) + `reloadAndRecalculate`/`cancelRecalculation`/`setBackground`.
- `GroupsContainerView`/`GroupDetailView` — `import UIKit` + `@Environment(scenePhase)`; `.onDisappear` cancela el recálculo; `.onChange(scenePhase)` suprime en background y refresca al volver a foreground.
- Acciones locales siguen `loadData()` directo (instantáneo).

### 2026-07-03 — Inc.1/3 — `6982383b` `refactor(groups): separa loadData en fetch/calc + equality guards + skeleton en detalle`

**Resumen:** primer incremento (refactor puro, sin cambio de valores mostrados). Split de `loadData()` + equality guards + skeleton `isReady` en el detalle. Prepara el debounce de los Inc.2/3.

**Archivos modificados:**
- `Yala/App/ViewModels/GroupsViewModel.swift` — `loadData()` = `fetchData()` (fetch puro) + `recalculate()` (cálculo puro sobre dicts cacheados; reconstruye los acumuladores cruzando-grupos). Equality guards en `groups`/`balancesByGroup`/`globalSummary`.
- `Yala/App/ViewModels/GroupDetailViewModel.swift` — mismo split; flag nueva `isReady`; equality guards en `balances`/`debts`.
- `Yala/App/Views/Groups/GroupDetailView.swift` — `.yalaSkeleton(!viewModel.isReady)` sobre `tabContent`.
- `YalaTests/GroupDetailViewModelTests.swift` — regresión de `isReady` (inicial `false` + tras `loadData` sin contexto sigue `false`).

**Decisiones técnicas:**
- El `/review-plan` descubrió que `SplitSyncManager.syncNow` (`:857-860`) **NO bumpea `dataVersion` a propósito** (delega el reload al caller) → la idea original de debouncear `refreshFromCloud` habría roto el pull-to-refresh. El doble-load de entrada se resolverá con enfoque **conservador** (D1 —eliminación total— diferido).
- Cache por hash de inputs (pto 6 del plan) **diferido**: se confía en debounce + equality guards de salida (igual que Panel).

**Verificación:** `/verify-ios` verde; `/test-smart` 40 casos verdes (GroupsViewModelTests + GroupDetailViewModelTests). Equivalencia de valores del split: por construcción (mismas expresiones movidas) + verificación manual en simulador (invariante).

**Pendiente:** Inc.2 (infra debounce + lifecycle) e Inc.3+3b (debounce del sync remoto + dismiss-first + GroupStats). Plan: `~/.claude/plans/2-confirmado-funciona-actualiza-kind-fox.md`.

## Acceptance Criteria

- [x] `GroupsViewModel.loadData()` y `GroupDetailViewModel.loadData()` están separados en fetch-only + calc-only, con la misma salida (mismos balances/deudas/summary) que antes del refactor — verificado manualmente comparando valores antes/después en simulador. _(Inc.1 — `6982383b`)_
- [x] Ambos VMs tienen `scheduleRecalculation(reload:)` con debounce de 150ms + `Task<Void, Never>?` cancelable, replicando literal el patrón de `PanelViewModel.swift:2322-2337`. _(Inc.2 — `55e17488`)_
- [x] `.onChange(of: sessionState.dataVersion)` en `GroupsContainerView` y `GroupDetailView` invocan `reloadAndRecalculate()` en vez de `loadData()` directo; la lógica de dismiss de `GroupDetailView` sigue funcionando (reorden dismiss-first: las condiciones leen `group` directo, sin carrera). Test manual en device pendiente (grupo archivado/eliminado remotamente con el detalle abierto). _(Inc.3 — `063f6aff`)_
- [x] `.onDisappear` en ambas Views llama `viewModel.cancelRecalculation()` ADEMÁS de resetear `showNudgeBanner` (no en lugar de). _(Inc.2 — `55e17488`)_
- [x] Ambas Views tienen `@Environment(\.scenePhase)` + `.onChange(scenePhase)` cableado a `setBackground(_:)`, replicando `PanelView.swift:278-289`. _(Inc.2 — `55e17488`)_
- [x] Acciones locales del usuario (`deleteExpense`, `confirmSettlement`, `rejectSettlement`, `removeOpeningBalance` en `GroupDetailViewModel`) siguen sintiéndose instantáneas — NO pasan por el debounce de 150ms del sync remoto. _(Inc.2/3 — `loadData()` directo se mantiene)_
- [x] `GroupDetailView` tiene un `isReady`/skeleton equivalente al `hasLoadedOnce` de `GroupsViewModel`, consumido con `.yalaSkeleton(!viewModel.isReady)`. _(Inc.1 — `6982383b`)_
- [~] El doble-load de `.onAppear` en ambas Views se resuelve (un solo `loadData()` real por entrada a la vista, no dos), sin dejar la vista en blanco más tiempo del que está hoy (requiere el skeleton del punto anterior ya implementado). _(Inc.3 — enfoque CONSERVADOR: se mantiene el load síncrono de `setContext` + `refreshFromCloud`; la eliminación total es D1, diferida por decisión del owner porque `syncNow` no bumpea `dataVersion` y debouncear `refreshFromCloud` rompería el pull-to-refresh)_
- [ ] Escenario de validación end-to-end: 2 dispositivos (o simulador + físico) con el mismo grupo, agregar 3-5 gastos rápidos en uno — el otro dispositivo coalesce esos cambios en un solo recálculo tras el debounce, no uno por cada cambio recibido. _(PENDIENTE — TestFlight, mismo par de devices del sync fix; CKShare bloqueado en sim)_
- [x] Build verde (`/verify-ios`) y `/test-smart` sobre los archivos tocados antes de cada commit incremental. _(3 commits, build + 82 tests verdes cada vez)_
- [~] `qa/coverage-index.json`: clasificación confirmada — `groups-crud-balances-settlements` (deterministic, XCUITest) y `groups-stats-multicurrency` (agentic, device-qa). `lastVerified` NO bumpeado a propósito: los unit tests corridos NO son la cobertura del área (XCUITest/device), y el e2e de coalescing es cross-device (pendiente TestFlight). Bumpear sería drift falso. El ratchet (`bash qa/validate-coverage.sh`) sigue OK (backlog 0).

## QA Visual

### 2026-08-14 — simulador · **avance, NO cierra el ticket**

**Qué se verificó (verde):** que el debounce de 150 ms no rompió el dismiss del detalle, en **las dos
direcciones**. Es lo único que este escenario puede probar.

**Setup:** Yala Dev · Debug-Dev · iPhone 17 Pro · `-uitest -uitest-reset -uitest-skip-onboarding -uitest-pro
-uitest-seed grupos -uitest-deeplink groups`.

1. **El skeleton se levanta**: al abrir «Viaje a Cusco» aparecen `group_detail_fab_new_expense` y las filas
   de gastos; no se queda en gris. (`isReady` flipa.)
2. **Archivar → la app sale sola.** Ajustes del grupo → «Archivar grupo» → sale el diálogo de deudas
   («Hay deudas pendientes entre miembros. Si archivas, las deudas siguen vivas. ¿Continuar?») → confirmar.
   Se aterriza en la **LISTA**: existen `groups_fab_new` y la tarjeta «Viaje a Lima», **no** existe
   `group_detail_fab_new_expense`, aparece «Ver archivados (1)» y el total baja a «Te deben S/ 140,00».
   Esa aserción es la que importa: `GroupSettingsView.performArchiveToggle` llama a su propio `dismiss()`,
   que solo cerraría la sheet — ver «se cerró algo» no habría probado nada.
   ![[qa-groups-archivar-vuelve-a-lista-20260814-134428.png]]
3. **Desarchivar → NO expulsa.** Entrando al grupo archivado y tocando «Desarchivar grupo», la app **se
   queda dentro**: la sheet sigue abierta con el botón ya cambiado a «Archivar grupo» y detrás sigue el
   detalle (`group_detail_fab_new_expense`). Este paso es el que distingue la implementación correcta
   (`GroupDetailDismissDecision.shouldDismiss` cierra solo si se archivó DURANTE la sesión) de una que
   reaccione a «cambió el archivado» a secas.

**Lo que este QA NO prueba, y por qué el ticket sigue abierto:**

- **El AC de coalescing sigue pendiente** (línea marcada `[ ]`): necesita 2 dispositivos con el mismo grupo
  y ráfagas reales; CKShare no funciona en simulador. **Cerrar el ticket con esto sería cerrar un AC vivo.**
- El archivado de aquí es una mutación **LOCAL** con el objeto `SplitGroup` vivo en memoria. El caso que el
  `qa-notes` pide —**grupo archivado o eliminado REMOTAMENTE con el detalle abierto**— llega por merge y
  puede traer el modelo refaulteado: no queda cubierto.
- **El paso extra de scenePhase (background→foreground) no se pudo hacer con esta herramienta**, y conviene
  saberlo: `launch_app_sim` **no** trae la app al frente, la **mata y relanza** — y sin `launchArgs` arranca
  sin `-uitest`, así que apareció el Welcome Hero en vez del detalle. Para ejercitar
  `scenePhase .background → .active` hace falta otro mecanismo (o hacerlo a mano).
- El debounce es de 150 ms: ninguna impresión de fluidez cuenta como evidencia en ninguna dirección.

migrated from YalaWiki Bugs/qa_groups-tab-no-perf-patterns.md @ 1934e8ad
