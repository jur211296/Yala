---
created: 2026-07-29
updated: 2026-07-30
tags: [modo-nube, grupos, fase3, brief]
status: blocked  # commit 0 HECHO (bc486c92) + Fase 2 bis del escritor de identidad (40a4e417); los commits 1 y 2 siguen bloqueados por el flag
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
| Ficheros «enteros» (13) | 4.892 | **4.498** → **4.355** tras `bc486c92` | −384 son solo `SplitSyncManager`: **2.521**, no 2.905. El commit 0 se llevó 143 de `SplitSyncStartGate` (292→149) |
| Recortes en ficheros vivos | no cuantificado | **~460** (139 exactas, ~321 estimadas) | `GroupService` 1.534 → ~1.075 |
| Tests | «10 ficheros, ~2.042» | **1.855 en 15 ficheros** → **1.723** tras `bc486c92` | 9 mueren enteros (1.504) + 6 con recorte (351). El commit 0 sacó 132 de `SplitSyncStartGateTests` (395→263) |
| Canarios y breadcrumbs | no cuantificado | **~74** | `MetricsService` 451→~433 · `GroupsSyncBreadcrumb` 213→~157 |
| **Total** | ~6.934 | **~5.974** → **~5.699** tras `bc486c92` | |

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
| ~~`Yala/App/Logic/SplitSyncStartGate.swift` (292)~~ → **149, RESUELTO en `bc486c92`** | ~~`BootSaveGateLogic` (`:198-292`) + `WaitResolution` (`:61`) + `resolveWaitByQuiescence` (`:97-108`)~~ — ya viven en `BootSaveGateLogic.swift` | ~~reintroduce el crash-loop SIGTRAP del restore de iCloud~~ (H-2026-07-18-8) — el commit 1 ya puede borrar el fichero entero |
| `Yala/Services/Groups/GroupUserIdentityService.swift` (~~88~~ → **85 tras `40a4e417`**) | `deterministicUUID` (`:74-84`), usado por `GroupBackendIdentityLogic.swift:38` y `GroupsSyncClient.swift:1901`, **+ el cache `cachedRecordName` (`:24-28`, `:40-47`)** — el ESCRITOR ya salió a `Services/CloudSync/Groups/` (Fase 2 bis) | rompe la derivación de ids del canal backend **y** deja el cache sin dueño |
| ~~`CKConstants` (en `CloudKitConstants.swift`)~~ → **RESUELTO en `bc486c92`** | ~~`zonePrefix`~~ (+ `zoneName(for:)`) ya vive en `SplitGroupZone` (`Yala/Models/`); el `init` de `SplitGroup.swift:102` apunta ahí | ~~se rompe la identidad de los grupos en el backend~~ — literal `"SplitGroup-"` conservado byte a byte |

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

### Y el peor de todos, que no es un apagón sino un colapso — ✅ RESUELTO (Fase 2 bis, `40a4e417`)

**`cachedRecordName` se queda sin escritor.** Su único escritor en todo el repo es el
`UserDefaults.set` de `GroupUserIdentityService.swift:41`, **dentro del `currentUserRecordName()` que el
plan borra**. En instalación fresca queda `nil` para siempre ⇒ mueren en silencio sus consumidores vivos,
que son **CINCO, no cuatro** (verificado con `grep -rn "shared.cachedRecordName" Yala/`; los dos de
`SplitSyncManager` —`:265` y `:1649`— no cuentan porque mueren con el fichero):

| Consumidor | Coordenada |
|---|---|
| `GroupService.refreshCurrentUserFlags` | `GroupService.swift:1019` |
| `GroupExpenseService.currentUserMemberID` | `GroupExpenseService.swift:614` |
| `GroupJoinReconciler.currentUserMemberExists` | `GroupJoinReconciler.swift:293` |
| `GroupSettingsView.hasOutstandingBalance` | `GroupSettingsView.swift:704` |
| `GroupBackendInviteEntryHandler.legacyMemberKeyForRejoin` | `GroupBackendInviteEntryHandler.swift:127` |

**Y los tests lo TAPAN**: las 3 suites que los prueban inyectan la identidad con
`_testSetCachedRecordName`, así que compila, pasa y falla solo en un device real. «Conservar
`cachedRecordName`», como dice el plan, es insuficiente: hay que conservar **quién lo escribe**.

#### La decisión, medida: se conserva el escritor (opción 1). Las otras dos se descartaron con datos

**Lo elegido.** El escritor —key, fetch y persistencia— se muda a
`Yala/Services/CloudSync/Groups/GroupICloudIdentitySeed.swift`: donde vive el canal nuevo y donde el
criterio de salida de la Fase 3 (`grep -r "import CloudKit" Yala/Services/Groups/ Yala/App/Views/Groups/`
→ 0) **no mira**. Solo necesita `CKContainer(identifier:).userRecordID()` y
`SwiftDataConfiguration.groupsCloudKitContainerIdentifier`, no `CKConstants` ⇒ no arrastra transporte. El
seed de boot de `AppBootstrapper` entra por ahí y `currentUserRecordName()` queda como fachada que delega,
así que **el commit 1 puede borrar el método sin dejar la identidad sin escritor**.
`GroupUserIdentityService` conserva el cache (`cachedRecordName`) y `deterministicUUID`.

**Opción 2 (derivarlo del canal backend) — DESCARTADA, y es la que parecía mejor.** No se sostiene, por
una circularidad del servidor: `migrate_group` sube los members no-owner como **placeholders `user_id
NULL`** (`qa/cloud/g6_01_migrate_group.sql:158`) y su reclamación **solo** ocurre vía
`join_group(token, p_legacy_member_key)`, que es quien estampa `user_id = v_uid`
(`g7_02_encrypt_groups_cutover.sql:223-241`). La RLS entrega el grupo únicamente a quien ya está
reclamado por `user_id` ⇒ **el `member_key` legacy no puede BAJAR antes del rebind que lo necesita**. Y el
server no puede decírnoslo por otra vía: no conoce el recordName de iCloud del usuario hasta que el
device se lo manda. `isLegacyMemberKey` sirve para elegir el namespace del id local, no para reconocer al
usuario sin identidad previa.

**Opción 3 (aceptar el nil) — DESCARTADA, pero se midió y 4 de los 5 no pierden nada.** En una
instalación fresca el fallback iCloud es **estructuralmente inerte** en los cuatro primeros: comparan
`cloudKitUserRecordID == cachedRecordName`, y toda fila born-remote tiene `cloudKitUserRecordID == ""` por
diseño (`GroupsSyncClient.applyMember` lo dice explícito). Ahí quien resuelve es el `sub`
(`refreshCurrentUserFlags` sigue viva por `backendCanResolve`, y `selectCurrentUserMemberID` tiene el
fallback backend ANTES del de iCloud). **El que sí pierde es el quinto**, y lo que pierde es dinero
atribuido: sin `legacyMemberKey` el re-join de un grupo migrado entra como member NUEVO y el historial
CloudKit-era del usuario queda colgando de una fila fantasma. Hoy eso es el residual §9.3b —acotado a
otro Apple ID o a un device sin iCloud— y **tras la Fase 3 pasaría a ser el caso general**. Un residual
que se convierte en el caso normal no es un residual.

**Fecha de caducidad, anotada:** el commit 2 de la Fase 4 retira el entitlement del container de Grupos ⇒
desde ahí el fetch falla siempre y el rebind legacy muere con él, esta vez por decisión de release y no
por un descuido. Las filas placeholder seguirán en el servidor: si hay que hacer algo con ellas, se decide
allí.

**El test tuvo que ser ESTRUCTURAL, y esa es la lección de método.** Rojo antes (exit 65) y verde después
(exit 0), en `YalaTests/GroupICloudIdentitySeedTests.swift` (7 celdas). Las dos rojas miden *dónde vive el
escritor* y *si el seed de boot depende del símbolo que muere*. No hay test de COMPORTAMIENTO que pueda
estar rojo antes del fix: el estado post-Fase 3 es «cache nil **y** identidad de iCloud disponible», y
reproducirlo exige un fetcher inyectable que el fix es quien introduce — inyectar el cache reproduce el
bug tapado, que es exactamente lo que hacen las 3 suites que no lo cazaron. Las otras cinco celdas sí son
de comportamiento y ejercitan la instalación fresca con el cache **vacío** y el **fetcher** inyectado.

⇒ **El hueco declarado en el docblock de `GroupServiceCurrentUserFlagsTests` sigue abierto y no lo cierra
esta pieza**: ese hueco es «el 3er guard exige que el fetch a CKContainer falle», y el fetcher inyectable
vive ahora en el seam, no en el camino que `refreshCurrentUserFlags` recorre (lee el cache o llama a la
fachada). Cerrarlo pide inyectar el proveedor de identidad *en `GroupService`*, que es re-cableo de otro
consumidor. Docblock no tocado a propósito.

#### ¿Comparten mecanismo los otros cinco apagones? Solo en la firma, no en la causa

Medido antes de escribirlo, porque el molde «mueve el escritor» invita a aplicarse a todo:

- **S2 (`movedToBackendAt`) — NO.** Sus dos únicos escritores (`CKRecordTranslator.swift:127`, `:151`)
  hacen `group.movedToBackendAt = record[F.movedToBackendAt] as? Date`: **leen de un `CKRecord`**. El dato
  no está en el device esperando a que alguien lo escriba — llega por CloudKit. Post-Fase 3 no llega de
  ningún sitio, así que mover el escritor no arregla nada: el marcador tiene que viajar por el canal
  backend o el freeze no existe. Es un apagón de **FUENTE**.
- **S3 y S4** — igual que S2: lo que muere es el **evento** (el fetch de CloudKit que desatasca «esperando
  aprobación» / detecta «me sacaron»). Se resuelven espejando el trigger en el pull del canal nuevo, no
  moviendo código.
- **S6 (`SoftDeleteObserverLogic`)** — el inverso: un **consumidor huérfano**, no un escritor perdido. O
  se re-cablea a un emisor del canal nuevo o se borra; mover no aplica.

⇒ **Esta pieza es la única de las seis cuyo problema era de ESCRITOR** (el dato ya vive en el device y
solo faltaba quién lo persistiera). Lo que sí es transferible a las otras cuatro es el **método**: la
firma «compila, pasa en verde, falla en device» viene de suites que inyectan el estado que el apagón
destruye, y contra eso el test que sirve es el que pinnea el **cableado**, no el comportamiento.

#### Dos huérfanos nuevos que la Fase 3 crea aquí, y quedan REPORTADOS (fuera de ámbito)

- **`clearCache()` pierde su único caller** (`SplitSyncManager.swift:1466`) ⇒ tras la Fase 3 nadie puede
  olvidar la identidad de un Apple ID que se fue: la key se queda congelada con el recordName anterior.
  Va de la mano de que el boot-guard entero (`GroupsIdentityBootGuardLogic`) también muere, así que el
  cambio de Apple ID deja de detectarse — decidir junto, no por separado.
- **`fetchFreshRecordName()` queda sin callers** (su único uso es `SplitSyncManager.swift:270`, el
  boot-guard) ⇒ borrable con él.
- Y uno que no es de la Fase 3 sino de **2.6**: `legacyMemberKeyForRejoin` es el **sexto resolvedor de
  identidad** y no recibió el re-cableo de 2.6 — resuelve por `isCurrentUser == true` crudo, sin el
  fallback por `sub`. Como `isCurrentUser` es device-local y **no viaja en el CKRecord**
  (`CloudKitConstants.swift:90`), en un 2º device la fila legacy llega con el flag apagado y su
  `cloudKitUserRecordID` poblado: la llave está en esa misma fila y la función no la ve. Hoy lo tapa el
  cache (que el fix mantiene vivo); el molde correcto es `GroupExpenseService.selectCurrentUserMemberID`.

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

**Commit 0 — movimientos. ✅ HECHO: `bc486c92` (2026-07-29).**
`BootSaveGateLogic` + `WaitResolution` + `resolveWaitByQuiescence` → `Yala/App/Logic/BootSaveGateLogic.swift`
(169); su suite (9 celdas) → `YalaTests/BootSaveGateLogicTests.swift` (147); `zonePrefix` + `zoneName(for:)`
→ `enum SplitGroupZone` en `Yala/Models/SplitGroupZone.swift` (32), con el literal `"SplitGroup-"` intacto.
Build `Yala` + `Yala Dev` verdes sin warnings nuevos; **5.221 tests / 483 suites en verde**;
`validate-coverage.sh` → `RESULT: OK`. Cero cambios de comportamiento.

**Lo que cambió respecto a lo que decía este brief, medido al ejecutarlo:**

- **`SplitSyncStartGate.swift` adelgaza 292 → 149, no 292 → ~197.** Salen las tres piezas juntas (147
  líneas), porque `WaitResolution` y `resolveWaitByQuiescence` se llevan sus docblocks completos. El commit 1
  borra 149, no 292 ⇒ **el total de «ficheros enteros» baja de 4.498 a 4.355**.
- **`resolveWaitByQuiescence` tenía DOS callers de producción, no uno.** Además de `BootSaveGateLogic.decide`
  lo llama `SplitSyncManager.evaluateQuiescentPromotion` (`:630`), que muere en la Fase 3. Como el dueño
  tiene que ser el que sobrevive, la función quedó **dentro de `BootSaveGateLogic`** y ese callsite ahora
  dice `BootSaveGateLogic.resolveWaitByQuiescence` — se va con el fichero, sin trabajo extra para el commit 1.
- **`zoneName(for:)` SÍ tiene caller superviviente, pero es un TEST**, no producción:
  `GroupsIdentityPurgeGateTests` lo usa como control negativo de la derivación (`zona real ≠ derivada`).
  Se movió con `zonePrefix`. El **parser inverso `groupID(from:)` tiene 0 callers supervivientes** (todos en
  `SplitZoneManager`/`SplitSyncManager` y sus tests) ⇒ **se queda en `CKConstants`**, igual que
  `zoneID(for:)`, los dos apuntando ya al nuevo dueño. `CloudKitConstants.swift`: 150 → 149.
- **`CloudKitGroupsSchemaParityTests` NO se rompe con el movimiento.** Lee el fichero por ruta pero parsea
  solo los 5 enums de campos, y `zonePrefix` nunca fue uno de ellos. Lo único que quedó obsoleto es el
  comentario de `:74`, que usaba `zonePrefix` como ejemplo del fallo de parseo; corregido a una formulación
  genérica. El adelanto de este test al commit 2 sigue en pie: el fichero que lee muere ahí.
- ⚠️ **DEUDA para el commit 2, nueva. Y son 9 celdas, no 8** (verificado en la otra Mac el 2026-07-29):
  a las ocho `resolveByQuiescence_*` hay que sumar **`mirrorNotConfirmedOff_matrixUnchanged`**, cuyo nombre
  habla de la matriz del mirror pero que ejercita la función igual. Quien mueva «las 8» dejará ese caso
  atrás. En el fichero nuevo la función solo tiene HOY **una** llamada indirecta
  (`BootSaveGateLogicTests.swift:141`, comparando el gate de grupos contra el de boot-save), así que sin el
  rescate se queda prácticamente sin cobertura propia. Las **8 celdas de `resolveWaitByQuiescence`** más esa
  novena se quedaron en
  `SplitSyncStartGateTests.swift`, que el commit 2 borra, **aunque cubren código que sobrevive** (la función
  vive ahora en `BootSaveGateLogic`). Fuera del alcance del commit 0 —que movía la suite nombrada, no esa—
  pero si el commit 2 borra el fichero sin moverlas, `resolveWaitByQuiescence` se queda sin un solo test.
  Muévelas a `BootSaveGateLogicTests.swift`. El fichero mide hoy 263 líneas (395 − 132 del commit 0).
- **Índice de cobertura:** `Yala/Models/SplitGroupZone.swift` entra en `groups-cross-device-sync` (18 globs)
  y `Yala/App/Logic/BootSaveGateLogic.swift` en **`icloud-sync-multi-device`** (7 globs) — el gate de
  boot-saves pertenece al área que sobrevive, no a la del transporte. Los dos `lastVerified` a `2026-07-29`
  por drift de glob, no por re-verificación de sync.

**Commit 1 — producción, atómico e indivisible.** Los 13 ficheros ya vaciados de lo movido + los trims de
`GroupService`, `GroupExpenseService`, `GroupJoinReconciler`, `GroupJoinReconcileLogic`,
`AppBootstrapper`, `ContentView`, `AppRouter`, `YalaAppDelegate`, `GroupDetailViewModel`,
`GroupMembersView`, `GroupSettingsView`, `GroupsViewModel`, `GroupJoinIntentTracker`, `iCloudSyncService`,
`InviteLinkService`, `RouterIntent`, `SplitGroup` y **`DataWipeService`**.

**Commit 2 — tests y coverage.** Los 8 ficheros de test del transporte (1.681 menos las **132** movidas en
el commit 0) **+ las 8 celdas de `resolveWaitByQuiescence` que hay que RESCATAR de
`SplitSyncStartGateTests.swift` antes de borrarlo** (ver la deuda del commit 0) + **`CloudKitGroupsSchemaParityTests.swift` (157), adelantado de la Fase 4** porque lee
`CloudKitConstants.swift` por RUTA y el fichero muere aquí + las **5 áreas** de `qa/coverage-index.json`
+ `_meta.counts`.

### Trampas del índice de cobertura

- La Fase 1 **no** redujo el área del transporte: redujo `groups-backend-g6-migration` (26→8 globs).
  `groups-cross-device-sync` (`manual`) tiene **18 globs** tras `bc486c92` (entró `SplitGroupZone.swift`),
  9 de los cuales sobreviven.
- **`groups-icloud-availability-gate` (JSON `965-976`) pierde sus 2 únicos globs, y `codeGlobs` vacío es
  error DURO** (`validate-coverage.py:61`) ⇒ hay que **borrar el área** y bajar `_meta.counts` a
  `total 133 / manual 57`. Los globs sin match son solo WARN, y **`counts` no lo valida nadie**.
- ~~El índice cita `unit:YalaTests/BootSaveGateLogicTests` escondida en `SplitSyncStartGateTests.swift`~~ —
  **RESUELTO en `bc486c92`**: la suite tiene su fichero y la cita es literal. La cita vive en DOS áreas
  (`groups-cross-device-sync` y `icloud-sync-multi-device`); la segunda es la dueña del gate y sobrevive.
- El criterio de salida `grep -r "import CloudKit"` del plan **no escanea `App/Logic/`**, donde
  sobreviven `GroupJoinReconcileLogic.swift:15` y `GroupAcceptShareErrorLogic.swift:23` — ninguno en las
  listas del plan.

---

## Dos cosas ya muertas hoy (limpieza gratis, sin relación con la Fase 3)

- `GroupUserIdentityService.swift:70-73` — `deterministicMemberID(groupZoneID:)`, **0 callsites**.
- `MetricsService.swift:37` — `cloudkitBudgetCSVMirrorRebuilt`, **0 emisores** en todo el repo.
