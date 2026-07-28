Fase 1 del plan de simplificación de Grupos de Yala: **borrar la maquinaria de migración de grupos vivos a la nube** (~3.500 líneas, DARK, nunca corrió en producción) y **cerrar el RPC `migrate_group` en el gateway**. Es una fase de BORRADO, no de construcción.

Repo `/Users/jur/Yala`, branch `2.0.5`. Haz `git pull` primero.

**El plan de referencia, por orden:** (A) `$VAULT/Backlog/modo-nube/MODO-NUBE-PLAN-SIMPLIFICACION-GRUPOS.md`, con `$VAULT = ~/Library/Mobile Documents/iCloud~md~obsidian/Documents/YalaWiki/` — es la SSOT y esta máquina **sí** tiene el vault; (B) si no está montado, el espejo del repo `docs/modo-nube/MODO-NUBE-PLAN-SIMPLIFICACION-GRUPOS.md`. Comprueba cuál existe antes de leer, y si el `updated:` del vault es posterior, gana el vault. Lee §3 (Fase 1). De todos modos **este texto es autosuficiente**: el plan es contexto, no un requisito para trabajar.

Todas las coordenadas de abajo se verificaron contra `ed38c1ea` el 2026-07-28. **Re-comprueba cada rango con `sed -n`/`grep -n` antes de editarlo** — si el `pull` trajo commits nuevos habrá drift.

---

## 0 · Pre-vuelo, antes de escribir una línea

`git status --porcelain`. Hay (o había) **trabajo de otras sesiones sin commitear**: `Yala/App/ContentView.swift` y `gateway/src/index.ts` (+10 líneas, un `app.onError`). Ese segundo fichero es precisamente el que enruta `/groups/rpc/:fn`.

- **Nunca** `git add -A`, **nunca** `git stash`, **nunca** `git checkout --` sobre trabajo ajeno.
- Si aparece algo modificado fuera de tu allowlist (§5), **párate y pregunta**.
- Añade solo los ficheros que tú tocas, por ruta explícita.

---

## 1 · La secuencia obligada, y su porqué

**Gateway → cliente Swift → (después, y NO lo ejecutas tú) `drop function` en staging → en prod.**

Al revés: PostgREST devuelve `PGRST202`, el gateway lo traduce a 502 `yala_unavailable` (su `message` no casa `/^yala_[a-z_]+$/`), y un uploader de un build antiguo entra en **retry-loop**. Cerrar la puerta primero hace que la ruta devuelva **404 antes de tocar PostgREST**.

Riesgo real de tráfico hoy: **cero** — `Yala/Services/CloudSync/CloudSyncFlags.swift:266` es `groupsBackendCompiledDefault = false` sin `#if`, y `:257-262` compone «compilado && remoto» (el flag remoto solo mata, nunca enciende) ⇒ ningún build publicado llama `migrate_group`. Mantén el orden igual: es gratis. **El peligro de verdad es otro y está en el paso 1.**

---

## 2 · Los pasos, en orden

### Paso 1 — Cerrar el RPC en el gateway. **Commit propio, separado.**

`gateway/src/groups/rpc.ts` (159 líneas):
- `:51-52` comentario de la entrada + `:53` `migrate_group: new Set(["p_group_id", "p_meta", "p_members"]),` en `PARAM_ALLOWLIST` → fuera.
- `:66` `"migrate_group",` en `RPC_NEEDS_ENC_KEY` → fuera.
- `:6` el doc-comment dice «(11 RPCs de membresía)» y quedan **10** → corregir el número. (Verificado: `PARAM_ALLOWLIST` tiene 11 claves hoy.)

Blast radius: `PARAM_ALLOWLIST` se lee **solo** en `:105` y `RPC_NEEDS_ENC_KEY` **solo** en `:128`, ambos dentro de `handleGroupsRpc`. El 404 sale en `:106-108`. Ninguna otra ruta cambia.

**EN EL MISMO COMMIT, los goldens — esto es lo que el plan viejo se dejaba y es bloqueante.**
`gateway/test/groups.goldens.test.ts` (994 líneas):
- `:88` `"migrate_group",` en la copia **local** de `RPC_NEEDS_ENC_KEY` del test → fuera.
- El bloque G6 es **`640-848`** (no `641-852`): `:640` es el `// ====` de apertura, `:641` la cabecera, `describe(` en `:695` (**ya ACTIVO**, no `.skip`), cierra en `:848`. `:850-852` es la cabecera del bloque G7 y **no se toca**.
- **BLOQUEANTE:** el `describe` G10 (`:928-994`) usa tres símbolos definidos DENTRO del bloque G6 — `setupGroupWithRebind` (`:673`, que **llama** `migrate_group` en `:682` y espera 200 en `:691`), `readMember` (`:666`, usado en `:946 :949 :976 :991`) y `LEGACY_PIA` (`:659`, usado en `:963 :976`). Borrar `640-848` en bloque **no compila**. Y el golden G10 nº 2 (`:961`, «owner sin heredero elegible → `no_eligible_owner`») se pone **ROJO en cuanto aterrice este paso**, porque llama `migrate_group` por el gateway.
- `:925` es prosa de la LIMITACIÓN CONOCIDA de G10 que cita `migrate_group`.

**YA DECIDIDO por el owner (2026-07-28) — no preguntes, ejecuta esto:**

1. **Mueve `readMember` y `LEGACY_PIA`** (~12 líneas) por encima del `describe` G10, para que sobrevivan al borrado del bloque G6.
2. **Re-siembra el fixture de G10 nº2 sin `migrate_group`.** Escribe un helper nuevo y acotado (~15-20 líneas) que reproduzca lo que hacía `setupGroupWithRebind`: crear el grupo con **`create_group`** por el gateway y luego poner a NULL el `user_id` del miembro placeholder con un UPDATE directo. Es lo único que ese golden necesita: la fila de co-member con `user_id NULL` que dispara `no_eligible_owner`. **No reutilices `setupGroupWithRebind`** — se va con el bloque G6.
3. **Borra el bloque G6** (`640-848`) y `:88`, y ajusta la prosa de `:925`.

**Por qué se paga esta excepción al presupuesto de la fase:** el golden cubre «el owner se va y no hay heredero elegible», rama de `transfer_group_ownership` que **se enciende en 2.1** y decide qué pasa con un grupo cuando su dueño desaparece y nadie puede heredarlo. Perder su cobertura E2E por ahorrar 20 líneas de fixture es un mal cambio. Las ~20 líneas son test, no producción: el techo de producción nueva sigue intacto.

**Lo que NO haces:** dropear la función SQL. Ver el paso 6.

**Contexto de por qué el fixture hay que re-sembrarlo y no hay atajo:** el propio fichero lo explica en `:923-926` — la fila placeholder con `user_id NULL` que ese golden necesita **solo la sabía fabricar `migrate_group`**. De ahí que haya que reproducirla a mano con `create_group` + UPDATE.

### Paso 2 — Preservar la cobertura del camino VIVO, antes de cualquier `git rm`

`YalaTests/CloudSync/GroupPullRescueChannelTests.swift` (216 líneas) tiene **dos** secciones:
- `58-125` — `// MARK: - backendPullSignal`, 4 tests que mueren con el rescate → **borrar solo esto**.
- `126-216` — `// MARK: - Suelo del corte del History`, 5 tests que cubren un camino **VIVO**: `theCutNeverOvertakesTheGroupsDrainAnchor`, `aLiveGroupOutboxRowHoldsTheCut`, `aDeadLetteredGroupRowDoesNotHoldTheCut`, `theCutIsTheMinimumAcrossBothChannels`, `withoutTheGroupsChannelTheCutIsUnchanged` → **conservar**, junto con la infra de `22-56`.

Esos 5 tests atan `CloudSyncEngine.deleteHistorySafeCut` a las anclas del canal de Grupos (`GroupSyncCursor.lastDrainedTxAt` y la fila viva más vieja de `GroupSyncOutbox`). Con 2.1 el backend es el ÚNICO canal ⇒ el invariante pasa a crítico. Renombra el suite (p. ej. `GroupsHistoryCutFloorTests`) y su glob en el coverage-index. **Borrar el fichero entero es una regresión de cobertura silenciosa.**

### Paso 3 — El commit del cliente: editar los consumidores y borrar los 7 ficheros. **Un commit atómico.**

No existe orden intermedio que compile: `GroupFetchQuiescenceGate` ↔ `SplitSyncManager.privateFetchGateSignal` (`198-216`) se referencian mutuamente (el tipo de retorno **es** `GroupFetchQuiescenceGate.Signal`), y `GroupCapability` vive DENTRO de `GroupCapabilityBeacon.swift:19-50` con `GroupMigrationReadinessLogic:78/:90` y `GroupSettingsView` colgando. Edita las hojas primero solo por comodidad.

**Consumidores a editar (rangos verificados):**

| Fichero | Rangos |
|---|---|
| `Yala/App/AppBootstrapper.swift` | **`417-431`** (beacon: comentario `417-422`, `if !uiTestActive` en `:423`, llamada en `:429`, cierra `430-431`) y **`433-454`** (uploader: comentario `433-438`, `if` en `:439`, `reconcileMarkers` `:451`, `run()` `:452`, cierra `453-454`). El plan viejo decía `426-431` y `439-446`/`439-453`: **las tres falsas**. No toques `456-467` (`GroupBatchLeaveOrchestrator.resume`, D10) más allá de corregir la frase «DESPUÉS del uploader (16.8.5)» |
| `Yala/App/Views/Groups/GroupsContainerView.swift` | `:40` (`@State migrationProgress` — rompe el build), `74-86` (`migratingBanner`), `88-103` (`waitingBanner`) |
| `Yala/App/Views/Groups/GroupSettingsView.swift` | `113-118` (la condición) y `665-717` (`migrationLaggards` + `migrationWaitingSection`) |
| `Yala/Services/Groups/SplitSyncManager.swift` | `:182`, `:186` (declaraciones), `188-196` (`backendPullSignalProvider`), `198-216` (`privateFetchGateSignal`), `1808-1820` (`rescueFlagOn`/`backendPullCache`/`backendPullSignal(_:)`/`rescuedThisBatch`), **`1843-1877`** (ver TRAMPA 1), `1949-1955` (canario + `pendingRescueDrain = true`), `2027-2033` (consumo de `pendingRescueDrain`), `2344-2362` (re-encolado del beacon tras conflicto), **`2542-2617`** (ver TRAMPA 2) |
| `Yala/Services/CloudSync/Groups/GroupsSyncClient.swift` | `751-852` (MARK + seed; `enqueueSnapshotRows` en `:767`), `1426-1457` (`backendPullSignal`, func en `:1444`), `1761-1772` (guard `migrationInFlight`, código en `:1769-1770`), `2151-2155` (`liveGroupOutboxCount`, func en `:2153`). **El privado `liveOutboxCount` de `:2146` SOBREVIVE**: lo usa el Merkle |
| `Yala/Services/CloudSync/Groups/GroupBackendMembershipService.swift` | `150-155` (`func migrateGroup` en `:152`) |
| `Yala/Services/CloudSync/Groups/GroupsMembershipClient.swift` | `102-115` (`struct MigrateGroupResult` en `:104` — el plan viejo no lo listaba) y `353-369` (`func migrateGroup` en `:358`; `:370` es línea en blanco) |

**Estado que queda write-only y hay que barrer en el mismo commit** (Swift avisa pero no falla, así que si no lo haces queda drift permanente): `replayingFullCorpus` (declaración `:182`, writes en `:396 :1529 :1536 :1648 :1686`, único lector el gate del rescate), `pendingRescueDrain` (`:186`, `:1954`, `2027-2033`), `fetchApplyFailedThisSession` (`:165`, writes `:1765` y `:1962`), `backendPullSignalProvider` (`188-196`), `prefetchFailed` (`:1790`, `:1802`).

**`git rm` de los 7 ficheros de producción — 1.288 líneas, `wc -l` verificado:**

```
Yala/Services/CloudSync/Groups/GroupMigrationUploader.swift        537
Yala/App/Logic/GroupPullRescueGate.swift                           181
Yala/App/Logic/GroupFetchQuiescenceGate.swift                      178
Yala/Services/CloudSync/Groups/GroupCapabilityBeacon.swift         132
Yala/App/Logic/GroupMigrationReadinessLogic.swift                  106
Yala/Services/CloudSync/Groups/GroupMigrationPayloadBuilder.swift  103
Yala/Services/CloudSync/Groups/GroupMigrationProgress.swift         51
```

**`git rm` de los 10 ficheros de test restantes** (2.293 menos los 216 del recortado en el paso 2 = 2.077):

```
YalaTests/CloudSync/GroupMigrationUploaderTests.swift
YalaTests/CloudSync/GroupPullRescueTests.swift
YalaTests/CloudSync/GroupPullRescueWiringTests.swift
YalaTests/CloudSync/GroupPullRescueGateTests.swift
YalaTests/CloudSync/GroupPullRescueParityTests.swift
YalaTests/CloudSync/GroupFetchQuiescenceGateTests.swift
YalaTests/CloudSync/GroupFetchGateWiringTests.swift
YalaTests/GroupMigrationReadinessLogicTests.swift
YalaTests/GroupMigrationStateTests.swift
YalaTests/GroupMigrationPayloadBuilderTests.swift
```

**NUNCA con un glob `*Migration*`:** `YalaTests/CloudSync/` tiene 8 ficheros `Migration*` de la migración **PERSONAL** a la nube, otro frente (`MigrationRunnerTests`, `MigrationStateMachineTests`, `MigrationPhaseStoreTests`, `MigrationStateJournalTests`, `MigrationWorkExecutorTests`, `MigrationSnapshotUploaderTests`, `MigrationCutoverE2EStagingTests`, `BGTaskMigrationGateTests`, `CloudMigrationI14Tests`). Un glob se lleva medio canal personal.

**Un test que hay que EDITAR, no borrar, o el target no compila:** `YalaTests/GroupCardDisplayLogicTests.swift` usa `GroupMigrationState` en `:48-94`. No está en la lista de arriba. Su suite `GroupFreezeLogicTests` (`:102-138`, sobre `isFrozen`) **sobrevive**.

### Paso 4 — Canarios y breadcrumbs sin emisor (mismo commit que el paso 3)

- `Yala/Services/Metrics/MetricsService.swift` (**ojo: el path es `Services/Metrics/`, no `Services/`**) — casos huérfanos: `:93` `groupMigrationCompleted`, `:94` `groupMigrationFailed`, `:102` `groupMigrationDeferred`, `:108` `groupCkPullRescued`, `:117` `groupMigrationWaitingForMembers`, `:119` `groupCapabilityBeaconPublished`.
- `Yala/Services/CloudSync/Groups/GroupsSyncBreadcrumb.swift` — huérfanos: `:176 :181 :187 :194 :210 :216 :222`.
- **SOBREVIVEN:** `groupsCkMigrationMarkerEnqueued` (`:151`, su callsite `SplitSyncManager:1233` tiene un segundo consumidor vivo en `:2267`, el rebase por conflicto), `groupsCkPullSkippedBackendGroup` (`:165`, lo usa el guard que conservas), `groupsCkFetchApplyFailed` (`:203`).

### Paso 5 — `qa/coverage-index.json`, en el MISMO commit

El área `groups-backend-g6-migration` está en **`2420-2455`** con **26 `codeGlobs`**, y **8 apuntan a ficheros que SOBREVIVEN**: `Yala/App/Logic/GroupFreezeLogic.swift`, `Yala/App/Logic/GroupCardDisplayLogic.swift`, `Yala/Services/Groups/CKRecordTranslator.swift`, `Yala/Services/Groups/CloudKitConstants.swift`, `YalaTests/GroupFreezeGuardTests.swift`, `Yala/App/Views/Groups/GroupCardView.swift`, `Yala/Models/SplitMember.swift`, `YalaTests/GroupCardDisplayLogicTests.swift`.

⇒ **el área se REDUCE, no se borra.** Quita los 18 globs de la maquinaria, deja los 8, reescribe el texto de `coverage` a lo que queda (el freeze y su guard) y actualiza `lastVerified`. El área muere entera en la Fase 4, cuando se borre `movedToBackendAt`.

- El área es `classification: "manual"` y `_meta.backlogBaseline` es **0** ⇒ **el ratchet no se dispara y `backlogBaseline` NO se toca** (ya está en el suelo; solo cuenta áreas `deterministic` cuyo `coverage` no empiece por `xcuitest:`).
- `_meta.counts` **no lo valida nadie**: si reduces el área, `total` sigue en 134 y no cambia. **Si acabaras borrando un área**, hay que bajar `total` (134→133) y `manual` (58→57) **a mano**.
- Edita también la prosa de las 4 áreas que citan lo borrado: `groups-cross-device-sync`, `cloud-sync-capture`, `groups-backend-g2-sync-channel` (las tres mencionan `GroupPullRescue`) y `session-sign-out` (menciona `GroupMigration`).
- Corre `bash qa/validate-coverage.sh` → debe dar `RESULT: OK` sin WARN nuevo de «glob sin match».

### Paso 6 — La función SQL NO se dropea. **Decisión del owner (2026-07-28).**

`migrate_group` **se queda en la base de datos**, inerte detrás del 404 del paso 1. Con eso **todo el runbook
de despliegue que el plan viejo pedía aquí queda CANCELADO**, no aplazado:

- **NO** escribas `qa/cloud/g6_02_drop_migrate_group.sql`.
- **NO** toques `supabase-groups-staging.ddl` (su §4 se queda tal cual, y sus contadores «34/34 functions»
  siguen siendo verdad).
- **NO** borres `qa/cloud/g6_01_migrate_group.sql` ni la sección `## migrate_group (G6-1)` del README.
- **NO** apliques migraciones, **NO** despliegues Workers, **NO** corras los goldens de red. Los goldens
  **MUTAN staging** (crean grupos sin cleanup: `DELETE` está revocado por diseño) y exigen `GROUPS_ENC_KEY`
  con fail-fast en `beforeAll`. Y `wrangler deploy` sube **el árbol de trabajo, no HEAD**.

**Lo único que sí escribes** (3-4 líneas, para que nadie se confunda dentro de seis meses): un addendum
**fechado** al final de `qa/cloud/README.md` que diga que desde el 2026-07-28 la ruta
`POST /groups/rpc/migrate_group` devuelve **404 por diseño** (retirada de `PARAM_ALLOWLIST`), que la función
`public.migrate_group` **sigue existiendo** en staging y en producción a propósito, y que sus goldens G6 se
retiraron con la Fase 1 del plan de simplificación de Grupos. **No toques** los «33/33» ni los md5 históricos
de `:343` y `:1201`: son fotos del 2026-07-16 y editarlas corrompe el registro de la promoción.

**Lo que queda pendiente del owner, y lo dejas escrito sin ejecutar:** desplegar el gateway con el cambio del
paso 1 (`cd gateway && npm run deploy:staging`, luego `deploy:production`) y verificar que
`POST /groups/rpc/migrate_group` con un JWT válido devuelve **404 `yala_bad_request`**, esperando **≥30 s** —
hay ~15 s de 404-con-envelope por propagación de Cloudflare, así que un 404 inmediato NO prueba nada. Antes de
cualquier deploy hay que resolver `gateway/src/index.ts` sucio (trabajo ajeno sin commitear).

**NO edites las migraciones ya aplicadas**, que mencionan `migrate_group` legítimamente y se comparan byte a
byte contra `schema_migrations`: `qa/cloud/g7_02_encrypt_groups_cutover.sql:415-417/:911/:924`,
`g8_01_push_fanout.sql:14`, `g10_01_transfer_group_ownership.sql:45`.
`g8_01_push_fanout.sql:14`, `g10_01_transfer_group_ownership.sql:45`.

---

## 3 · Las tres trampas. Aplicar los rangos del plan viejo literal rompe cosas.

**TRAMPA 1 — `SplitSyncManager:1843-1877` mezcla código muerto y código VIVO.**
El `if backendZoneNames.contains(record.recordID.zoneID.zoneName) {` de **`:1851`** (cierra en `:1877`) **no es el rescate C-4**: es el **guard de PULL de G6-3 (C2)**, y su comentario lo dice («aplicarlos PISARÍA las ediciones backend post-migración»). Lo que muere es el interior: la señal (`1852-1864`), el `guard GroupPullRescueGate.decide(...) == .rescue` (`1865-1868`) y el `applyRemoteRecordIfAbsent` (`1869-1871`). Lo que **queda** es esta forma reducida, que es un revert a lo anterior:

```swift
if backendZoneNames.contains(record.recordID.zoneID.zoneName) {
    GroupsSyncBreadcrumb.groupsCkPullSkippedBackendGroup(site: "applyRemote", reason: "backendGroup")
    continue
}
```

Su gemelo de `deletions`, **`:1936`**, **no se toca**. `backendZoneNames` (`:1778`) y `backendGroupZoneNames` (`:918-928`) **sobreviven**. Con 2.1 todo ON y el transporte vivo hasta la Fase 3, borrar el guard abre una ventana en la que un record CloudKit stale pisa la verdad del backend y se bridgea al store personal. **No falla al compilar y no lo caza ningún test.**

**TRAMPA 2 — el bloque de helpers termina en `:2617`, no en `:2626`.**
`:2542` es el `// MARK: - Rescate de pull (C-4 PIEZA 2)`, `recordExistsLocally` en `:2550`, `applyRemoteRecordIfAbsent` en `:2578` y **termina en `:2616`**. `applyGroupMeta` (**VIVO**) empieza en **`:2619`**, y su `let wasHidden = existing.isHiddenForAll` (`:2624`) alimenta `pendingFreezeZoneIDs` (`:2628` y `:2644`), que se drena en `1971-1985` disparando `freezeForSoftDelete` (`:1979`). El rango `2542-2626` del plan viejo se come esa captura.

**TRAMPA 3 — el describe G10 de los goldens.** Ver el paso 1.

**Cuatro piezas que se apagan en silencio y NO son de esta fase — compruébalas por grep en el momento del borrado, no al final:**
- `grep -n processRemoteChanges Yala/Services/Groups/SplitSyncManager.swift` → **1** (`:2039`).
- `grep -n MemberChangeNotificationLogic …` → **≥3** (`1828-1837`, `:1909`).
- `grep -n pendingFreezeZoneIDs …` → los inserts de `:2628`/`:2644` y el drenaje de `1971-1985` **intactos**.
- `grep -n accountDeletionGroupsSummary …` → `:998`, con sus 3 consumidores (`ProfileView.swift:545`, `:1128`, `UserDataResetView.swift:90`).

---

## 4 · Lo que NO se borra aunque lo parezca

1. **`CloudSyncEngine.deleteHistorySafeCut` y sus anclas del canal de Grupos** (`groupDrainedBoundary` y `oldestLiveGroupOutboxDate`, más las 2 líneas del cut). Nacieron con el rescate pero son **correctness del canal que sobrevive**: el History es por-`ModelContainer` y con 2.1 el backend es el único canal de Grupos. Sin ellas, el pruning personal puede comerse la transacción de una fila del outbox de Grupos antes de que suba. Solo se reescribe el «[C-4 PIEZA 2]» del doc-comment.
2. **`SplitSyncManager.enqueueMigrationMarker`** (`:1233`): segundo callsite vivo en **`:2267`** (rebase del marcador ante conflicto). Muere con el transporte, no aquí.
3. **`GroupsSyncClient.liveOutboxCount`** (`:2146`, privado): lo usa el Merkle.
4. **`GroupsIdentityPurgeGate`**: no depende de nada de esta fase (solo de los **campos** `movedToBackendAt` y `markerEnqueuedFlag`). Sobrevive intacto. Sus 2 callsites vivos están en `Yala/Services/Groups/GroupService.swift:1043` y **`:1083`** (el plan viejo decía `:1034`/`:1074`).
5. **`L10n.Groups.SignIn.retryLater`**: es del sign-in del backend, camino VIVO. No la confundas con las keys del estado migrado.
6. **`GroupFreezeLogic.isFrozen` (`111-120`) y `SplitGroup.isMigratedFrozen` (`17-24`)**: sobreviven a esta fase y mueren en la Fase 4, con `movedToBackendAt`. **No repuntes el predicado de `isFrozen`** — la «red de seguridad» que lo pedía está CANCELADA por decisión del owner.
7. **`GroupMigrationState`, `GroupBackendCapability`, `GroupFreezeLogic.migrationState`, las 19 keys de l10n del estado migrado y las 6 vistas que las pintan**: van **en la Fase 4**, en el commit que borra `movedToBackendAt`. **No las toques aquí.** Tocarlas ahora obliga a editar las mismas 6 vistas dos veces, y eso es exactamente el sobre-alcance que hay que cortar.
8. **`SplitMember.clientCapability` / `clientCapabilityAt`**: son schema, mueren en la Fase 4. Anota en el commit que **el deploy pendiente de esos 2 field keys a CloudKit Production queda CANCELADO, no aplazado** — que nadie lo despliegue por inercia.

**YA DECIDIDO por el owner (2026-07-28): declarar el hueco, NO rescatar los tests.** Los únicos tests de `GroupFreezeLogic.isFrozen` viven dentro de `YalaTests/GroupMigrationStateTests.swift` (el invariante `isFrozen_unchanged_byCapability`), que esta fase borra. `isFrozen` sobrevive en producción hasta la Fase 4, donde muere con `movedToBackendAt`.

⇒ **No escribas tests de sustitución.** Escribir cobertura para lógica que ya está programada para morir es justo el exceso que esta fase corta. Lo que sí es obligatorio: **decirlo en el mensaje del commit**, con esta forma o parecida — «`GroupFreezeLogic.isFrozen` queda sin cobertura unitaria al borrar `GroupMigrationStateTests`; es deliberado: muere en la Fase 4 con `movedToBackendAt`, que va antes de 2.1, así que no llega a publicarse sin tests». Si por cualquier razón la Fase 4 se retrasa y 2.1 se acerca, **eso deja de ser cierto y hay que reabrirlo** — dilo también.

---

## 5 · Disciplina de alcance. Con números.

**Esta fase es SUSTRACTIVA. Si el diff acaba con más inserciones que borrados, algo va mal.**

Presupuesto verificado, actualizado con las decisiones del owner del 2026-07-28:

| Concepto | Techo |
|---|---|
| Borrado | **~-3.500 líneas** |
| Producción NUEVA | **+5 líneas**, y son solo la forma reducida del guard de la TRAMPA 1 (3 líneas que ya existen en otra forma). **Nada más.** |
| Test NUEVO | **+20 líneas**, y son solo el fixture re-sembrado del golden G10 nº2 (paso 1) más el movimiento de `readMember`/`LEGACY_PIA` |
| Documentación NUEVA | **+4 líneas**: el addendum fechado de `qa/cloud/README.md` (paso 6) |

El techo de producción bajó de 25 a 5 porque el `drop function` está cancelado: ya no hay `.sql` nuevo, ni tombstone en el DDL, ni addendum de paridad. Y las +20 de test son una **excepción explícitamente autorizada** por el owner, no un permiso general para escribir tests.

**Prohibido, sin excepciones:**
- **Ficheros de lógica pura nuevos** con su suite exhaustiva. En la tanda anterior esto fue el **29 %** del diff.
- **Canarios y breadcrumbs nuevos.** La tanda anterior dejó ~180 líneas de canarios que no pueden emitir. Aquí solo se **retiran** los 6 casos de `MetricsService` y los 7 de `GroupsSyncBreadcrumb` que quedan sin emisor.
- **Tests que afirman texto fuente.** Los dos `*WiringTests` que borras (`GroupPullRescueWiringTests` 205 + `GroupFetchGateWiringTests` 114 = 319 líneas) son exactamente ese patrón. **No los sustituyas por otros del mismo molde.**
- **Doc-comment de más.** La tanda anterior metió ~700 líneas de doc-comment redundante — más doc que código. Aquí solo se escribe donde el borrado deja una afirmación FALSA, y son 5 sitios concretos: `Yala/Utils/SwiftDataConfiguration.swift:381` (nombra el uploader en prosa), `Yala/App/Logic/GroupsIdentityPurgeGate.swift:77`, `Yala/App/Logic/GroupFreezeLogic.swift:126`, `Yala/Models/SplitGroup.swift:54-58`, `Yala/Services/Metrics/MetricsService.swift:97-107`. **Ni uno más.**
- **l10n en superficies inalcanzables.** Esta fase **no añade ni una key** y no toca los `.lproj` (las 19 keys del estado migrado son de la Fase 4). La tanda anterior localizó copy en 17 locales para pantallas que nadie podía alcanzar.
- **Ficheros de documentación nuevos.** Ni `.md` nuevo en `docs/`, ni `STATE.md`, ni `DECISIONS.md`. Las dos superficies son el plan que ya existe y, si sale una regla durable, `.claude/rules/`.
- **Arreglar de paso cualquier cosa ajena a la fase.** Si encuentras un bug, **lo REPORTAS en tu mensaje final, no lo arreglas.** En particular: no toques `ImportIntroSheet.swift` (§6), no toques `ContentView.swift` ni `gateway/src/index.ts` (trabajo ajeno sin commitear), y no arregles el drift preexistente de `groups.signin.error` (huérfana en `en.lproj`, declaración viva en `L10n.swift`).

**Contexto de por qué estas reglas están aquí:** una revisión de los 4 commits de la tanda anterior encontró que de **6.823 líneas insertadas solo 1.163 eran código de producción ejecutable (17 %)**, con más doc-comment (1.299) que código y 3.361 de test — factor **4,5×** sobre el fix mínimo. Además dejó 6 riesgos en caminos VIVOS mientras arreglaba código apagado, y desplegó a producción sin pedirlo. Las reglas del repo no lo explican: `coverage-index` + `.claude/rules` costaron 85 líneas de 6.823.

**Allowlist de ficheros que el diff puede tocar.** Cero hits fuera de: `Yala/Services/CloudSync/Groups/**`, `Yala/App/Logic/Group*`, `Yala/Services/Groups/SplitSyncManager.swift`, `Yala/App/AppBootstrapper.swift`, `Yala/App/Views/Groups/**`, `Yala/Services/Metrics/MetricsService.swift`, `YalaTests/**`, `gateway/src/groups/rpc.ts`, `gateway/test/groups.goldens.test.ts`, `qa/**`, `supabase-groups-staging.ddl`.
**Cero hits** en `CloudSyncEngine.swift`, `MigrationRunner*`, `PreferenceSyncService.swift`, `StorageMode*`, `iCloudSyncService.swift`, `DataWipeService.swift`, `CloudSessionSignOut.swift`.
**Excepción única y auditada:** `Yala/Utils/SwiftDataConfiguration.swift` — si aparece, su diff debe ser **100 % líneas de comentario**. Compruébalo: `git diff -- <f> | grep '^[+-]' | grep -v '^[+-][[:space:]]*//'` debe salir vacío.

**Excepción de comportamiento que hay que DECLARAR, no ocultar.** El bloque del beacon (`AppBootstrapper 417-431`) corre **fuera** del gate del flag en toda producción, y su `guard await awaitPersonalStoreReady()` (`:425`) pasa por el gate de boot-save del store personal, que escribe el contador persistido `bootSaveDeferCount` y a los ≥3 emite un canario (UserDefaults + POST). Borrarlo baja de **12 a 11** los consumidores de ese contador (`grep -c 'awaitPersonalStoreReady()' Yala/App/AppBootstrapper.swift`, la definición incluida) ⇒ el canario `cloudBootSaveDeferredRepeatedly` puede bajar de frecuencia. El cambio es benigno, pero **la rama `.icloud` NO queda byte-idéntica**: escríbelo en el mensaje del commit. No afirmes lo contrario.

---

## 6 · El árbol está verde. Y cómo NO repetir un rojo falso.

`/gate` exige **las dos** schemes (`.claude/commands/gate.md:22-29`). **Estado verificado el 2026-07-28 a las 08:49: las dos compilan.** `-scheme "Yala Dev"` → `BUILD SUCCEEDED` sobre `HEAD ed38c1ea`. No hay ningún bloqueo.

**Lee esto antes de diagnosticar cualquier fallo de compilación, porque ya costó horas.** Ese mismo día, dos builds de `Yala Dev` fallaron en `Yala/App/Views/Import/ImportIntroSheet.swift:370` con `requires that 'Category' conform to 'Hashable'`, `cannot conform to 'SortComparator'` y `cannot infer type of closure parameter`, y se concluyó que la branch estaba rota. **No lo estaba.** El código era byte-idéntico, no había commits nuevos, DerivedData no se recreó y el disco tenía 64 GB libres. Lo único distinto era la **carga de la máquina**: dos workflows con decenas de agentes y builds concurrentes. Esa terna de errores es la firma de un **timeout del type-checker** en una expresión encadenada (`Dictionary(grouping:)` + `compactMap` + `sorted`), no un defecto de tipos.

Conducta:

1. **No corras builds ni `/gate` con otras sesiones o workflows compilando en paralelo.** Un rojo falso es peor que no medir: manda a cazar un bug inexistente.
2. **Ante errores de inferencia en una expresión encadenada, sospecha del entorno antes que del código.** Repite el build con la máquina en reposo antes de tocar una línea. Es el principio que CLAUDE.md ya fija: «antes de culpar al código, mira el entorno».
3. **NO arregles `ImportIntroSheet.swift`.** No está roto, y aunque anotarle los tipos lo blindaría contra esa flakiness, es código ajeno a esta fase: sobre-alcance.
4. **Párate en seco** si el build se rompe **por tu cambio** y lo reproduces con la máquina en reposo. Entonces el problema es tuyo: no sigas apilando trabajo.
5. Si por lo que sea el gate queda incompleto: implementa la fase, corre lo que sí puedas (`-scheme Yala`, `YalaTests`, `/l10n-check`, `bash qa/validate-coverage.sh`, `npm run typecheck` en `gateway/`) y deja el trabajo **staged o en un branch, sin commit**, con nota explícita. Un commit con el gate a medias rompe el sello.

Nota: el sello del gate no lo comprueba ningún hook de git (`.git/hooks/` solo tiene `pre-push`, que valida el coverage-index). Lo comprueba un hook `PreToolUse` de `git commit`.

---

## 7 · Criterio de hecho

**A · greps que deben dar 0 hits** (con este alcance exacto; ampliarlo da falsos positivos):

1. `grep -rn "migrate_group\|migrateGroup" Yala/ gateway/src/ gateway/test/` → **0**. Ojo con el alcance, y es distinto de lo que decía el plan viejo: **`supabase-groups-staging.ddl` SÍ debe seguir mencionándola** (la función no se dropea, decisión del owner), y `qa/cloud/` también — las migraciones aplicadas conservan menciones legítimas y el addendum nuevo la nombra a propósito. Ampliar este grep a esas dos rutas da falsos positivos y te hará borrar cosas correctas.
2. `grep -rn "GroupMigrationUploader\|GroupPullRescueGate\|GroupFetchQuiescenceGate\|GroupCapabilityBeacon\|GroupMigrationReadinessLogic\|GroupMigrationPayloadBuilder\|GroupMigrationProgress" Yala/` → **0** (incluye las prosas de los 5 sitios del §5).
3. `grep -rn "pendingRescueDrain\|replayingFullCorpus\|fetchApplyFailedThisSession\|backendPullSignalProvider\|prefetchFailed\|privateFetchGateSignal" Yala/Services/Groups/SplitSyncManager.swift` → **0**.
4. `grep -n "groupMigrationCompleted\|groupMigrationFailed\|groupMigrationDeferred\|groupCkPullRescued\|groupMigrationWaitingForMembers\|groupCapabilityBeaconPublished" Yala/Services/Metrics/MetricsService.swift` → **0**.

**B · greps que deben SEGUIR dando hits** (éste es el freno de verdad):

5. `grep -n backendZoneNames Yala/Services/Groups/SplitSyncManager.swift` → **≥3** (`:1778`, el guard reducido, `:1936`).
6. `grep -n pendingFreezeZoneIDs Yala/Services/Groups/SplitSyncManager.swift` → los inserts de `applyGroupMeta` y el drenaje de `1971-1985`, intactos.
7. `grep -n processRemoteChanges Yala/Services/Groups/SplitSyncManager.swift` → **1**.
8. `grep -n accountDeletionGroupsSummary Yala/Services/Groups/SplitSyncManager.swift` → **≥1**, y sus 3 consumidores intactos.
9. `grep -n "isFrozen" Yala/App/Logic/GroupFreezeLogic.swift` → sigue ahí.
10. `grep -c 'awaitPersonalStoreReady()' Yala/App/AppBootstrapper.swift` → **11** (era 12). Exactamente uno menos: es la excepción declarada.
11. `grep -n liveOutboxCount Yala/Services/CloudSync/Groups/GroupsSyncClient.swift` → el privado sigue.
12. `grep -n enqueueMigrationMarker Yala/Services/Groups/SplitSyncManager.swift` → sigue (segundo callsite vivo).

**C · builds, suites y validadores:**

13. `xcodebuild -scheme Yala … build` → **SUCCEEDED, 0 warnings nuevos** en los ficheros tocados.
14. `xcodebuild -scheme "Yala Dev" … build` → SUCCEEDED. Si no, §6.
15. `YalaTests` completa **verde**, sin editar aserciones fuera de los 10 borrados + `GroupCardDisplayLogicTests` + el recortado. Con nombre propio, deben pasar: `HandoverGroupsDomainTests`, `GroupFreezeGuardTests`, `GroupsSignOutFlowTests`, `GroupNotificationServiceTests`, `GroupTransactionBridgeSoftDeleteTests`, `AccountDeletionGroupsSummaryTests`, `CloudKitGroupsSchemaParityTests`, `CloudSyncEngineTests`. **Si alguna de éstas necesita editarse, la fase se salió de su carril.**
16. `bash qa/validate-coverage.sh` → `RESULT: OK`, sin WARN nuevo de «glob sin match».
17. `cd gateway && npm run typecheck` verde. **Los goldens de red NO se corren** (mutan staging).
18. `git diff --stat` contra la allowlist del §5, con la excepción de comentarios verificada.
19. **Balance del diff: borrados ≫ inserciones**, y las inserciones de producción ≤ 25 líneas.

**D · lo que NO cuenta como criterio de hecho:**

20. «BUILD SUCCEEDED» no prueba nada aquí: los cuatro apagones del §3 son silenciosos por definición. Compruébalos por grep.
21. Que `qa/validate-coverage.sh` pase **no** prueba que el índice sea verdad: no valida `_meta.counts` ni que existan los ficheros de test citados, y los `codeGlobs` sin match son solo WARN. De hecho ya miente hoy: cita `GroupFreezeLogicTests` y `GroupCapabilityBeaconRefreshTests` como ficheros, y son `struct`s dentro de otros.

---

## 8 · Qué devolver al terminar

- Los commits creados (o el estado staged/branch si `Yala Dev` sigue roto), con sus mensajes.
- El resultado de cada comprobación del §7, con el número real.
- La decisión que tomaste sobre `isFrozen` sin cobertura (§4), textual.
- El runbook de despliegue que dejaste escrito (§2 paso 6), y **confirmación explícita de que no ejecutaste nada** de eso.
- **Los bugs y rarezas que encontraste y NO arreglaste**, con `path:línea`.
