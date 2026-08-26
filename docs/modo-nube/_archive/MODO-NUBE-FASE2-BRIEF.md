---
created: 2026-07-28
updated: 2026-07-29
tags: [modo-nube, grupos, fase2, brief]
status: in-progress
---

# Fase 2 — brief ejecutable, con las coordenadas re-medidas contra HEAD

## ESTADO — 2.1 a 2.5 HECHOS (2026-07-29)

Cinco commits en `2.0.5`, subidos. Cada uno deja el árbol compilando, sus tests verdes y
`qa/coverage-index.json` actualizado en el MISMO commit; `/gate` corrido antes de cada uno.

| Pieza | Commit |
|---|---|
| 2.1 · notificaciones de grupo | `bed60a92` |
| 2.2 · notificaciones de miembro | `ba95f62a` |
| 2.3 · freeze en soft-delete | `4a51d9c0` |
| 2.4 · consultas SwiftData → `GroupService` | `632c951f` |
| 2.5 · `syncNow` → drain del backend | `c3aee764` |

| 2.6 · identidad del miembro | `8e666074` (helper) + `08298365` (fix) |

| 2.7 · seam del handover | ver la ⚠️ de su sección: el plan prescribía lo contrario |

**FASE 2 COMPLETA.** Las 7 piezas re-cableadas, cada una con el árbol compilando y sus tests verdes.

**2.6 validado en las DOS Macs (2026-07-29).** Escrito con SDK 26.5, verificado además con **SDK 27.0**:
build `Yala` + `Yala Dev` SUCCEEDED sin warnings en los ficheros tocados, 68 tests de identidad/balance
verdes y `GroupsSmokeUITests` **8/8 en iOS 27.0** (172 s, ocho casos ejecutados). Las dos reglas de
identidad de `.claude/rules/swiftdata-cloudkit.md` se preservan; el hallazgo real de la pieza fue que la
rama por `sub` de `refreshCurrentUserFlags` era **inalcanzable** porque el guard C-3 saltaba los grupos
backend enteros.

**Dos precisiones sobre lo reportado**, para que no se hereden como ciertas:
- La tabla de `belongsToBackendChannel` no se «mudó» de suite: `GroupsIdentityPurgeGateTests` nunca la
  llamaba directamente (la ejercitaba vía `decideForZone`) ⇒ se **añadió** cobertura que no existía y el
  gate no perdió nada.
- «Flag OFF ⇒ byte-idéntico» es exacto en `refreshCurrentUserFlags` y `selectCurrentUserMemberID`, pero
  **no** en los otros dos: `GroupJoinReconciler.currentUserMemberExists` añade el criterio del record-name
  en los triggers que iban por la rama sin contexto, y `GroupSettingsView.hasOutstandingBalance` cambia a
  la resolución canónica con `min(by: joinedAt)`. Ambas desviaciones son intencionales, están en sus
  docblocks y van al lado conservador (pisar menos displayNames · bloquear un borrado antes que permitirlo),
  pero son cambio de comportamiento en producción HOY, no inercia.

**El gap del test unitario está CERRADO** (2026-07-29, misma tanda). Se declaró creyendo que hacía falta
un seam en `CloudAuthService`; no hacía falta: `GroupService.backendUserIDProvider` copia el molde de
`GroupJoinReconciler.backendUserIDProvider`, que ya existía por la misma razón, y el record-name ya tenía
`_testSetCachedRecordName`. `YalaTests/GroupServiceCurrentUserFlagsTests` cubre las 4 decisiones con su
contra-caso + 3 casos de inercia con flag OFF, y está **verificado por mutación** (3 mutantes: el salto
C-3 incondicional tumba 4 tests; quitar cada guard tumba exactamente su test, exit 65). Hueco restante
consciente: el 3er guard (sin record-name resuelto NO apagar `isCurrentUser` en los grupos CloudKit) exige
que el fetch a CKContainer falle, lo que ataría el unit test a la red.

**Suite unitaria completa: 5.198 tests en 481 suites, verde** (scheme `Yala Dev`). 18 tests nuevos:
16 en `GroupsSyncClientTests` y 2 en `GroupsSyncClientPushTests`. 2.5 verificado además en el
simulador (pull-to-refresh en lista y detalle).

### Lo único que la re-medición encontró mal, y sirve para 2.6

- **2.4, bloque de consultas: `837–1000`**, no `900–1063`.
- **2.4, segundo rango `2809-2860` YA NO EXISTÍA** — el fichero se quedó en 2.658 líneas tras la
  Fase 1. Lo que el plan describía son los helpers by-ID, hoy en `2562–2598`. No se movieron: son
  `private`, solo los usa `buildRecord` y mueren con el fichero. Tampoco se movió
  `backendGroupZoneNames` (solo el guard de pull del transporte).
- **El «8» son 8 FICHEROS de producción, no 8 consumidores.** Los callsites reales del bloque son
  13, más 8 internos y 1 de test. Enumerar por bloque, como avisaba el §2b, era lo correcto.
- **Las coordenadas de 2.1, 2.2, 2.3 y 2.5 estaban exactas al número.** La heurística del §0 se
  cumplió: solo derivaron las de `SplitSyncManager.swift`. **Aviso para 2.6: ese fichero volvió a
  moverse (2.658 → 2.521), así que sus coordenadas hay que re-medirlas otra vez.**

### Diferencia consciente con el canal CloudKit (2.2)

El baseline de primer import lo arma `applyGroupMeta` born-remote y lo CIERRA `pullUntilExhausted`
al agotarse con deltas, que es el gemelo de `didFetchRecordZoneChanges`. El grupo que crea el
propio usuario no pasa por ahí (lo materializa `GroupBackendMembershipService` server-first), así
que el creador no sufre la supresión.

### Tres cosas reportadas, no arregladas (chips abiertos)

1. **`SplitSyncManager.groupName(for:)` está muerto** — cero consumidores en todo el repo.
2. **Dos tests rojos SOLO con el scheme `Yala`** (`config_isConfigured_inTestScheme`,
   `secondaryEntry_killedByRemoteOff`): config de backend ausente. Preexistente, verificado con
   `git stash`.
3. **Dos XCUITest flaky al encadenar suites** (`GroupsRetention`, `GroupsSmoke`): verdes aisladas,
   rojas en cadena. La de retención, preexistente demostrada. Durante esa corrida el disco estaba
   en 22 GB, bajo el umbral de 25 — la causa que CLAUDE.md manda descartar antes que el código.

> **Para qué existe.** El plan ([[MODO-NUBE-PLAN-SIMPLIFICACION-GRUPOS]] §3) marca las coordenadas de las Fases 2–5 como **NO VERIFICADAS** y obliga a re-medirlas al abrir la fase. Aquí están medidas contra HEAD el 2026-07-28, **después** de que la Fase 1 borrara 4.418 líneas. Sin esto se trabaja sobre números que ya no existen: en la Fase 1, tres coordenadas del brief estaban desplazadas y costaron búsquedas a mano.

## 0 · Lo que cambió desde que se escribió el plan

- **La Fase 1 aterrizó** (`21dcd465` gateway + `5010db6a` cliente, **+85 / −4.418**) y está validada: los 12 criterios de su §7 comprobados uno a uno.
- **`SplitSyncManager.swift` pasó de 2.905 a 2.658 líneas.** Es el fichero al que apunta casi toda la Fase 2 ⇒ **todas sus coordenadas se movieron**, incluidas las que el plan marcaba ✅.
- **Heurística que sale de esta re-medición y sirve para las Fases 3–5:** la Fase 1 fue sustractiva *dentro* de `SplitSyncManager.swift`, así que **solo derivaron las coordenadas de ESE fichero**. Las de los demás ficheros siguen exactas, hasta la línea. Al abrir la Fase 3, re-medir con prioridad lo que apunte a los ficheros que la Fase 2 haya tocado.
- **`migrate_group` quedó cerrado de verdad**: la migración `g6_02_revoke_migrate_group_execute` retiró el `EXECUTE` al rol `authenticated` en **producción Y staging**. La función sigue existiendo (decisión de la Fase 1 respetada). El 404 del gateway está desplegado en **staging**; producción **pendiente**.
- Contexto de release al día en [[MODO-NUBE-HANDOFF-2026-07-28]]: bloqueantes #0 y #2 cerrados · D-A3 revisada a **2 días** · email auth fuera de producción a propósito.

## 1 · Tabla de coordenadas: plan → HEAD

| # | Qué | Plan | **HEAD (2026-07-28)** | |
|---|---|---|---|---|
| 2.1 | callsite de `processRemoteChanges` | `SplitSyncManager:2039` | **`:1889`** | −150 |
| 2.1 | destino (apply del backend) | `GroupsSyncClient:1937`/`:1945` | `applyPulledPage` **`:1436`** · `applyGroupMeta` **`:1590`** | re-anclar por símbolo |
| 2.2 | baseline de miembros | `SplitSyncManager` `1828-1837` | **`:1729`** | −99 |
| 2.2 | clasificación (`initialMemberImportStartedAt`) | `:1909` | **`:1735`** | −174 |
| 2.3 | drenaje del freeze | `1971-1985`, freeze en `:1979` | bloque **`:1832`**, `freezeForSoftDelete` **`:1841`** | −138 |
| 2.3 | detección en `applyGroupMeta` | `:2628`/`:2644` | `applyGroupMeta` **`:2372`** | −256 |
| 2.4 | `accountDeletionGroupsSummary` | `:998` | **`:936`** | −62 |
| 2.4 | consumidor del canal nuevo | `GroupBackendInviteEntryHandler:87` | **`:87`** | ✅ exacto |
| 2.5 | `syncNow` lista · detalle | `GroupsViewModel:201` · `GroupDetailViewModel:133` | **`:201`** · **`:133`** | ✅ exactos |
| 2.6 | `refreshCurrentUserFlags` | `GroupService` `983-1130` | **`:992`** | dentro del rango |
| 2.6 | `selectCurrentUserMemberID` | `GroupExpenseService` `620-629` | **`:621`** | ✅ |
| 2.6 | `GroupJoinReconciler` | `:284` | **`:284`** | ✅ exacto |
| 2.6 | `GroupSettingsView` | `:698` | **`:698`** | ✅ exacto |
| 2.6 | callsites de `belongsToBackendChannel` | `GroupService:1043`/`:1083` | **`:1043`** · **`:1083`** | ✅ exactos |
| 2.7 | seam `resetSyncState` | `DataWipeService:268` | **`:268`** | ✅ exacto |
| 2.7 | destino `purgeGroupsSyncState` | `CloudSessionSignOut:591` | **`:591`** | ✅ exacto |

**Ruta correcta de un fichero que el plan citaba mal:** `GroupBackendInviteEntryHandler.swift` está en `Yala/App/Services/`, no bajo `Yala/Services/CloudSync/Groups/`.

## 2 · Tres correcciones al plan, encontradas al medir

**(a) `belongsToBackendChannel` YA EXISTE y el «extraer ANTES» se lee mal.** Está como estático en `GroupsIdentityPurgeGate.swift:113`, con sus dos callsites vivos. No hay nada que extraer *de una función*: lo que pide el plan es **sacarlo de ese fichero**, porque la **Fase 3 borra `GroupsIdentityPurgeGate.swift` entero** (263 líneas) y ese helper tiene que sobrevivir. Leerlo como «extraer lógica inline a una función» lleva a no hacer nada y a que la Fase 3 se lleve el helper por delante.

**(b) Los «8 consumidores» de 2.4 no son de `accountDeletionGroupsSummary`.** Esa función tiene **3 callsites reales**: `UserDataResetView.swift:90`, `ProfileView.swift:545`, `ProfileView.swift:1128` (más una referencia de doc en `AccountDeletionDebtLogic.swift:22`). El 8 es del **bloque entero de consultas** (`900-1063`), que incluye `group(for:)`, `currentUserMember(zoneID:)` y compañía. **Al abrir la fase: enumerar el conjunto completo de consumidores del bloque, no de una función.** Si se mueve el bloque y se olvida un consumidor, no compila — así que aquí el compilador es la red, a diferencia de 2.1–2.3.

**(c) El plan dice «hoy `/gate` está bloqueado (§5)» y es texto rancio.** El árbol está verde y `/gate` se ha corrido varias veces el 2026-07-28. Ignorar esa línea.

## 3 · Los 7 re-cableos, en orden. Un commit cada uno

**El orden del plan se mantiene y su razón es buena:** los cuatro primeros son **apagones silenciosos** — ninguno falla al compilar, así que cada uno va con su test **antes** de que la Fase 3 borre su emisor. 2.6 es el trozo de más riesgo del plan entero y **no comparte commit con nada**. 2.7 va al final.

### 2.1 · Notificaciones de grupo
Mover la llamada de `GroupNotificationService.processRemoteChanges` (hoy única, en `SplitSyncManager.swift:1889`) al apply del canal backend. El destino natural es `GroupsSyncClient.applyPulledPage` (`:1436`), que es donde el backend ya materializa la página; `applyGroupMeta` (`:1590`) es por-delta y notificaría de más.
**Verificación:** `GroupNotificationServiceTests` + QA en sim: un gasto ajeno debe producir notificación.

### 2.2 · Notificaciones de miembro
`MemberChangeNotificationLogic` con su baseline (`:1729`) y su clasificación por `initialMemberImportStartedAt` (`:1735`).
**Cuidado documentado en `.claude/rules/swiftdata-cloudkit.md`:** en el PRIMER import de una zona recién unida los miembros preexistentes clasifican como «nuevos». La regla exige baseline (`SplitGroup.initialMemberImportStartedAt`) **más** autoexclusión por identidad. Al re-cablear al backend hay que preservar **las dos** condiciones, o el invitado recibe «X se unió al grupo» por el miembro del owner.
**Verificación:** `GroupNotificationRecipientLogicTests`.

### 2.3 · Freeze en soft-delete remoto
Detección hoy en `applyGroupMeta` (`:2372`), drenaje en el bloque de `:1832` con `freezeForSoftDelete` en `:1841`.
**Lo que NO se hace (corrección del plan viejo, ya escrita):** no añadir `freezeForSoftDelete` a `wipeLocalGroupsDomain`. La premisa de que deja transacciones huérfanas es falsa en sus dos callsites reales —llaman `wipeAllUserData` inmediatamente antes— y rompería `HandoverGroupsDomainTests.wipeLocalGroupsDomain_leavesPersonalCorpusAlone`.
**Verificación:** `GroupTransactionBridgeSoftDeleteTests`.

### 2.4 · Consultas SwiftData → `GroupService`
Bloque `900-1063` (incl. `accountDeletionGroupsSummary` en `:936`) y `2809-2860` — **los rangos siguen sin re-verificar**; medir al abrir.
**Invariante que no se puede romper:** preservar el `#Predicate` **concreto por tipo**. Un `#Predicate` genérico-protocolo crashea al ejecutar el fetch con un `Fatal error: Couldn't find \X.<computed …>` no atrapable — es el fix `c74349fc`, y la regla de `.claude/rules/swiftdata-cloudkit.md` lo documenta con el precio que costó.
**Verificación:** `AccountDeletionGroupsSummaryTests` + build (aquí el compilador sí caza los consumidores olvidados).

### 2.5 · `syncNow` → drain del backend
`GroupsViewModel.swift:201` y `GroupDetailViewModel.swift:133`, los dos exactos.
**Verificación:** QA en sim, pull-to-refresh en lista y en detalle.

### 2.6 · Identidad del miembro — **COMMIT AISLADO**
`GroupService.refreshCurrentUserFlags` (`:992`), `GroupExpenseService.selectCurrentUserMemberID` (`:621`), `GroupJoinReconciler.swift:284`, `GroupSettingsView.swift:698`. **Primero** sacar `belongsToBackendChannel` de `GroupsIdentityPurgeGate.swift` (ver §2a).
**Por qué aislado:** decide **quién ve qué balance**. Un error aquí no se ve en un build verde, se ve en un usuario mirando el saldo de otro.
**Cuidado de la regla de área:** el dominio Grupos pertenece al Apple ID, **excepto** en el canal backend, donde la identidad es el `sub` de la cuenta Yala. `GroupsIdentityPurgeGate` existe justo por eso. Y `applyMember` **nunca** setea `isCurrentUser`, así que ninguna resolución de identidad puede depender de ese flag en el canal nuevo (`GroupJoinReconciler.swift:115` y `:156` lo dicen explícitamente).
**Verificación:** `GroupBalanceServiceTests` + `GroupExpenseServiceCurrentMemberTests` + **QA en sim de quién ve qué balance**.

### 2.7 · Seam del handover — **HECHO, y NO como lo prescribía el plan**

> ⚠️ **La prescripción original era incorrecta y habría abierto una fuga entre usuarios.** Decía:
> «repuntar el default de `resetSyncState` en `DataWipeService.swift:268` a
> `CloudSessionSignOut.purgeGroupsSyncState` (`:591`). 1 línea + docblock + 1 test». Esa función borra
> `GroupSyncOutbox` **y** `GroupSyncCursor`, y en esta frontera los dos tienen **signos opuestos**.

**Lo que de verdad hacía falta.** Los dos objetos viven en `syncMetaSchema`, el store que el wipe no
toca, así que el «empiezo de cero» los deja vivos a ambos — pero:

- **El outbox debe MORIR**: son escrituras pendientes del humano anterior y el JWT de la sesión Nube
  vive en su propio Keychain ⇒ **sobrevive al relevo** ⇒ se subirían firmadas como suyas.
- **El cursor debe SOBREVIVIR**: es la BARRERA que impide que el corpus del anterior BAJE a este device
  con ese mismo JWT (el bug de `31dded30`). Purgarlo lo reabre.

Verificado contra el código, no contra el plan: los dos call-sites (`ContentView.swift:260` y `:303`)
son el Welcome y **ninguno cierra la sesión Nube**, así que el JWT sigue vivo. Y el docblock de
`purgeGroupsSyncState` acota su uso al camino solo-grupos «tras el teardown (generación cortada)»,
precondición que este camino no cumple.

**La mitad que casi se escapa:** borrar las filas sin purgar el espejo del App Group es **cosmético** —
`GroupsSyncClient.rehydrateOutboxFromMirror` las re-inserta al próximo boot, y su filtro por `userID` no
protege aquí precisamente porque la sesión sigue viva y la identidad casa. Por eso el borrado de filas va
en el cuerpo (usa el `context`, testeable) y `GroupsOutboxMirror()?.purgeAll()` en el seam `resetSyncState`
(es disco, y los tests lo sustituyen por `{}`).

**Alcance real:** 1 línea de borrado + 1 línea de purga del espejo + docblocks, y **3 tests** que pinnean
los dos sentidos: `outbox == 0` **y** `cursor == 1` con su contenido intacto, más un source-scan de que el
espejo se purga y de que la función de sign-out **no** se llama. La regla durable quedó en
`.claude/rules/swiftdata-cloudkit.md`.
**Por qué al final y por qué importa:** `GroupSyncCursor` y `GroupSyncOutbox` viven en `syncMetaSchema`, un store que el wipe no toca, así que un «empiezo de cero» dejaría vivos el cursor y el outbox del usuario anterior. Y el cursor superviviente es la **barrera** que impide que el corpus del usuario anterior baje al device del nuevo (el bug de `31dded30`) ⇒ tocar esto sin entender esa regla reabre una fuga entre usuarios.
**Verificación:** `HandoverGroupsDomainTests`.

## 4 · Contrato de salida

- **Cada re-cableo deja el árbol compilando y los tests verdes.** Se puede parar en cualquiera de las 7 fronteras: el transporte sigue vivo y solo queda lógica duplicada temporalmente. Estado estable.
- **Regla dura:** ningún borrado de la Fase 3 entra sin que su re-cableo esté verde y commiteado.
- `qa/coverage-index.json` se actualiza **en el MISMO commit** que el código y se valida con `bash qa/validate-coverage.sh`.
- **`/gate` antes de cada commit.** Nota de entorno que ahorra un diagnóstico falso: en iOS 27.0 un rojo de XCUITest tarda **11–13 min de reloj** (~66 s de tests + ~600 s de teardown colgado de `xcodebuild`), así que un timeout por debajo de ~15 min reporta «timeout» y no «fallo». Y clasificar por exit code ANTES de leer el output: 65 = fallo de test · 70 o cero líneas `Test Case` = infraestructura.
- **Requisito para ABRIR la Fase 3, no ésta:** reescribir el plan de rollback (§6). Y el borrado manual de los gastos de grupo del owner (§1.1), que puede hacerse en paralelo a esta fase.

## 5 · Techo de alcance

De [[MODO-NUBE-REVISION-TANDA1-ALCANCE]] §8, que el owner pidió explícitamente: de 6.823 líneas insertadas en la tanda anterior, **1.163 eran código de producción (17 %)**.

- Esta fase **mueve** lógica, no la añade: el techo de líneas de producción NUEVAS es **≈0** por commit, salvo el helper que sobreviva a `belongsToBackendChannel`.
- **Nada de ficheros de lógica pura nuevos** con su suite exhaustiva sin justificarlo.
- **Cero canarios que no puedan emitir · cero tests que afirmen texto fuente · cero doc-comment de relleno.**
- **Cero l10n en superficies inalcanzables.**
- **Prohibido arreglar de paso** lo ajeno: si aparece un bug, se REPORTA.
- **Ninguna acción de infraestructura sin OK explícito del owner en el turno.**

## 6 · Hueco menor, para decidir aparte

La exclusión de `migrate_group` del allowlist del gateway **no tiene test propio**. El mecanismo genérico sí está cubierto (`groups.goldens.test.ts:549` afirma 404 para `fake_fn` y `apply_group_delta`), y la Fase 1 borró todas las referencias a `migrate_group` de los tests. Añadir una línea a ese test cerraría el hueco de drift; hoy nadie cazaría a quien lo re-añadiera a `PARAM_ALLOWLIST`. **No autorizado todavía.**
