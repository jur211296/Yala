---
id: groups-cloud-mode-hardening-v1
status: discarded
priority: high
area: groups
created: 2026-07-13
updated: 2026-08-26
source: YalaWiki/Backlog/qa_groups-endurecimiento-modo-nube-v1.md
---


# Paquete de endurecimiento de Grupos para v1 del Modo Nube

Why: Discarded 2026-08-26. Parked. iCloud / boot-guard / acceptShare pieces are CloudKit and 404. Superseded by groups-backend-v1.

Decisión de origen: [[MODO-NUBE-GRUPOS-V1-DECISION]] (owner, 2026-07-13, D2) — v1 lanza con Grupos en CloudKit; los peligros REALES identificados (producto/identidad, no datos) se cierran con este paquete de 4 piezas + 1 opcional.

## Problema

1. **No existe gate "sin iCloud" para Grupos.** El tab solo se filtra por sesión secundaria y por el beta gate (`GroupsBetaGateLogic`, temporal). Un usuario sin cuenta iCloud (born-cloud del Modo Nube, o cualquier usuario que apague iCloud) ve el tab con spinner/empty-state sin explicación (`GroupsContainerView.swift:44-52`), y crear grupo/aceptar invite falla con errores genéricos. El `GroupsICloudAvailabilityGate` planeado en ARQUITECTURA §i.8(c)2 (riesgo A21) nunca se implementó.
2. **GAP 1 (gap-estados): cambio de Apple ID del OS con la app cerrada pasa desapercibido.** La limpieza reactiva existe (`handleAccountChange`, `SplitSyncManager.swift:1206-1235`: borra datos locales + resetea state de engines + limpia cache de identidad), pero depende de que CKSyncEngine entregue `.accountChange`. `groups_currentUserRecordName` persistido (`GroupUserIdentityService.swift:18-25`) nunca se compara proactivamente al boot → Grupos puede operar con identidad vieja en silencio.
3. **Invite en sesión secundaria falla EN SILENCIO.** `acceptShare` con `container == nil` (engine nunca inicializado en secundaria) hace early-return con `noteAcceptFailed` + log, sin `showGroupSyncError` (`SplitSyncManager.swift:628-636`). El invitado no ve nada.
4. **Cero cobertura de la integración bridge→motor cloud.** El camino está completo (verificado 2026-07-13), pero las suites del bridge (`GroupTransactionBridgeTests`, `A0BridgeIntegrationTests`) y del motor (`CloudSync*Tests`) son disjuntas: ningún test crea un gasto de grupo vía bridge y verifica la fila de outbox. Una regresión de integración (p.ej. bridge adoptando `outboxSaveAuthor`, sweep dejando de cubrir una entidad) no la detectaría nadie.

## Solución

Las 4 piezas de [[MODO-NUBE-GRUPOS-V1-DECISION]] §3, como incrementos independientes y commiteables por separado. Ninguna toca el motor de sync ni el flujo de migración.

## Acceptance criteria

- [ ] Usuario sin cuenta iCloud ve en el tab Grupos un estado explícito "Grupos necesita una cuenta de iCloud" + CTA a Ajustes (no spinner mudo). Usuarios con iCloud: cero cambio.
- [ ] Invite aceptado sin cuenta iCloud produce un error localizado ESPECÍFICO (no el genérico `groups.sync.errorAcceptShare`).
- [ ] Al boot con engine primario, si la identidad iCloud persistida difiere de la actual (fetch fresco exitoso), se ejecuta la misma limpieza que `.switchAccounts` + breadcrumb; un fetch fallido/transitorio JAMÁS dispara limpieza.
- [ ] Invite en sesión secundaria emite un error visible al usuario con copy propio.
- [ ] Existe un test que crea un gasto de grupo vía bridge, corre el drain, y asserta la fila de outbox con `split_expense_id`/`split_group_zone_id` poblados (contenido REAL, lección `d49d2e47`).
- [ ] XCUITests de Grupos (`GroupsSmokeUITests`, `DeeplinkRoutingUITests`) siguen verdes: el gate nuevo está exento en modo uitest (el sim no tiene iCloud).
- [ ] Keys l10n nuevas en los 16 locales completos (`add-l10n-key.sh` + `LocalizationParityTests`).
- [ ] `qa/coverage-index.json` actualizado en el mismo commit de cada pieza (regla QA anti-drift).

---

## Analisis tecnico

### Archivos involucrados

| Archivo | Cambio | Impacto |
|---------|--------|---------|
| `Yala/App/Logic/GroupsICloudAvailabilityGateLogic.swift` | Crear (pure-logic, patrón `GroupsBetaGateLogic`) | Bajo |
| `Yala/App/Views/Groups/GroupsICloudUnavailableView.swift` | Crear (estado + CTA a Ajustes) | Bajo |
| `Yala/App/ContentView.swift` (~:1588) | Modificar — gate en SERIE tras el beta gate en el contenido del tab Grupos | Medio |
| `Yala/Services/Groups/SplitSyncManager.swift` | Modificar — (a) catch de `acceptShare` :684-692 distingue `CKError.notAuthenticated`; (b) early-return :628-636 emite error visible; (c) boot-guard en `initialize()`; (d opcional) gate quiescencia :1490-1496 vía router | Alto |
| `Yala/App/Logic/GroupsIdentityBootGuardLogic.swift` | Crear (pure-logic: decisión cached-vs-current) | Bajo |
| `Yala/Services/Groups/GroupUserIdentityService.swift` | Modificar — `fetchFreshRecordName()` que NO lee el cache (el cache es justo lo que se compara) | Medio |
| `Yala/Resources/*/Localizable.strings` (16 locales) | Modificar vía `qa/scripts/add-l10n-key.sh` (~5 keys) | Bajo |
| `YalaTests/GroupBridgeCloudSyncIntegrationTests.swift` | Crear (e2e bridge→drain→outbox) | Bajo |
| `YalaTests/GroupsICloudAvailabilityGateLogicTests.swift` + `GroupsIdentityBootGuardLogicTests.swift` | Crear | Bajo |
| `qa/coverage-index.json` | Modificar (área groups + cloud-sync, `lastVerified`) | Bajo |

### Modelo de datos

Ninguno. Cero cambios SwiftData/CloudKit schema (sin deploy .ckdb).

### Dependencias

- **Señal iCloud:** `iCloudSyncService.shared.isAccountAvailable` (`iCloudSyncService.swift:104`). Ya existe override de test (`:572-579`) y el launch arg `-uitest-fake-icloud` (memoria `reference_uitest_fake_icloud`).
- **Routing de error:** `RouterEntryGate.shared.submit(.showGroupSyncError(String))` — el intent ya existe (`RouterIntent.swift:112`) y `groupSyncError` YA está en la matriz de readiness (fix routing 2/5, commit `7aab55a3+`). No hay que tocar `ShellReadinessState`.
- **Limpieza de identidad:** reusar el camino de `.switchAccounts` de `handleAccountChange` (respeta el gate export-only vía `deferredClearAllRequested` en `clearAllLocalGroupData`).
- **Sesión secundaria:** `SecondarySessionStore.isActive()` (M1) para el copy diferenciado de la pieza 3.
- **Test e2e:** moldes en `CloudSyncWiredEntitiesTests` (drain sobre contexto in-memory) + `GroupTransactionBridgeTests` (setup del bridge). `@Suite(.serialized)` + `makeTestContext()` per-file.

## Plan de implementacion

### Incrementos (orden de ejecucion — de menor a mayor superficie prod)

1. **Test e2e bridge→drain→outbox** — cero superficie prod; protege el hallazgo central de la decisión ANTES de tocar nada más.
   - Archivos: `YalaTests/GroupBridgeCloudSyncIntegrationTests.swift`, `qa/coverage-index.json`
   - Tests: crear `SplitGroup`+`SplitExpense` → `GroupTransactionBridge` materializa `TransactionItem` (Caso A real y Caso B draft) → drain del `CloudSyncEngine` → assertar fila de outbox con `split_expense_id`/`split_group_zone_id`/`split_total_amount` REALES (no solo count>0, lección `d49d2e47`). Variante negativa: write con `outboxSaveAuthor` NO aparece.

2. **Invite en secundaria: error visible** — solo se activa con el flag M1 (hoy DARK); riesgo prod cero.
   - Archivos: `SplitSyncManager.swift` (early-return :628-636 → además de `noteAcceptFailed`, `RouterEntryGate.shared.submit(.showGroupSyncError(...))` con key nueva si `SecondarySessionStore.isActive()`, genérica si `container == nil` por otra razón), keys `groups.sync.errorAcceptShareSecondary` (+ genérica existente) × 16 locales.
   - Tests: pure-logic de selección de key (secundaria vs container-nil genérico); verificación sim vía panel DEBUG M1 (descriptor FAKE + intento de invite).

3. **`GroupsICloudAvailabilityGate` + copys** — prod-visible solo para usuarios SIN iCloud (hoy raros; imprescindible antes de encender flags de Modo Nube).
   - Archivos: `GroupsICloudAvailabilityGateLogic.swift` (nuevo: `shouldShowGate(isAccountAvailable:isUITest:)` — exento en uitest, el sim no tiene iCloud y `GroupsSmokeUITests` moriría), `GroupsICloudUnavailableView.swift` (nuevo: `YalaEmptyState`-style + CTA `UIApplication.openSettingsURLString`, `.yalaScreenBackground`, a11y ids), `ContentView.swift:1588` (en serie: beta gate PRIMERO, luego availability), catch de `acceptShare` :684-692 (rama `CKError.notAuthenticated` → key específica), ~3 keys × 16 locales.
   - Tests: tabla de la logic (4 combos); XCUITest existente de Grupos sigue verde (exención uitest); `LocalizationParityTests`.

4. **Boot-guard GAP 1** — prod-visible para cualquier usuario que cambie de Apple ID (fix de bug latente; el más delicado por ser limpieza destructiva de cache local).
   - Archivos: `GroupsIdentityBootGuardLogic.swift` (nuevo: `decide(cached: String?, fresh: Result<String, Error>) -> Action` con `.none`/`.runSwitchCleanup` — SOLO limpia con DOS valores válidos distintos; error/nil/cached-nil JAMÁS limpian), `GroupUserIdentityService.swift` (`fetchFreshRecordName()` bypass del cache), `SplitSyncManager.swift` (`initialize()`: Task post-arranque que compara y, en mismatch, ejecuta el mismo camino de `.switchAccounts` + breadcrumb/telemetry `groupsIdentityBootMismatch`).
   - Tests: tabla exhaustiva de la logic (match/mismatch/cached-nil/fetch-error/fresh-empty); el cleanup reusa código ya probado. Verificación real solo en device físico (cambio de Apple ID no reproducible en sim) → añadir fase al guion device pendiente.

5. **(Opcional, mismo incremento 4 o aparte) Gate de quiescencia del bridge remoto vía router** — corregir el "accidente afortunado": `SplitSyncManager.swift:1490-1496` consulta `iCloudSyncService.status` hardcodeado; enrutar por `StorageModeSignalRouter.quiescenceSource(mode:)`. Solo si el diff resulta pequeño y no arrastra refactor — si crece, diferirlo con nota en DIFERIDOS.

### Riesgos

- **El gate sin-iCloud rompe XCUITests/QA en sim** (el sim no tiene cuenta iCloud; hoy Grupos funciona local en sim — memoria `reference_groups_sim_qa_constraints`). Mitigación: exención uitest en la logic (input explícito `isUITest`, cableado a `UITestHooks`) + `-uitest-fake-icloud` para los flujos que quieran probar el estado CON iCloud. El gate NO debe impedir el uso local de Grupos en device-qa de sim: revisar que solo gatea la UI, no `GroupService`.
- **Boot-guard con falso positivo → borra cache de grupos legítimo.** Mitigación: regla "dos valores válidos distintos" en la pure-logic (fetch fallido/transitorio = `.none`), y la limpieza es de CACHE local re-fetcheable (los datos viven en CloudKit) — pero aún así, breadcrumb + telemetría para detectar disparos inesperados en prod.
- **Boot-guard vs export-only window:** `clearAllLocalGroupData` ya difiere el save si el import personal no asentó (`deferredClearAllRequested`) — reusar ese camino tal cual, no duplicarlo.
- **Copy del CTA a Ajustes:** iOS no permite deep-link directo a la pantalla de iCloud; `openSettingsURLString` abre los ajustes de la APP. El copy debe decir "Ajustes → [tu nombre] → iCloud", no prometer navegación directa.
- **Pieza 3 toca `ContentView.swift`** (archivo caliente del fix de routing): cambio mínimo en serie, sin tocar readiness ni presentaciones.

### Estimacion

- Incrementos: 4 (+1 opcional)
- Complejidad: media (baja por pieza; la coordinación con uitest/sim y el boot-guard concentran el cuidado)
- Sin deploy CloudKit, sin cambios de schema, sin migraciones.

---

## Implementación

### 2026-07-13 — 5 commits en branch 2.0.5 (81b0a894 → commit 5)

**Resumen:** las 4 piezas + la opcional, implementadas en orden de menor a mayor superficie prod, cada una con gates (build ambas schemes + tests + validate-coverage) y commit atómico.

| # | Commit | Pieza |
|---|--------|-------|
| 1/5 | `81b0a894` | Test e2e bridge→drain→outbox (`GroupBridgeCloudSyncIntegrationTests`, Caso A/B, columnas `split_*` con contenido real; cardinalidad verificada empíricamente a la primera: Caso A = 2 TX + 1 draft) + doc-fix comentario stale `personalEntityNames` |
| 2/5 | `b3329db0` | `GroupAcceptShareErrorLogic` + acceptShare: SOLO secundaria alerta (container-nil transitorio sigue silencioso por diseño — retry de PendingInviteStore) + `.notAuthenticated` → copy "necesitas iCloud". 2 keys × 16 locales (voseo es-AR) |
| 3/5 | `93512d59` | `GroupsICloudAvailabilityGateLogic` + `GroupsICloudUnavailableView` + wiring en serie tras beta gate + arg DEBUG standalone `-fake-icloud` (YalaApp.init — BUG cazado en verificación sim: en `applyUITestHooksEarly` jamás corría sin `-uitest`). 3 keys × 16. Verificación sim 3 estados VERDE |
| 4/5 | `46a270d9` | Boot-guard GAP 1: `fetchFreshRecordName()` (bypass cache) + `GroupsIdentityBootGuardLogic` (solo limpia con 2 valores válidos distintos) + `performAccountSwitchCleanup()` extraído y reusado + canario `groupsIdentityBootMismatch` |
| 5/5 | (ver git log) | Gate de quiescencia del bridge remoto enrutado por `StorageModeSignalRouter` (`.cloud` → `SyncQuiescenceCoordinator`; `.icloud` byte-idéntico) |

**Decisiones técnicas clave:**
- Test e2e con container ON-DISK (History no fiable in-memory) + `bridgeExpense(shouldSave: false)` — los side-effects de `saveIfNeeded` eran la causa de la blacklist R8.
- Container-nil no-secundaria NO alerta (ajuste del /review-plan): ventana transitoria con retry — alertar sería espurio.
- Reactividad del gate: `isAccountAvailable` es computed → se lee `syncService.status` (stored) en el branch para registrar la dependencia @Observable.
- Boot-guard jamás limpia sin evidencia (fetch fallido = skip + reintento próximo boot).

**Pendiente device QA (fases añadidas al guion M1):** ver sección QA abajo.

## QA device (pendiente owner)

Añadidas al guion `MODO-NUBE-M1-GUION-DEVICE.md` (§ Endurecimiento Grupos-v1):
1. **Invite en secundaria:** con descriptor secundario activo, abrir un enlace de invitación → debe aparecer el alert "Las invitaciones a grupos se aceptan desde la sesión principal…" (antes: nada).
2. **Boot-guard GAP 1 (device físico only):** con grupos poblados, cerrar la app → cambiar el Apple ID del OS → abrir la app → los grupos locales se limpian y re-fetchean bajo la identidad nueva; verificar canario `groupsIdentityBootMismatch` en TelemetryDeck.
3. **Gate sin iCloud (device sin cuenta):** tab Grupos muestra "Grupos necesita iCloud" + CTA abre Configuración (verificado en sim; confirmar en device).

## 2026-08-17 — re-medición contra 2.0.5

Árbol: `jur211296/Yala` rama `2.0.5`, HEAD `012cabe0`. **No se ejecutó QA hoy.** `status` / `qa-status` siguen **parked** (decisión owner 2026-07-14). **No rename.**

**Piezas CK — D / 404 (no ejecutar el guion CloudKit):**

| Pieza | Premisa | Evidencia |
|---|---|---|
| 3/5 muro iCloud | `GroupsICloudUnavailableView` + gate en el tab | ambos ficheros **404**. `ContentView` (tab Grupos) monta `GroupsContainerView()` y declara el muro retirado. Supercedido por `965a4d86`. |
| 4/5 boot-guard Apple ID | `GroupsIdentityBootGuardLogic` | fichero **404**. |
| 2/5 acceptShare en secundaria | alerta CK `notAuthenticated` / container-nil | `GroupAcceptShareErrorLogic` **404**; `SplitSyncManager` **404**. |
| 5/5 quiescencia vía router en el motor CK | hook en `SplitSyncManager` | el motor **404**. El tipo `StorageModeSignalRouter.quiescenceSource` **sí** vive en `Yala/Services/CloudSync/StorageModeSignalRouter.swift` (modo personal, no el acceptShare de Grupos). |

**Residual que NO es D:** `YalaTests/CloudSync/GroupBridgeCloudSyncIntegrationTests.swift` existe (pieza 1/5; no es QA de pantalla).

**REMAINS (parked, no urgente):** decisión owner 2026-07-14 — Grupos migra al backend en v1; no reabrir el paquete CK. Si se reabre algo, el leftover real sería invite **backend** en sesión secundaria (C: sesión real + enlace), no el alert `errorAcceptShare` de CloudKit.

Joan revisa el nombre. No tratar el parked como «cerrado por QA».

migrated from YalaWiki Backlog/qa_groups-endurecimiento-modo-nube-v1.md @ 1934e8ad
