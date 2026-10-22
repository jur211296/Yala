---
id: group-notif-credits-payer-not-editor
status: done
created: 2026-07-22
updated: 2026-08-28
source: YalaWiki/Bugs/groups-notif-actualizo-atribuye-al-pagador-no-al-autor.md
---


# Notificación "Pia actualizó [gasto]" cuando el que editó fui yo — atribución por PAGADOR + eco sin autoexclusión

## Síntoma

El owner editó un gasto compartido cuyo **pagador** era Pia → recibió la notificación "✏️ Pia actualizó '[gasto]' — te toca X". Pia no tocó nada.

## Causa raíz — DOS defectos que convergen (canal CloudKit)

**1. La "X" del texto es el PAGADOR, no el autor de la edición.**
`GroupNotificationService.buildExpenseNotification` (`GroupNotificationService.swift:296-311`): línea 297 `resolveMemberName(memberID: expense.paidByMemberID)` → línea 309 `L10n.Notifications.Group.modifiedExpense(memberName, …)` (key `notifications.groups.modifiedExpense`). Mismo proxy en gasto nuevo (línea compartida) y en liquidaciones (`settlement.fromMemberID`, línea 316).

**2. La autoexclusión del eco es POR PAGADOR, no por autor.**
`GroupNotificationRecipientLogic.swift:36-43`: `if paidByMemberID == me { return .skip }`. El header del servicio (líneas 10-11) declara "el autor NUNCA se notifica de lo que él mismo registró" — pero la implementación confunde autor con pagador. Funciona en el caso común (creas un gasto que pagas tú); falla exactamente cuando editas un gasto pagado por otro.

**Camino del eco reconstruido:** owner edita → push CloudKit → el eco vuelve por `fetchedRecordZoneChanges` → `SplitSyncManager.handleFetchedRecordZoneChanges:1579-1584` clasifica el expense como modified **sin ningún filtro de quién originó el cambio** (contrasta con members, que SÍ tienen autoexclusión por identidad: `:1608-1609` + `MemberChangeNotificationLogic.swift:86-91`) → recipient logic no skipea (owner ≠ pagador) → el builder nombra a Pia.

## Hecho estructural clave: NO EXISTE campo "autor del último cambio"

- `SplitExpense.swift:12-63`: sin `lastEditedBy`/`modifiedBy`/`authorMemberID`. El único identificador de persona en el record es `paidByMemberID` — por eso se usó como proxy.
- El wire del canal backend tampoco lo lleva (`GroupEntityEmissionMap.swift:66-76`).
- El propio código ya lo documenta: `GroupExpenseAccountFinalizationSheet.swift:98` y `GroupExpenseAccountAndSubcategoryFinalizationSheet.swift:116` — "sync remoto no expone 'modifiedBy'".

⇒ La atribución correcta es hoy **imposible** sin dato nuevo.

## Fix en dos capas

**Capa 1 — mínimo del síntoma (sin campo nuevo, sin deploy de schema):** autoexcluir el ECO por identidad en la clasificación de expenses, replicando el patrón de members (`cachedRecordName` de `GroupUserIdentityService`; candidato: leer `record.lastModifiedUserRecordID` en la rama expense de `handleFetchedRecordZoneChanges` y comparar con la identidad local — solo sirve para "¿fui yo?", no para atribuir a terceros). Con esto el owner deja de recibir el eco de su propia edición. El texto seguiría atribuyendo mal cuando un TERCERO edita un gasto pagado por otro (Pia edita gasto pagado por Marco → "Marco actualizó").

**Capa 2 — atribución correcta (campo nuevo end-to-end):** `SplitExpense.lastEditedByMemberID` escrito por el editor, traducido en `CKRecordTranslator`, emitido en `GroupEntityEmissionMap` + aplicado en `GroupsSyncClient.applyExpense` (1626-1651). ⚠️ **Regla inviolable del container de grupos**: field key nuevo = deploy del schema CloudKit a Production + actualizar `cloudkit-groups-production.ckdb` en el MISMO PR (`CloudKitGroupsSchemaParityTests`); y si toca el wire del backend, columna en `split_expenses` + emisión + Merkle projection en el mismo movimiento.

## Canal backend (DARK) — sin duplicado hoy, riesgo al migrar

`GroupsSyncClient.applyPulledPage` (1539-1591) NO notifica (solo `markRemoteChangePending` + bridge); su echo-suppression es de History (`tx.author == outboxSaveAuthor`, `:495`), no de notificaciones. Cuando las notificaciones migren al canal backend, arrastrarían este mismo defecto salvo que el wire lleve el campo autor — anotar en el diseño de esa migración.

## Superficies del fix

- `GroupNotificationService.swift:296-311` (builder), `GroupNotificationRecipientLogic.swift:36-43` (recipient), `SplitSyncManager.swift:1579-1584` (clasificación), patrón a replicar en `MemberChangeNotificationLogic.swift:79-111`.

---

## Resolución (2026-07-23, branch `2.0.5`) — Capa 1 + Capa 2, incluyendo liquidaciones

**Decisión owner (AskUserQuestion):** Capa 1 + Capa 2 robusto, **incluyendo liquidaciones**. Se descartó "solo Capa 1" porque `lastModifiedUserRecordID` es **no confiable** (en la base privada devuelve `__defaultOwner__` para la edición del propio owner → la comparación falla justo en el caso principal; en zona compartida la representación por-participante no está documentada — por eso el patrón de members usa un campo *stored*) **y** no corrige la atribución cuando un tercero edita.

**Campos stored nuevos** (= `SplitMember.id.uuidString`, determinista entre devices → cubre 2º device mismo iCloud):
- `SplitExpense.lastEditedByMemberID` — el editor real (crear/editar). Atribución "X actualizó"/"X agregó" al editor, no al pagador.
- `SplitSettlement.recordedByMemberID` — quien registró la liquidación. Cierra el **eco Caso D** (registro "X me pagó" y no me llega "X te pagó"). La atribución "X te pagó" (=`fromMemberID`) ya era correcta.

**Piezas:** escritura en el path LOCAL (`GroupExpenseService.create/updateExpense/createSettlement`, helper `currentUserMemberID(in:)`) · lectura en `CKRecordTranslator` (molde `subcategoryName`) · `CKConstants.ExpenseField/SettlementField` · autoexclusión del eco en `GroupNotificationRecipientLogic.expenseDecision` (skip si `(lastEditedByMemberID ?? paidByMemberID) == me` — el guard legado `paidByMemberID == me` se preserva: "alguien editó un gasto que pagué yo" sigue silencioso, fuera de scope) y `shouldNotifySettlement` (skip si `recordedByMemberID == me`) · atribución vía `expenseAttributionMemberID`.

**Review adversarial (4 confirmed, todos corregidos):**
- SERIO: el write-side resolvía el miembro actual con tie-break distinto al consumidor → bajo `isCurrentUser` duplicados elegían ids distintos y el eco no se autoexcluía. **Fix:** resolución canónica (`isCurrentUser` con `joinedAt` más antiguo, espeja `currentMemberID(inZone:)`), extraída a `selectCurrentUserMemberID` (pura, testeada con `@Model` directo).
- MINOR: ventana temprana del owner (`isCurrentUser` device-local aún no marcado en 2º device/restore) → campo nil → reintroducía el bug. **Fix:** fallback por identidad iCloud (`cloudKitUserRecordID == cachedRecordName`, misma fuente que `refreshCurrentUserFlags`).
- MINOR: `try?` que silencia (regla inviolable). **Fix:** `do/catch` con log DEBUG.
- MINOR: el cableado del servicio no lo verificaba ningún test (revert silencioso con los params `= nil`). **Fix:** source-scan `GroupNotificationServiceTests.wiring_*`.

**Residuales documentados (limitación de plataforma):**
- Rollout mixto: un editor en app VIEJA no escribe la key; CloudKit hace merge por-campo ⇒ el server RETIENE el autor previo (no nil) ⇒ esa edición puede atribuirse/suprimir por un autor que ya no corresponde. Transitorio, sin pérdida de datos, auto-sana cuando todos actualizan.
- Ventana ultra-estrecha (primer arranque sin identidad iCloud cacheada + editar gasto de otro): campo nil; ahí el consumidor tampoco resuelve `currentMemberID` ⇒ `expenseDecision` skipea (sin notif espuria).

**Wire backend DIFERIDO** (canal DARK `groupsBackendEnabled=false`): el campo es invisible al emission map/Merkle (precedente `bridgePending`) — cuando las notifs migren al backend hay que cablearlo (columna DDL + emisión + manifest + Merkle projection + goldens). TODO anotado en los modelos.

**Gates verdes:** build prod "Yala" + "Yala Dev" (0 warnings nuevos) · **129 tests / 7 suites** (pure-logic + paridad `.ckdb` + wire intacto), parallel OFF · **mutante verificado** (neutralizar el guard `author == me` → rojo en `expense_iEditedGastoPaidByOther_skips`) · `validate-coverage` OK. Verificado en **worktree aislado** (una sesión paralela editaba el mismo repo principal con WIP que rompía la compilación del target de tests).

### ✅ Deploy + commit HECHOS (2026-07-23)
Los 2 field keys nuevos (`SplitExpense.lastEditedByMemberID`, `SplitSettlement.recordedByMemberID`, STRING) fueron **desplegados por el owner a Production en AMBOS containers**: `.groups` y `.groups.dev` (scheme Yala Dev). Snapshots-contrato renombrados a la convención por sufijo de container — `Cloudkit Schemas/groups-*.ckdb` / `groups_dev-*.ckdb`; `CloudKitGroupsSchemaParityTests` re-apuntado a `groups-production.ckdb` + regla de CLAUDE.md actualizada. Commiteado y pusheado: `d784a4ab` (fix) + `20b71590` (docs).

### Guion device-QA (el eco/atribución real solo reproduce con 2 devices/CloudKit)
Requiere el schema desplegado (Development si se usan builds dev contra el entorno Development de CloudKit, o TestFlight tras el deploy a Production). Grupo con owner (device A) + otro member (device B):
1. **Bug reportado (eco al editor):** existe un gasto **pagado por B**. El owner (A) EDITA el monto. → **A NO recibe** "actualizó" (antes recibía "B actualizó"). 
2. **Atribución al editor:** device B recibe "✏️ **[Owner]** actualizó '…' — te toca X" (atribuido al EDITOR, no al pagador B).
3. **Gasto nuevo:** el owner registra un gasto **pagado por B**. → B (y terceros) reciben "🧾 **[Owner]** agregó…" (creador), no "B agregó".
4. **Eco settlement Caso D:** un member registra "X me pagó" (es el receptor). → **NO recibe** "X te pagó" por su propio registro.
5. **2º device mismo iCloud:** el owner con 2 devices edita en A → **B NO le notifica** al owner su propia edición.

migrated from YalaWiki Bugs/groups-notif-actualizo-atribuye-al-pagador-no-al-autor.md @ 1934e8ad

## Cierre del owner 2026-08-28 (Jurgen, Lima) — PASS de atribución/eco

**La corrida.** Dos teléfonos, el **mismo grupo que el resto del QA de hoy**, **TestFlight 2.1 build 12**
(el binario que ya hay en campo; no se subió nada nuevo para esto).

- **A fue quien actuó** (crear/editar el gasto).
- **A NO recibió notificación.** Ningún eco de su propio movimiento y, en particular, **ninguno que
  atribuyera el cambio a B**. Es el síntoma con el que se abrió este ticket ("Pia actualizó" cuando el que
  editó fui yo), visto ahora desde el lado del que actúa.
- **B SÍ recibió notificación.** El aviso al otro miembro sigue saliendo: la autoexclusión del eco no
  apagó el canal.

**Veredicto del owner: PASS** en este ticket de atribución/eco. Con eso pasa a `done/`. Es el escenario que
ningún test podía cerrar —el eco solo existe con dos devices y CloudKit real— y por la regla del repo no lo
declara bueno quien escribió el fix.

**Esto es un cierre de QA, no un fix nuevo.** No hay cambio de código en este movimiento, **no hubo subida a
TestFlight** y **A7/M5 sigue en HOLD**, igual que App Store y tag.

### Lo que este PASS NO cubre

- **La notificación de B llegó solo al abrir la app.** Es un hallazgo real de la misma corrida, pero es
  **otro problema**: el *momento de entrega*, no *a quién se atribuye* el cambio. Va en ticket aparte
  (`groups-expense-notif-only-on-foreground`, en alta separada) y **no entra aquí ni como PASS ni como FAIL
  de la atribución**: el contenido del aviso y la autoexclusión son correctos con independencia de cuándo
  aparezca.
- **El escenario original (gasto pagado por Pia y editado por el owner) no consta re-corrido palabra por
  palabra.** El reporte de hoy dice que **A** fue el autor de la acción; **no dice quién era el pagador** ni
  si el paso fue el de crear o el de editar. Lo que queda visto es la autoexclusión del eco; la precondición
  literal del paso 1 del guion —gasto **pagado por B**, editado por A— no está escrita en el reporte.
  - **Por qué importa cuál era el pagador:** el skip vive en `GroupNotificationRecipientLogic.expenseDecision`
    como `(lastEditedByMemberID ?? paidByMemberID) == me`, y el guard legado `paidByMemberID == me` se
    **preservó**. Si el gasto lo pagaba A, el silencio hacia A ya existía ANTES de este fix ⇒ esa variante no
    discrimina. Solo discrimina con **pagador ≠ A**. El reporte no lo fija, así que el PASS se apoya en el
    veredicto del owner, no en ese control.
- **El texto de la notificación de B no está medido.** El reporte registra que **llegó**, no qué nombre
  mostraba. El **paso 2** del guion —B ve "✏️ **[Owner]** actualizó '…'", atribuido al EDITOR y no al
  pagador— no tiene lectura literal de pantalla hoy.
- **Terceros y liquidaciones: sin correr.** Fuera de esta corrida quedan el caso «un tercero edita un gasto
  pagado por otro» (Pia edita gasto de Marco, la parte que la Capa 1 sola no arreglaba), el **paso 3** (gasto
  nuevo atribuido al creador), el **paso 4** (eco Caso D de liquidaciones, `recordedByMemberID`) y el
  **paso 5** (2º device con el mismo iCloud).
- **Los residuales de plataforma siguen escritos y sin probar**: rollout mixto (un editor en app vieja no
  escribe la key ⇒ el server retiene el autor previo) y la ventana ultra-estrecha del primer arranque sin
  identidad iCloud cacheada.
- **El wire del canal backend sigue DIFERIDO.** El campo es invisible al emission map / Merkle; cuando las
  notificaciones migren al canal backend hay que cablearlo. Este PASS es del canal **CloudKit**.
