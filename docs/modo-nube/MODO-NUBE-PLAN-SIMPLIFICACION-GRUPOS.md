---
created: 2026-07-27
updated: 2026-07-28
tags: [modo-nube, grupos, simplificacion, plan]
---

# PLAN — Simplificación de Grupos: 5 fases

**Repo** `/Users/jur/Yala` · **branch** `2.0.5` · **HEAD al reescribir** `ed38c1ea`.
Todas las coordenadas de este documento se comprobaron con `sed -n` / `grep -n` / `wc -l` reales el
2026-07-28. Lo que no se pudo confirmar va marcado **NO VERIFICADO** y no se propaga como hecho.

---

## Banner · Qué cambió respecto a la versión de 6 fases

El plan anterior tenía 6 fases más una Fase 0. El owner lo revisó punto por punto el **2026-07-28** y tomó
cinco decisiones. **Las dos fases que desaparecen son justamente las dos que añadían código nuevo.**

| Decisión del owner (2026-07-28) | Qué se cae del plan viejo |
|---|---|
| **1. Nada de export CSV.** «Siento que lo del CSV es innecesario.» | **La Fase 0 entera** (exportar los 2 CSV + confirmación escrita). Además la fila de Exportar estaba **oculta en modo solo-grupos**, que es el de Pia, así que tampoco estaba disponible |
| **2. Nada de red de seguridad.** «NADIE MÁS ACCEDIÓ… si alguien logró sobrepasarlo no me importa, le eliminamos todo, no hay impacto, son pocos usuarios.» | **La Fase 2 entera** (~61 líneas: repuntar `GroupFreezeLogic.isFrozen` a `!isBackendGroup` + hoja one-shot de aviso y export) |
| **3. Nada de desprender las transacciones bridgeadas.** El owner borra a mano cada gasto de grupo y los reintroduce después | **Las ~10 líneas de desprendimiento** (poner a `nil` `splitExpenseID` / `splitGroupZoneID` / `splitSettlementID`) **no se escriben** |
| **4. Release 2.1 con todo ENCENDIDO, sin escalonado**, TestFlight primero (`docs/modo-nube/MODO-NUBE-DECISION-RELEASE-2.1.md`) | Nada de rampas por %, gates de rollout parcial ni andamiaje de convivencia |
| **5. Migración personal a la nube = opt-in silencioso** | No afecta a Grupos, pero fija el marco: la rama `.icloud` la sigue usando casi todo el mundo ⇒ **cualquier regresión ahí golpea a todos los usuarios reales**. La no-regresión de 2.x es la regla más importante del release |

Objetivo declarado, textual: **«quiero código limpio»**, **«lo que implique MENOS COMPLICACIÓN DE CÓDIGO»**,
**«no quiero código innecesario ni artilugios para tan pocos registros»**. El plan viejo pedía ~71 líneas de
código nuevo (61 de red + 10 de desprendimiento) para proteger un caso que el owner declara inexistente. Las
5 fases que quedan son **sustractivas**: cada una borra mucho más de lo que escribe.

**Ganancia de alcance:** de 6 fases + Fase 0 y ~71 líneas de producción nueva, a **5 fases** con techo de
producción nueva **≈ 0** (solo la forma reducida de un guard que ya existe, más una migración SQL de un
statement).

---

## §1 · Lo que el owner hace a mano, y cuándo

Esta sección sustituye la Fase 0 del plan viejo. **No hay código que la implemente: es trabajo del owner en la
app**, y su ventana se cierra en la Fase 3.

### 1.1 · Borrar uno a uno cada gasto de grupo, ANTES de la Fase 3

**Por qué funciona sin código nuevo (verificado):** borrar el gasto en el grupo se lleva la transacción
personal. `GroupExpenseService.performExpenseDeletion` llama a
`GroupTransactionBridge.unbridgeExpense(expenseID:)` (`Yala/Services/Groups/GroupExpenseService.swift:263`) y
esa función borra **TODAS** las entidades cuyo `splitExpenseID == X`
(`Yala/Services/Groups/GroupTransactionBridge.swift:1201`; `TransactionItem` en `:1203-1206`, `InboxDraft` en
`:1208-1211`). Su propio doc-comment lo declara en `:1200`. **Sin huérfanos ⇒ el desprendimiento no hace
falta.** Lo mismo para liquidaciones: `unbridgeSettlement` (`:1180`) borra por `splitSettlementID`.

**Orden obligado dentro de cada grupo, y esto NO es opcional:**

1. **Primero las liquidaciones confirmadas, después los gastos.** `deleteExpense`
   (`GroupExpenseService.swift:222`) lanza `expenseHasAssociatedSettlements` si existe **cualquier** liquidación
   confirmada del grupo con `date >= expense.date` (`:229-241`). Con una liquidación confirmada reciente,
   **ningún** gasto anterior se puede borrar. Se borran con `deleteSettlement` (`:487`), que unbridgea antes
   (`:495`).
2. **Después los gastos**, en cualquier orden.

**Cuándo:** mientras el transporte CloudKit siga vivo, es decir **antes de la Fase 3**. El borrado encola
`SplitSyncManager.shared.enqueueDeletion(modelID:group:)` dentro de `performExpenseDeletion`, y ése es el camino
por el que la baja llega al device de Pia. Después de la Fase 3 el borrado es solo local.

**La ventana está abierta hoy:** ningún grupo está congelado. `GroupFreezeLogic.isFrozen`
(`Yala/App/Logic/GroupFreezeLogic.swift:111-120`) exige `movedToBackendAt != nil`, y el único escritor de ese
campo es el uploader, que vive detrás de `groupsBackendEnabled` (compilado en `false`,
`Yala/Services/CloudSync/CloudSyncFlags.swift:266`). ⇒ los grupos se pueden editar y vaciar **ahora**.

### 1.2 · ¿Puede borrar los gastos de Pia? — SÍ. Punto cerrado.

El brief lo dejaba abierto. Verificado: `deleteExpense` **no comprueba quién pagó ni quién creó el gasto**. Su
único guard es `validateCurrentUserCanWrite(in: group)` (`GroupExpenseService.swift:633-645`):

| Requisito | Línea |
|---|---|
| el grupo es escribible (no congelado) | `:634` `validateGroupIsWritable(group)` |
| hay fila de miembro `isCurrentUser`… o es owner sin fila (`if group.isOwner { return }`) | `:636-639` |
| no está pendiente de aprobación | `:640-642` |
| está activo | `:644` |

La UI gatea igual, por participación y no por autoría: `GroupDetailView.swift:304` y `:419` pasan el `onDelete`
solo si `viewModel.canCurrentUserParticipate`.

⇒ **El owner puede borrar los gastos de Pia desde su propio device**, siempre que sea miembro activo (u owner)
del grupo. Pia no tiene que hacer nada. Lo único que sigue dependiendo de su device es que su app
**sincronice** para que la baja aterrice ahí, y eso solo ocurre mientras el transporte viva (§1.1).

### 1.3 · Lo que NO puede hacer: eliminar los grupos

`GroupService.deleteGroup` (`Yala/Services/Groups/GroupService.swift:325`) lanza `deleteDisabled` bajo
`#if !DEBUG` (`:326-327`) y, **aun en DEBUG**, exige `allowDestructiveDelete: true` (`:331`) y ser owner
(`:332`). ⇒ **desde TestFlight el owner solo puede VACIAR los grupos, no eliminarlos.**

Los cascarones vacíos los limpia `DataWipeService.wipeLocalGroupsDomain`
(`Yala/Utils/DataWipeService.swift:265-296`), que **ya existe y ya la usa el fix del handover**: borra las 5
entidades `Split*` (`:272-276`) y `GroupBridgePreference` (`:282`), pone el sello
`groupsDomainSealedForFreshStart` (`:295`) y **no toca `TransactionItem` ni `InboxDraft`** (verificado leyendo
la función entera). Reutilizarla cuesta cero líneas.

### 1.4 · Reintroducir los gastos, después

Al terminar la Fase 3 (canal backend como único canal) el owner recrea los grupos y reintroduce a mano los
gastos que le importen. No hay import: es entrada manual, y es la decisión consciente que sustituye al CSV.

---

## §2 · Riesgo aceptado explícitamente — decisión del owner del 2026-07-28

**El código no puede garantizar que nadie más tenga Grupos.** Verificado, y el owner lo asume a sabiendas:

| Puerta | Coordenada | Qué hace |
|---|---|---|
| Cualquier enlace CKShare | `Yala/App/Services/CKShareEntryHandler.swift:43` | `UserDefaults.standard.set(true, forKey: …groupsBetaUnlocked)` **sin ninguna condición** y permanente, para todo sub-modo de invitación. Su comentario lo declara: «quien llega por enlace de invitación queda desbloqueado sin código (decisión owner)» |
| Tarjeta «Solo grupos» del onboarding | `Yala/App/Views/Onboarding/OnboardingView.swift:1813` | El mismo `set(true…)`, explícito, «per-device, como CKShareEntryHandler hace al aceptar un enlace» |
| 11 semanas sin gate | tab en `23cc9730` (**2026-04-06**), gate en `d563a876` (**2026-06-21**) — las dos fechas verificadas con `git log` | Todo tester de esos builds pudo crear un grupo sin código beta |

**Decisión del owner, textual (2026-07-28):** «Sobre el acceso a beta, NADIE MÁS ACCEDIÓ, nunca enviamos
enlaces a nadie, nunca di el código beta a nadie. Si alguien logró sobrepasarlo no me importa, le eliminamos
todo, no hay impacto, son pocos usuarios.»

**Consecuencia asumida:** si aparece un tercero con grupos, sus datos quedan inalcanzables tras la Fase 4 y no
hay hotfix que los recupere. **Esto es lo que compraba la Fase 2 del plan viejo, y se cancela a conciencia.**
No se reintroduce sin una decisión nueva y fechada del owner.

---

## §3 · Las 5 fases

**Contrato común:** cada fase deja el árbol compilando y los tests verdes ⇒ **se puede parar en cualquier
frontera**. `qa/coverage-index.json` se actualiza **en el MISMO commit** que el código (`CLAUDE.md`) y se valida
con `bash qa/validate-coverage.sh`. Ninguna fase se cierra sin `/gate`, y hoy `/gate` está bloqueado (§5).

**Estado de verificación:** la Fase 1 está verificada línea a línea por tres frentes independientes más los
contrastes de esta reescritura. Las Fases 2–5 conservan las coordenadas del plan viejo: las comprobadas aquí van
marcadas ✅ y **el resto va marcado NO VERIFICADO y hay que re-medirlo al abrir la fase**.

---

### Fase 1 · Cerrar la puerta del servidor y matar la migración

**Objetivo:** eliminar la maquinaria de migración de grupos vivos, DARK y que nunca corrió en producción.
Riesgo bajo, con tres trampas que hay que respetar.

**Presupuesto medido:** **~3.845 líneas fuera en el cliente** (1.288 de producción + 2.077 de test + ~420 de
re-cableo + ~60 de canarios), **~4.535 contando gateway, DDL y QA** (~5 en `rpc.ts`, 209 de goldens, 140 de
DDL, 200 de `g6_01`, ~240 de README, coverage-index). Contra un techo de **+25 líneas de producción NUEVAS**:
la forma reducida del guard (trampa 1), el tombstone del DDL, el addendum de paridad y la migración de un
statement. **Si el diff acaba con más inserciones que borrados, algo va mal.**

**Pasos, en orden obligado:**

| # | Paso | Ficheros verificados | Por qué en esta posición |
|---|---|---|---|
| 1.1 | Cerrar el RPC en el gateway, en **commit propio** | `gateway/src/groups/rpc.ts` — `PARAM_ALLOWLIST` **`:53`** ✅, `RPC_NEEDS_ENC_KEY` **`:66`** ✅, doc de cabecera **`:6`** («11 RPCs» → 10). El 404 sale en **`:106-108`** ✅, antes de PostgREST | Con el gateway cerrado, un build antiguo recibe 404 en vez de tocar PostgREST y no entra en retry-loop. Commit propio porque `gateway/src/index.ts` tiene trabajo ajeno sin commitear |
| 1.2 | Preservar la cobertura del camino VIVO **antes** de cualquier `git rm` | `YalaTests/CloudSync/GroupPullRescueChannelTests.swift` — conservar la infra (`22-56`) y los **5 tests del suelo del corte del History** (`126-216`); borrar solo `58-125` y renombrar el suite | Esos 5 tests atan `CloudSyncEngine.deleteHistorySafeCut` a las anclas del canal de Grupos. Con 2.1 el backend es el ÚNICO canal ⇒ el invariante pasa a crítico. Borrar el fichero es regresión silenciosa |
| 1.3 | Editar los consumidores y borrar los 7 ficheros — **un commit atómico** | ver las dos tablas de abajo | No existe orden intermedio que compile: `GroupFetchQuiescenceGate` ↔ `SplitSyncManager.privateFetchGateSignal` (`198-216`) se referencian mutuamente, y `GroupCapability` vive DENTRO de `GroupCapabilityBeacon.swift:19-50` |
| 1.4 | Retirar canarios y breadcrumbs sin emisor | `Yala/Services/Metrics/MetricsService.swift` (`:93 :94 :102 :108 :117 :119`) · `Yala/Services/CloudSync/Groups/GroupsSyncBreadcrumb.swift` (`:176 :181 :187 :194 :210 :216 :222`) | Solo se sabe qué queda huérfano después de borrar los emisores |
| 1.5 | **REDUCIR** (no borrar) el área del coverage-index | `qa/coverage-index.json` **`2420-2455`** ✅ — 26 `codeGlobs` ✅, de los que **8 apuntan a ficheros que sobreviven** | Mismo commit que el código. El área es `classification: manual` ✅ y `backlogBaseline: 0` ✅ ⇒ el ratchet no se dispara, pero `_meta.counts` (hoy `total 134 / manual 58` ✅) hay que tocarlo a mano |
| 1.6 | Dejar **escritos, sin ejecutar**, los pasos de despliegue | `qa/cloud/g6_02_drop_migrate_group.sql` (nuevo, 1 statement) + los borrados de `supabase-groups-staging.ddl` **`1190-1329`** ✅, `qa/cloud/g6_01_migrate_group.sql` (**200** ✅), goldens **`640-848`** ✅, `qa/cloud/README.md` **`386-419`** ✅ / `:544` / `:561` ✅ | El `drop function` va después del gateway y del cliente. El bloque G6 de los goldens hay que arreglarlo **en el commit del paso 1.1**, no al final (trampa 3) |

**Ficheros de producción del paso 1.3 — verificados uno a uno con `wc -l`:**

| Fichero | Líneas |
|---|---|
| `Yala/Services/CloudSync/Groups/GroupMigrationUploader.swift` | 537 |
| `Yala/App/Logic/GroupPullRescueGate.swift` | 181 |
| `Yala/App/Logic/GroupFetchQuiescenceGate.swift` | 178 |
| `Yala/Services/CloudSync/Groups/GroupCapabilityBeacon.swift` | 132 |
| `Yala/App/Logic/GroupMigrationReadinessLogic.swift` | 106 |
| `Yala/Services/CloudSync/Groups/GroupMigrationPayloadBuilder.swift` | 103 |
| `Yala/Services/CloudSync/Groups/GroupMigrationProgress.swift` | 51 |
| **subtotal** | **1.288** |

Más 11 ficheros de test (**2.293** líneas exactas, de las que 216 son el fichero recortado del paso 1.2) y los
re-cableos:

| Fichero | Rangos verificados |
|---|---|
| `Yala/App/AppBootstrapper.swift` | **`417-431`** (beacon: comentario `417-422`, `if` en `:423`, llamada en `:429`) ✅ y **`433-454`** (uploader: comentario `433-438`, `if` en `:439`, `reconcileMarkers` `:451`, `run()` `:452`) ✅ |
| `Yala/App/Views/Groups/GroupsContainerView.swift` | `:40` (`@State migrationProgress`), `74-103` (los 2 banners) |
| `Yala/App/Views/Groups/GroupSettingsView.swift` | `113-118`, `665-717` |
| `Yala/Services/Groups/SplitSyncManager.swift` | `:182`, `:186`, `188-216`, `1808-1820`, **`1843-1877`** (ver trampa 1), `1949-1955`, `2027-2029`, `2344-2362`, **`2542-2617`** (ver trampa 2) |
| `Yala/Services/CloudSync/Groups/GroupsSyncClient.swift` | `751-852` (seed; `enqueueSnapshotRows` en **`:767`** ✅), `1426-1457` (`backendPullSignal` en **`:1444`** ✅), `1761-1772` (`migrationInFlight` en **`:1769-1770`** ✅), `2151-2155` (`liveGroupOutboxCount` en **`:2153`** ✅ — el privado `liveOutboxCount` de **`:2146`** ✅ **sobrevive**, lo usa el Merkle) |
| `Yala/Services/CloudSync/Groups/GroupBackendMembershipService.swift` | `150-155` (`func migrateGroup` en **`:152`** ✅) |
| `Yala/Services/CloudSync/Groups/GroupsMembershipClient.swift` | `102-115` (`MigrateGroupResult` en **`:104`** ✅) y `353-369` (`func migrateGroup` en **`:358`** ✅) |

**Las tres trampas (aplicar el plan viejo literal rompe algo):**

1. **`SplitSyncManager:1843-1877` MEZCLA código muerto y código VIVO.** El `if backendZoneNames.contains(…)` de
   **`:1851`** ✅ es el **guard de PULL de G6-3 (C2)**, no el rescate C-4. Se **conserva** en su forma reducida
   (`breadcrumb; continue`) y su gemelo de deletions (`:1936`) **no se toca**. Con 2.1 todo ON y el transporte
   vivo hasta la Fase 3, borrarlo abre una ventana en la que un record CloudKit stale pisa la verdad del
   backend y se bridgea al store personal. **No falla al compilar y no lo caza ningún test.**
2. **El final del bloque de helpers es `:2617`, no `:2626`.** ✅ `applyRemoteRecordIfAbsent` termina en `:2616`
   y `applyGroupMeta` (VIVO) empieza en **`:2619`** ✅; su captura de `wasHidden` (`:2624`) ✅ alimenta
   `pendingFreezeZoneIDs` (`:2628`, `:2644`) ✅ y por tanto el `freezeForSoftDelete` de `:1979`.
3. **El describe G10 de los goldens depende del bloque G6.** ✅ `setupGroupWithRebind` (**`:673`**, que **llama**
   `migrate_group` en **`:682`**), `readMember` (**`:666`**) y `LEGACY_PIA` (**`:659`**) están definidos dentro
   del bloque G6 y los usa el describe G10 (**`:928-994`**, con `:963` y `:976`). Borrar `640-848` en bloque
   **no compila**, y el paso 1.1 ya pone rojo el golden G10 nº 2. **Decisión pendiente del owner** antes de
   escribir el commit: (a) borrar ese golden y anotar la pérdida de cobertura de `no_eligible_owner`, (b) no
   dropear la función y quedarse solo con la puerta cerrada, (c) sembrar el placeholder `user_id NULL` por
   `execute_sql`.

**Excepción a declarar, no a ocultar:** el bloque del beacon corre **fuera** del gate del flag en toda
producción, y su `guard await awaitPersonalStoreReady()` (`AppBootstrapper.swift:425`) pasa por el gate de
boot-save del store personal. Borrarlo baja de 12 a 11 los consumidores del contador persistido
`bootSaveDeferCount` ⇒ el canario `cloudBootSaveDeferredRepeatedly` puede bajar de frecuencia. El cambio es
benigno, pero **la rama `.icloud` no queda byte-idéntica** y hay que decirlo en el mensaje del commit.

**Criterio de hecho:** `grep -rn "migrate_group\|migrateGroup" Yala/ gateway/src/` → **0** ·
`grep -rn` de los 7 símbolos borrados en `Yala/` → **0** ·
`grep -n backendZoneNames Yala/Services/Groups/SplitSyncManager.swift` → **≥3** (el guard vive) ·
`grep -n processRemoteChanges …SplitSyncManager.swift` → **1** (`:2039`) ·
`bash qa/validate-coverage.sh` → `RESULT: OK`, `Areas: 133` · `YalaTests` verde · **las dos schemes** verdes.

**Commits:** **2** (1 gateway + 1 cliente). Los despliegues **no se ejecutan**: quedan escritos para el owner.
**Se puede parar aquí:** sí, y es el mejor sitio para parar. ~3.845 líneas fuera con riesgo bajo.

---

### Fase 2 · Los 7 re-cableos — 7 commits, uno por pieza

**Objetivo:** que el canal backend haga todo lo que hoy hace el transporte, **antes** de borrarlo. Ésta es la
fase del trabajo real; las otras cuatro son mecánicas.

| # | Re-cableo | Ficheros | Verificación |
|---|---|---|---|
| 2.1 | Notificaciones de grupo: `GroupNotificationService.processRemoteChanges` al apply del backend | callsite único hoy **`SplitSyncManager.swift:2039`** ✅ · destino `GroupsSyncClient.swift` (el bridge del backend está en **`:1937`** y **`:1945`** ✅ — el plan viejo decía `:1903`/`:1911`: drift) | `GroupNotificationServiceTests` + QA en sim: gasto ajeno ⇒ notificación |
| 2.2 | Notificaciones de miembro: `MemberChangeNotificationLogic` | `SplitSyncManager.swift` `1828-1837` (baseline) y `:1909` (clasificación) — **NO VERIFICADO** | `GroupNotificationRecipientLogicTests` |
| 2.3 | Freeze en soft-delete remoto: disparar `freezeForSoftDelete` desde el apply del backend | detección hoy en `applyGroupMeta` **`:2628`** y **`:2644`** ✅, drenaje en **`:1971-1985`** ✅ (`freezeForSoftDelete` en `:1979`). **La coordenada `:1868` del plan viejo era FALSA** | `GroupTransactionBridgeSoftDeleteTests` |
| 2.4 | Consultas SwiftData: mover a `GroupService` preservando el `#Predicate` concreto (fix `c74349fc`) | `SplitSyncManager.swift` `900-1063` (incl. `accountDeletionGroupsSummary` en **`:998`** ✅) y `2809-2860` — rangos **NO VERIFICADOS** · 8 consumidores, incl. `GroupBackendInviteEntryHandler.swift:87` (canal nuevo) | `AccountDeletionGroupsSummaryTests` + build |
| 2.5 | `syncNow` de la lista y del detalle → drain del backend | `GroupsViewModel.swift:201`, `GroupDetailViewModel.swift:133` — **NO VERIFICADO** | QA en sim: pull-to-refresh en lista y detalle |
| 2.6 | **Identidad del miembro — COMMIT AISLADO, sin nada más** | `GroupService.refreshCurrentUserFlags` (`983-1130`), `GroupExpenseService.selectCurrentUserMemberID` (`620-629`), `GroupJoinReconciler.swift:284`, `GroupSettingsView.swift:698` — **NO VERIFICADOS** · **extraer `GroupsIdentityPurgeGate.belongsToBackendChannel` ANTES**: 2 callsites vivos en `GroupService.swift:1043` y **`:1083`** ✅ (el plan viejo decía `:1034`/`:1074`) | `GroupBalanceServiceTests` + `GroupExpenseServiceCurrentMemberTests` + QA en sim de **quién ve qué balance** |
| 2.7 | Seam del handover: repuntar `resetSyncState` de `DataWipeService.swift:268` ✅ a `CloudSessionSignOut.purgeGroupsSyncState` (**`:591`** ✅) | 1 línea + docblock + 1 test | `HandoverGroupsDomainTests` |

**Por qué este orden:** los cuatro primeros son los **apagones silenciosos** — ninguno falla al compilar, así
que van con su test **antes** de que la Fase 3 borre su emisor. 2.6 es el trozo de más riesgo del plan entero
(decide quién ve qué balance) y **no comparte commit con nada**. 2.7 va al final porque cierra un agujero que
el giro activa: `GroupSyncCursor` y `GroupSyncOutbox` viven en `syncMetaSchema`, un store que el wipe no toca,
así que un «empiezo de cero» dejaría vivos el cursor y el outbox del usuario anterior.

**Cosa que NO se hace aquí (corrección del plan viejo):** no añadir `freezeForSoftDelete` a
`wipeLocalGroupsDomain`. La premisa de que deja transacciones huérfanas es falsa en sus dos callsites reales
(llaman `wipeAllUserData` inmediatamente antes) y rompería el test que pinnea lo contrario,
`HandoverGroupsDomainTests.wipeLocalGroupsDomain_leavesPersonalCorpusAlone`.

**Regla dura:** ningún borrado de la Fase 3 entra sin que su re-cableo de la Fase 2 esté verde y commiteado.
**Se puede parar aquí:** sí, en cualquier frontera entre los 7. El transporte sigue vivo y solo queda lógica
duplicada temporalmente — estado estable.
**Requisito de salida:** reescribir el plan de rollback (§6) **antes** de abrir la Fase 3.

---

### Fase 3 · El bloque grande — 2 commits

**Objetivo:** borrar el transporte CloudKit de Grupos.

**Commit 1 (producción).** Ficheros enteros — cifras del plan viejo, **NO RE-VERIFICADAS** salvo donde se
indica: `SplitSyncManager.swift` (**2.905** ✅), `CKRecordTranslator.swift` (437), `SplitZoneManager.swift`
(**308** ✅; `deleteZone` en **`:58`** ✅, el único código del repo que sabe borrar una zona de grupos),
`SplitSyncStartGate.swift` (292), `GroupsIdentityPurgeGate.swift` (263 — **su `belongsToBackendChannel` ya se
extrajo en 2.6**), `CKShareEntryHandler.swift` (151), `CloudKitConstants.swift` (150),
`PendingInviteStore.swift` (92), `GroupUserIdentityService.swift` (88 — **conservar `deterministicUUID` y
`cachedRecordName`**: los usa el canal backend), `PendingLeaveShareTracker.swift` (68),
`GroupsICloudUnavailableView.swift` + `GroupsICloudAvailabilityGateLogic.swift` (94),
`GroupsIdentityBootGuardLogic.swift` (44).

Más los recortes: `GroupService.propagateBoolCustomKey` (**`:236`** ✅) con sus **4** callsites ✅
(`GroupService:228`, `:308`, `SplitSyncManager:2320`, `:2326`) — obligatorio, es el único write a
`privateCloudDatabase` que no pasa por `CKSyncEngine`; los callsites de `enqueueSave` fuera del fichero; la
parte CloudKit de `InviteLinkService` (**conservar** `buildBackendInviteURL` y `extractBackendInvite`, y
reescribir el guard de `AppBootstrapper` que usa `extractShareURL` como validez de *cualquier* link); y los
canarios y breadcrumbs que quedan sin emisor.

**Commit 2 (tests y coverage).** Los 10 ficheros de test del transporte (~2.042, **NO VERIFICADO**) +
`qa/coverage-index.json` + `_meta.counts`.

**Por qué este orden:** producción primero deja al compilador señalando exactamente qué test hay que tocar; al
revés son N errores encadenados. Y los dos commits van **después** de la Fase 2 completa porque los cuatro
apagones silenciosos no fallan al compilar: aquí es donde el error se vuelve invisible.

**Criterio de hecho:** `grep -r "import CloudKit" Yala/Services/Groups/ Yala/App/Views/Groups/` → **0** ·
`/gate` completo · QA en simulador del recorrido entero por el canal backend: crear, invitar, unirse, gasto,
liquidación, salir, archivar.
**Se puede parar aquí:** sí, y **es el estado final útil**. Las Fases 4 y 5 son limpieza.

---

### Fase 4 · Schema y entitlements — 2 commits. **La única irreversible.**

**Objetivo:** retirar el contrato de un schema que nadie usará.

**Commit 1 (schema).** Los campos del marcador de `Yala/Models/SplitGroup.swift` ✅ — `movedToBackendAt`
(**`:61`**), `backendReInviteToken` (**`:67`**), `markerEnqueuedFlag` (**`:74`**), `rejoinRevokedAt`
(**`:87`**) — más `SplitMember.clientCapability` (**`:63`**) y `clientCapabilityAt` (**`:68`**) ✅, sus field
keys en `CloudKitConstants.swift`, la traducción en `CKRecordTranslator.swift`, los **4** `.ckdb`
(`Cloudkit Schemas/groups-development.ckdb`, `groups-production.ckdb`, `groups_dev-development.ckdb`,
`groups_dev-production.ckdb`, **136 líneas cada uno = 544** ✅) y `CloudKitGroupsSchemaParityTests`.

**Aquí muere también todo lo que sobrevivió a la Fase 1 colgando del marcador:** `GroupFreezeLogic.isFrozen`
(**`111-120`** ✅) y `SplitGroup.isMigratedFrozen` (`17-24`), `GroupBackendCapability` (**`48-81`** ✅, doc desde
`:41` ✅), `GroupMigrationState` (**`85-94`** ✅, doc desde `:83` ✅), `GroupFreezeLogic.migrationState`
(**`134-153`** ✅, doc desde `:122` ✅), las **19 keys** del universo migrado (**15** `groups.migrated.*` ✅
presentes en los **16** `.lproj` ✅ + **3** `groups.card.moved*` ✅ + `groups.errors.movedToBackend`) y el
`enum Migrated` de `Yala/Utils/L10n.swift:1953` ✅. **Ninguna está en `.stringsdict`** ⇒ no aplica la trampa
de precedencia.

**No se toca `L10n.Groups.SignIn.retryLater`**: es del sign-in del backend, camino VIVO.

> **Decisión de alcance que evita tocar 6 vistas dos veces:** la presentación del estado migrado
> (`GroupMigrationState`, `GroupBackendCapability`, las 19 keys, las 6 vistas) va **en este commit**, junto con
> `movedToBackendAt`, y **no** en la Fase 1. Tras la Fase 1 nada escribe el marcador ⇒ toda esa presentación
> queda demostrablemente inalcanzable y aquí es puro borrado sin re-cableo. Colapsarla a un `Bool` en la Fase 1
> para borrar el `Bool` después es exactamente el patrón que costó el 4,5× de la tanda anterior.

**Consecuencia a anotar en la Fase 1, no aquí:** `isFrozen` sobrevive a la Fase 1 y sus únicos tests viven
dentro de `GroupMigrationStateTests.swift` (el invariante `isFrozen_unchanged_byCapability`), que la Fase 1
borra. **Se decide por escrito en la Fase 1**: o se rescatan ~30 líneas, o se declara que `isFrozen` queda sin
cobertura hasta que muera aquí. No dejarlo implícito.

**Commit 2 (entitlements) — AL FINAL DE TODO.** Quitar `iCloud.com.jurgenschmidt.yala.groups` y `.groups.dev`
de `com.apple.developer.icloud-container-identifiers` en `Yala/App/Yala-Release.entitlements` (**`:24-25`** ✅)
y `Yala/App/Yala-Debug.entitlements` (**`:19-20`** ✅). **No tocar** el container personal
(`iCloud.com.jurgenschmidt.yala` / `.dev`, presentes también en la lista de ubiquity KV: `Release:34-35`,
`Debug:29-30` ✅), ni `aps-environment`, ni `applesignin`.

**Por qué los entitlements van al final:** retirarlos antes deja el container privado de grupos **inalcanzable
para siempre**, incluso para un hotfix. Después de este commit ya no hay forma de leer esas zonas, y el owner
decidió no vaciarlas (§4).

**Criterio de hecho:** `/gate` + build de release firmado + revisar el `.ipa` para confirmar que el entitlement
de grupos desapareció y el personal sigue.
**Punto de no retorno:** el commit 2.

---

### Fase 5 · Limpieza de staging — 1 commit

**Objetivo:** que la base de staging no quede con tokens de unión funcionales colgando.

| Qué | Cómo |
|---|---|
| Concepto `legacy_member_key` en el cliente (~110 líneas): `GroupBackendIdentityLogic.isLegacyMemberKey`, la rama de namespace de `GroupsSyncClient` (la zona de `migrationInFlight`, `1761-1772` ✅), `PendingJoinEntry.legacyMemberKey`, `GroupBackendInviteEntryHandler.legacyMemberKeyForRejoin` — **NO VERIFICADOS** | Sin migración, todo `member_key` es el `sub`. Cierra el riesgo R10 del diseño |
| Las invitaciones de grupo **vivas** en staging (no revocadas, no expiradas) y los grupos sintéticos de los goldens | `groups_forget_user`, **nunca `DELETE` a mano** (`DELETE` está revocado por diseño). Las cifras del plan viejo (34 invitaciones, 590 grupos) están **NO VERIFICADAS**: contarlas al abrir la fase |
| **NO se toca:** la rama REBIND de `join_group` con `p_legacy_member_key` | Quitar el 4º argumento exige `drop+recreate` de **la función que usa TODO invitado**, en producción, y re-verificar la paridad md5. Se deja vestigial y el cliente simplemente no la envía |
| **NO se toca:** retipar `member_key` a `uuid` | `group_capability_manifest.json` es append-only por contrato e invalidaría `groups_merkle_fixtures.json` y el canon c1 en dos lenguajes. Beneficio cosmético |

**Se puede parar aquí:** esta fase es enteramente opcional. Si no se hace, lo único que queda es residuo en
staging.

---

## §4 · Lo que ya no se hace, y por qué (para que nadie lo reintroduzca)

| Cancelado | Por qué | Qué NO hay que volver a proponer |
|---|---|---|
| **Export CSV de los grupos** (era la Fase 0: 2 CSV + confirmación escrita) | Decisión del owner: «siento que lo del CSV es innecesario». Y la fila de Exportar estaba **oculta en modo solo-grupos**, el de Pia ⇒ ni estaba disponible | Ningún paso de export, ninguna llamada a `GroupsExportBuilder`, ninguna instrucción de desarchivar grupos para que salgan en el CSV. **`GroupsExportBuilder` se queda intacto en el código**: no es de este plan |
| **La red de seguridad** (~61 líneas: `isFrozen` a `!isBackendGroup` + hoja one-shot de aviso y export) | Decisión del owner del 2026-07-28, con el riesgo aceptado por escrito en §2 | No repuntar el predicado de `GroupFreezeLogic.isFrozen` (`:111-120`). No añadir hojas de aviso. **Si alguien lo reabre necesita una decisión nueva y fechada del owner**, no una inferencia de «esto es más seguro» |
| **Desprender las transacciones bridgeadas** (~10 líneas poniendo a `nil` `splitExpenseID` / `splitGroupZoneID` / `splitSettlementID`) | Innecesario: borrar el gasto en el grupo ya se lleva la `TransactionItem` (`GroupTransactionBridge.swift:1201`). El owner borra a mano y reintroduce | No escribir código de desprendimiento. **Y no añadir `freezeForSoftDelete` a `wipeLocalGroupsDomain`**: rompería `HandoverGroupsDomainTests.wipeLocalGroupsDomain_leavesPersonalCorpusAlone` |
| **Andamiaje de rollout escalonado**: rampas por %, gates parciales, flag propio para escalonar el muro, C-10 entero | `MODO-NUBE-DECISION-RELEASE-2.1.md`: todo ON en 2.1, TestFlight primero. Con **dos** usuarios reales, «coordinar el build» es un mensaje de WhatsApp | Ningún flag de rollout nuevo. Ninguna lógica de «miembro rezagado». C-10 muere entero en la Fase 4 |
| **Vaciar el container privado de iCloud** (~30 líneas de borrador one-shot con `CKModifyRecordZonesOperation`) | No vale código nuevo con acceso destructivo a CloudKit por higiene invisible | No escribir el borrador. Consecuencia asumida: tras la Fase 4 esas zonas son inalcanzables para siempre |
| **El deploy pendiente de `SplitMember.clientCapability` / `clientCapabilityAt` a CloudKit Production** | Los 2 field keys mueren en la Fase 4 | **CANCELADO, no aplazado.** Que nadie lo despliegue por inercia porque figuraba en una lista de pendientes |
| **D-A4** (migrar cualquier miembro), **D-A5** (`claim_group_ownership`, confirmado no construido: 0 líneas), **D-A6** + DIFERIDOS #38, el período de convivencia con grupos congelados, el guion device de G6 | Sin migración no hay nada que migrar | — |

---

## §5 · No hay bloqueo — y la lección de medición que casi lo inventa

`/gate` exige **las dos** schemes, `Yala` y `Yala Dev` (`.claude/commands/gate.md:22-29`, verificado: «`Yala
Dev` compila con `DEV_BUILD` y `Debug-Dev` y ha ocultado errores que solo salían en producción»).

**Estado real, verificado el 2026-07-28 a las 08:49: `Yala Dev` COMPILA.** `BUILD SUCCEEDED` sobre `HEAD
ed38c1ea`. El brief con el que se escribió este plan decía lo contrario y **estaba equivocado**; el propio
verificador hizo bien en marcarlo como NO VERIFICADO en vez de propagarlo.

**Por qué importa dejarlo escrito, y no solo corregirlo.** Horas antes, dos builds de `Yala Dev` habían fallado
en `Yala/App/Views/Import/ImportIntroSheet.swift:370` con
`requires that 'Category' conform to 'Hashable'`, `cannot conform to 'SortComparator'` y `cannot infer type of
closure parameter`. De ahí se concluyó que la branch estaba rota. **No lo estaba:** el código era byte-idéntico
(`git diff` vacío, cero commits nuevos), DerivedData no se recreó (creado el 14 de julio), y el disco tenía
64 GB libres. Lo único distinto era la **carga de la máquina**: dos workflows con decenas de agentes y builds
concurrentes. Esa terna de errores es la firma de un **timeout del type-checker** en una expresión compleja —y
`Dictionary(grouping:)` + `compactMap` + `sorted` lo es—, no de un defecto de tipos.

⇒ **Regla para quien ejecute cualquier fase de este plan:** ante errores de inferencia en una expresión
encadenada, **mira la carga de la máquina antes que el código**. Es el mismo principio que CLAUDE.md ya fija
(«antes de culpar al código, mira el entorno») y que aquí costó horas de diagnóstico en falso. Corolario
operativo: **no correr `/gate` con workflows o otras sesiones compilando en paralelo** — un rojo falso es peor
que no medir, porque manda a alguien a cazar un bug inexistente.

Si aun así una fase se topa con un rojo que no puede atribuir a carga: implementarla completa, correr lo que sí
se pueda y dejar el trabajo **staged, sin commit**, con nota explícita. Y **no arreglar de paso** nada ajeno a
la fase: mezclar frentes es el patrón de sobre-alcance que este plan existe para cortar.

**Mecánica del sello:** no lo comprueba ningún hook de git (`.git/hooks/` solo tiene `pre-push`, que valida el
coverage-index; `core.hooksPath` está vacío). Lo comprueba un hook `PreToolUse` de `git commit`
(`gate.md:85`) ⇒ un commit por otra vía no lo verifica.

---

## §6 · El plan de rollback, reescrito. **Va ANTES de la Fase 3.**

**Hoy:** apagar `groupsBackendEnabled` en remoto devuelve Grupos al canal CloudKit. Es un kill-switch real, de
segundos, sin build nuevo.

**Tras la Fase 3:** apagarlo deja Grupos **sin ningún canal**. El flag remoto solo puede MATAR, nunca encender
(`CloudSyncFlags.swift:257-262` compone «compilado && remoto»), así que apagarlo con el transporte ya borrado
significa que la app se queda sin ninguna vía de sync de grupos.

| | Antes de la Fase 3 | Después de la Fase 3 |
|---|---|---|
| **Mecanismo** | flag remoto `groupsBackendEnabled` → OFF | **revertir el build** (revert de los commits + release nueva por TestFlight) |
| **Tiempo** | segundos | horas o días |
| **Alcance de la vuelta** | inmediata y por device | ~40 ficheros + 4 `.ckdb` + re-deploy de schema a CloudKit Production + change tokens ya descartados |
| **¿Sirve de hotfix?** | sí | **no** |

**Acción concreta, y es requisito de entrada de la Fase 3: HECHA (2026-07-29)** → **[[MODO-NUBE-ROLLBACK]]**,
runbook propio con los commits exactos de las Fases 1 y 2, en orden de revert. Vive fuera de este plan a
propósito: se consulta en pánico, y un §6 dentro de un documento de 38 KB no se encuentra en una emergencia.
Su §5 obliga a anotar los 2 commits de la Fase 3 **en el mismo commit que los crea**.

**Lo que la escritura del runbook destapó, y este §6 no contemplaba:** «revertir el build» **no** es
suficiente, porque tres de los efectos vivos de la Fase 1 **no viven en git** — el 404 de `migrate_group` está
activo por un **deploy** del Worker, el revoke por **SQL ejecutado a mano** en los dos entornos, y la migración
de D1 no tiene `down`. Revertir `21dcd465` y `45c32a41` deja el código como estaba y la puerta igual de
cerrada: hace falta re-desplegar y volver a otorgar el `EXECUTE`. ⇒ **revertir la Fase 1 en git NO reabre la
migración de grupos.**

**Y el riesgo que domina el rollback desde 2.1:** un grupo **born-backend nunca tuvo zona CloudKit**, así que
un build sin canal backend no puede verlo por ninguna vía. No es pérdida de datos —siguen en Supabase— sino
de ACCESO, hasta que vuelva a haber un build con el canal. Hoy no afecta a nadie porque
`groupsBackendCompiledDefault` es `false`; pasa a ser el coste real del rollback el día que se encienda.

**Matiz que hay que respetar:** el flag remoto **sigue siendo útil** después de la Fase 3, pero para otra cosa —
apagar el canal backend a sabiendas de que Grupos queda inoperativo, no para volver a CloudKit. Documentarlo así
o se lee como un rollback que no es.

---

## §7 · Lo que este plan NO toca

| Asunto | Estado | Evidencia |
|---|---|---|
| **Store PERSONAL y su sync iCloud** | Intacto. Grupos vive en un container distinto y su store monta `cloudKitDatabase: .none` | `Yala/App/Yala-Release.entitlements:22-25` ✅ · `SwiftDataConfiguration.swift:720-751` (**NO VERIFICADO**) |
| **Migración personal iCloud → nube** | Intacta, y ahora opt-in silencioso. **Otro frente** | `MODO-NUBE-DECISION-RELEASE-2.1.md` |
| **La no-regresión de 2.x** | Más importante que antes: con opt-in silencioso casi todos se quedan en `.icloud`. **El criterio es el diff, no la intuición** | Ninguna fase puede tocar `CloudSyncEngine`, `MigrationRunner*`, `PreferenceSyncService`, `StorageMode*`, `iCloudSyncService`, `DataWipeService`, `CloudSessionSignOut` (excepción auditada: 2.7 toca 1 línea de `DataWipeService` a propósito) |
| **El bridge, los balances, los 5 modelos `Split*`, pagos planificados de grupo, Inbox → grupo, export** | Intactos. `GroupTransactionBridge.swift` (**1.378** ✅) tiene cero dependencias de código del transporte | `unbridgeExpense` en **`:1201`** ✅ es el mecanismo del §1 |
| **`CloudSyncEngine.deleteHistorySafeCut` y sus anclas del canal de Grupos** | **Se quedan**, aunque nacieron con el rescate: son correctness del canal que sobrevive. Sin ellas el pruning personal se come la transacción de una fila del outbox de Grupos | Cubiertas por los 5 tests que la Fase 1 conserva (paso 1.2) |
| **Las 45 migraciones aplicadas en Supabase** | El historial es append-only. La retirada es una migración **nueva** con `drop function`, no un revert. **No se editan** | `g7_02:415-417`, `:911`, `:924` · `g8_01:14` · `g10_01:45` mencionan `migrate_group` legítimamente ⇒ un `grep` repo-wide **nunca** dará 0 |
| **`group_capability_manifest.json`, `groups_merkle_fixtures.json`, `gateway/README.md`, `gateway/src/index.ts`** | **0 hits** de `migrate_group` ✅ ⇒ no se tocan (corrige una premisa del plan viejo) | — |

---

## Apéndice · Los tres números para llevarse

1. **5 fases, 14 commits, techo de producción nueva ≈ 0.** El plan viejo tenía 6 fases + Fase 0 y ~71 líneas de
   producción nueva; las dos fases que desaparecen eran justamente las dos que las escribían.
2. **La Fase 1 sola son ~3.845 líneas fuera con riesgo bajo** (~4.535 con gateway, DDL y QA), contra un techo
   de +25 de producción nueva. Si solo se hace una fase, es ésa.
3. **Los 7 re-cableos de la Fase 2 son el trabajo real.** Todo lo demás es `git rm` — y cuatro de esos siete se
   apagan **sin fallar al compilar**, que es por qué van antes del bloque grande y con su test cada uno.
