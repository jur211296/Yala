---
created: 2026-07-29
updated: 2026-07-29
tags: [modo-nube, grupos, fase3, brief]
status: blocked
---

# Fase 3 — brief, con las coordenadas medidas y el bloqueo que el plan no nombra

Medición del 2026-07-29 contra HEAD `ca06cfd5`, con 8 agentes en paralelo (6 midiendo por bloque, 2
refutando). Detalle completo en `docs/modo-nube/fase3-medicion/*.md` — 2.465 líneas de informe.
El plan ([[MODO-NUBE-PLAN-SIMPLIFICACION-GRUPOS]] §3, Fase 3) marcaba sus cifras como NO VERIFICADAS.

---

## 🔴 BLOQUEO · La Fase 3 no se puede ejecutar todavía

`CloudSyncFlags.swift:266` → `private static let groupsBackendCompiledDefault = false`, y
`groupsBackendEnabled` compone `compilado && remoto`, así que el remoto **solo puede matar**.

⇒ **en todo build de producción de hoy el canal backend está APAGADO y el transporte CloudKit es el
ÚNICO canal vivo de Grupos.** Borrarlo deja la app sin ninguna vía de sync de grupos.

**El plan no nombra este flag ni una vez** — ni como prerrequisito ni como parte del changeset. Y su
criterio de hecho pide «QA en simulador del recorrido entero por el canal backend», que con el flag OFF
no se puede ejercitar: se estaría borrando el único canal que funciona sin haber probado el que queda.

Esto no es una objeción de alcance. Convierte tres hallazgos de hipotéticos en **fallos de producción**,
porque cada resolvedor de identidad de Grupos tiene la forma `groupsBackendEnabled ? <backend> : nil` y
con el flag OFF la única identidad viva es la CloudKit-era que la Fase 3 borra:

| Resolvedor | Coordenada |
|---|---|
| `GroupSettingsView.hasOutstandingBalance` | `GroupSettingsView.swift:706` |
| `GroupJoinReconciler.currentUserMemberExists` | `GroupJoinReconciler.swift:296` |
| `GroupService.refreshCurrentUserFlags` | `GroupService.swift:1010` |

**Decisión de entrada, y es de release, no de refactor:** o el flip compilado a `true` entra en el mismo
lote —y entonces la Fase 3 **es el encendido del canal nuevo**, no limpieza— o los borrados se paran en
la frontera de la Fase 2. No hay tercera opción que deje la app funcionando.

⇒ **Prerrequisito real: bloqueante #4** (las 2 líneas de `CloudBackendConfig`) **+ el flip del
compilado**, como su propio lote, ANTES de cualquier borrado.

---

## Los números medidos (y cuánto se desvían del plan)

| Bloque | Plan | Medido | Nota |
|---|---|---|---|
| Ficheros «enteros» (13) | 4.892 | **4.498** | −384 son solo `SplitSyncManager`: **2.521**, no 2.905 |
| Recortes en ficheros vivos | no cuantificado | **~460** (139 exactas, ~321 estimadas) | `GroupService` 1.534 → ~1.075 |
| Tests | «10 ficheros, ~2.042» | **1.855 en 15 ficheros** | 9 mueren enteros (1.504) + 6 con recorte (351) |
| Canarios y breadcrumbs | no cuantificado | **~74** | `MetricsService` 451→~433 · `GroupsSyncBreadcrumb` 213→~157 |
| **Total** | ~6.934 | **~5.974** | |

**6 de 13 rutas del plan están mal**: apuntan a `Yala/Services/CloudSync/` cuando el transporte vive en
`Yala/Services/Groups/`. Y `Services/CloudSync/Groups/` **sí existe**, con 14 ficheros de nombre casi
idéntico ⇒ es una trampa activa, no un typo.

**Las 5 coordenadas de `propagateBoolCustomKey` están mal, incluidas 3 marcadas ✅ en el plan**: la
función está en `:246` (no `:236`) y los callsites en `GroupService:238`/`:318` y
`SplitSyncManager:2033`/`:2039`. Y no son 4 recortes sino **2**: los de `SplitSyncManager` viven en
`handleConflict` y se van con el fichero.

---

## 3 de los 13 «ficheros enteros» NO son borrados de fichero entero

| Fichero | Qué esconde | Si se borra entero |
|---|---|---|
| `Yala/App/Logic/SplitSyncStartGate.swift` (292) | `BootSaveGateLogic` (`:198-292`) + `WaitResolution` (`:61`) + `resolveWaitByQuiescence` (`:97-108`) — el gate de los `save()` del store **PERSONAL**, usado por `AppBootstrapper.swift:881` | **reintroduce el crash-loop SIGTRAP del restore de iCloud** (H-2026-07-18-8) sin un solo test rojo: los 9 tests que lo pinnean viven en `SplitSyncStartGateTests.swift`, que el mismo commit borra |
| `Yala/Services/Groups/GroupUserIdentityService.swift` (88) | `deterministicUUID` (`:75-87`), usado por `GroupBackendIdentityLogic.swift:38` y `GroupsSyncClient.swift:1901` — **el 63 % del fichero sobrevive** | rompe la derivación de ids del canal backend |
| `CKConstants` (en `CloudKitConstants.swift`) | `zonePrefix`, usado en el `init` de `SplitGroup.swift:102` para construir `cloudKitZoneID` | **`cloudKitZoneID` ES el `group_id` server-side del canal backend** ⇒ se rompe la identidad de los grupos en el backend |

---

## Los 6 apagones silenciosos — ninguno lo caza el compilador

Cuatro son **nuevos**: no están en el plan.

| # | Qué se apaga | Coordenada raíz |
|---|---|---|
| S1 | ~20 routers `flag ? backend : transporte` se quedan eligiendo una rama que ya no existe | `CloudSyncFlags.swift:266` |
| **S2** | `movedToBackendAt` pierde su ÚNICO escritor ⇒ el freeze del miembro y el CTA «vuelve a entrar» **nunca se activan** | `CKRecordTranslator.swift:127`, `:151` |
| **S3** | Muere el desatasco de «esperando aprobación» y el trigger `.remoteInsert` del reconciler — sin espejo backend | `SplitSyncManager.swift:1758-1769` |
| **S4** | «Me sacaron del grupo» deja de detectarse en vivo; queda solo la red del cold boot | `SplitSyncManager.swift:2293-2298` → `:1697-1715` |
| S5 | Pull-to-refresh, «invitar» y «crear grupo» pasan a **no-op con spinner** | `GroupsViewModel:202` · `GroupDetailViewModel:435` · `GroupMembersView:455` |
| **S6** | `SoftDeleteObserverLogic.swift` (31) queda huérfano total — **no está en ninguna lista del plan** | su único consumidor de producción es `SplitSyncManager` |

### Y el peor de todos, que no es un apagón sino un colapso

**`cachedRecordName` se queda sin escritor.** Su único escritor en todo el repo es el
`UserDefaults.set` de `GroupUserIdentityService.swift:41`, **dentro del `currentUserRecordName()` que el
plan borra**. En instalación fresca queda `nil` para siempre ⇒ mueren en silencio los 4 fallbacks vivos
del canal backend (`GroupBackendInviteEntryHandler:127`, `GroupExpenseService:614`,
`GroupSettingsView:704`, `GroupJoinReconciler:293`).

**Y los tests lo TAPAN**: las 3 suites que los prueban inyectan la identidad con
`_testSetCachedRecordName`, así que compila, pasa y falla solo en un device real. «Conservar
`cachedRecordName`», como dice el plan, es insuficiente: hay que conservar **quién lo escribe**.

---

## Otros dos que exigen decisión, no ejecución

- **Borrar `GroupsIdentityPurgeGate` se lleva `.deleteLocalRows`** (`:201-252`), la mitad que BORRA ⇒
  tras la Fase 3 no queda purga automática ante cambio de Apple ID: regresión de `31dded30` para las
  filas CloudKit-era.
- **`isInviteLink` (`InviteLinkService:1637`) es el guard verdadero**, no el `:1733` que dice el plan; y
  si se conserva la condición `groupsBackendEnabled` de `:1705`, con el flag OFF `handleInviteLink` queda
  **mudo**.

---

## Partición correcta: TRES commits, no dos

El ciclo duro `SplitSyncManager` ↔ `SplitZoneManager` y las ~30 llamadas a `enqueueSave`/`enqueueDeletion`
en 3 ficheros supervivientes **prohíben subdividir el commit de producción**.

**Commit 0 — movimientos (aislado, sin riesgo, se puede hacer YA y no depende del flag).**
Mover `BootSaveGateLogic` + `WaitResolution` + `resolveWaitByQuiescence` a fichero propio y su suite a
`YalaTests/BootSaveGateLogicTests.swift`; mover `zonePrefix` (con su literal) fuera de
`CloudKitConstants.swift`. Compila y pasa tests por sí solo, y saca 2 acoplamientos del commit grande sin
abrir ninguna ventana de riesgo.

**Commit 1 — producción, atómico e indivisible.** Los 13 ficheros ya vaciados de lo movido + los trims de
`GroupService`, `GroupExpenseService`, `GroupJoinReconciler`, `GroupJoinReconcileLogic`,
`AppBootstrapper`, `ContentView`, `AppRouter`, `YalaAppDelegate`, `GroupDetailViewModel`,
`GroupMembersView`, `GroupSettingsView`, `GroupsViewModel`, `GroupJoinIntentTracker`, `iCloudSyncService`,
`InviteLinkService`, `RouterIntent`, `SplitGroup` y **`DataWipeService`**.

**Commit 2 — tests y coverage.** Los 8 ficheros de test del transporte (1.681 menos las ~130 movidas en
el commit 0) + **`CloudKitGroupsSchemaParityTests.swift` (157), adelantado de la Fase 4** porque lee
`CloudKitConstants.swift` por RUTA y el fichero muere aquí + las **5 áreas** de `qa/coverage-index.json`
+ `_meta.counts`.

### Trampas del índice de cobertura

- La Fase 1 **no** redujo el área del transporte: redujo `groups-backend-g6-migration` (26→8 globs).
  `groups-cross-device-sync` (JSON `833-880`, `manual`) sigue con **17 globs**, 8 de los cuales
  sobreviven.
- **`groups-icloud-availability-gate` (JSON `965-976`) pierde sus 2 únicos globs, y `codeGlobs` vacío es
  error DURO** (`validate-coverage.py:61`) ⇒ hay que **borrar el área** y bajar `_meta.counts` a
  `total 133 / manual 57`. Los globs sin match son solo WARN, y **`counts` no lo valida nadie**.
- El índice cita `unit:YalaTests/BootSaveGateLogicTests`. Esa suite **existe** —es el nombre del tipo en
  `SplitSyncStartGateTests.swift:271`— pero el commit 2 borra el fichero que la esconde. El commit 0 la
  saca a un fichero propio y la cita pasa a ser literal.
- El criterio de salida `grep -r "import CloudKit"` del plan **no escanea `App/Logic/`**, donde
  sobreviven `GroupJoinReconcileLogic.swift:15` y `GroupAcceptShareErrorLogic.swift:23` — ninguno en las
  listas del plan.

---

## Dos cosas ya muertas hoy (limpieza gratis, sin relación con la Fase 3)

- `GroupUserIdentityService.swift:70-73` — `deterministicMemberID(groupZoneID:)`, **0 callsites**.
- `MetricsService.swift:37` — `cloudkitBudgetCSVMirrorRebuilt`, **0 emisores** en todo el repo.
