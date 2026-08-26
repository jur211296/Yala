---
created: 2026-07-13
updated: 2026-07-13
tags: [modo-nube, grupos, decision, v1]
---

# Modo Nube — Decisión: Grupos en v1 (2026-07-13)

> **⚠️ SUPERSEDIDA (2026-07-14, decisión owner durante el device-QA del batch M1/endurecimiento):** la dirección (4) queda revertida — **Grupos migra al backend nube EN v1** (no post-v1). Detonante: la corrida device del 2026-07-14 evidenció el costo de producto del híbrido CloudKit-grupos/backend-personal — identidad del dueño respondiendo a la invitada en invites (`alreadyMember` sobre `YalaGroups` compartido), tab/rutas fantasma en secundaria, gates dependientes del Apple ID del OS; el owner lo consideró inaceptablemente confuso ("no importa que signifique replanear muchas cosas"). El QA del batch quedó PARKEADO completo (hallazgos en [[MODO-NUBE-M1-GUION-DEVICE]] y [[MODO-NUBE-SIGNOUT-WELCOME-GUION-DEVICE]]). Replaneo: [[groups-backend-v1]]. Las secciones de abajo conservan la evidencia técnica (sigue válida: bridge→motor completo, sin divergencia de datos) — lo revertido es el TIMING de Grupos→backend, no el diagnóstico.

Sesión de diseño con el owner (2026-07-13). Pregunta de origen (verbatim del owner): cree que será necesario integrar Grupos al backend desde antes de v1 — sea para grupos con aprobación de un usuario Sign-in, o TODO Grupos al backend; siente que lanzar Sign-in con Grupos únicamente en CloudKit "puede tener alguna clase de peligro". Método: 3 exploradores (docs + 2 de código) → peligros con evidencia → opciones con trade-offs → decisión del owner.

**TL;DR: el miedo NO se sostiene como peligro de datos — la evidencia de código muestra que bridge→motor está completo y que grupos mixtos no divergen. Los peligros reales son de producto/identidad (gate sin-iCloud inexistente, GAP 1, invite mudo en secundaria) y se cierran con un paquete de endurecimiento de días. DECISIÓN: dirección (4) — v1 con Grupos en CloudKit + endurecimiento; Grupos→backend programado como PRIMER incremento post-v1, antes de web/Android.**

---

## 1. Evidencia — qué se verificó en código (2026-07-13, branch 2.0.5)

### 1a. Bridge→motor cloud: COMPLETO (el peligro temido NO existe)

Un usuario `.cloud` que usa Grupos bridgea gastos/liquidaciones a `TransactionItem`/`InboxDraft` en el store personal, y ese camino fluye entero al backend:

- El bridge escribe con `context.save()` normal del mainContext, **autor por defecto** (`GroupTransactionBridge.swift:735-741` y demás save-sites) → la History lo captura y el echo-suppression del drain NO lo descarta (solo filtra `outboxSaveAuthor`, `CloudSyncEngine.swift:997`).
- El bridge no setea `syncID`, pero `sweepAndBuildLookups` se lo asigna a filas vivas sin él, incluyendo `TransactionItem` e `InboxDraft` (`CloudSyncEngine.swift:1555-1558`) → se integran al outbox en el siguiente drain.
- Ambas entidades están en el manifest de 16 (`personalEntityNames`, `CloudSyncEngine.swift:771,776`) y cableadas en `EntityApplyMap`/`EntityEmissionMap`.
- Las columnas de vínculo a grupo están mapeadas en los TRES niveles (emisor / `capability_manifest.json` / DDL) con paridad testeada (`EntityEmissionParityTests`): `split_expense_id`, `split_group_zone_id`, `split_settlement_id` standalone + `split_total_amount`/`split_type`/`split_my_value`/`split_divisor` en el grupo de coherencia `tx_split`.
- **Corrección a la premisa de la sesión:** `GroupBridgePreference` NO vive en el container de grupos — es entidad del store PERSONAL por diseño (`GroupBridgePreference.swift:26-29`), una de las 16 sincronizadas. El cierre C3 (GAPS) está bien anclado.
- Gate de quiescencia del bridge remoto bajo `.cloud`: degrada bien (la señal de CloudKit queda perpetuamente quieta → siempre `.run`), pero **por accidente afortunado** — usa `iCloudSyncService.status` hardcodeado (`SplitSyncManager.swift:1490-1496`) en vez de `StorageModeSignalRouter.quiescenceSource(mode:)`.

**Huecos (menores, entran al paquete §3):** (1) NO existe ningún test e2e bridge→drain→outbox — las suites del bridge y del motor son disjuntas; una regresión de integración no la detectaría nadie. (2) La inconsistencia de señal de quiescencia recién descrita.

### 1b. Miembros mixtos: NO hay divergencia, solo degradación

- **Cero acoplamiento Grupos↔storageMode**: grep de `storageMode`/`StorageModePersistence`/`CloudSyncFlags.storageMode` sobre todo `Services/Groups/` + ViewModels + Models `Split*` + Views = 0 coincidencias. Grupos usa container CloudKit propio + CKSyncEngine propio; `storageMode` solo gobierna el store personal.
- Miembro migrado `.cloud` (con iCloud) ve **exactamente lo mismo** que uno `.icloud` — su identidad de Grupos (`CKContainer.userRecordID`) resuelve igual.
- Miembro en sesión secundaria M1: `SplitSyncManager.initialize()` no corre (`AppBootstrapper.swift:280`) → sus gastos no entran ni salen. El grupo del resto **degrada** (lo ven como member que no postea), NO diverge: `GroupBalanceService.calculateBalances` computa sobre el dataset sincronizado de CloudKit (SSOT compartido) y tolera members ausentes (fallback `memberNames[key.memberID] ?? key.memberID`). Sin asserts ni invariantes "todos sincronizan".

### 1c. Los peligros REALES (los que sí había que cerrar)

1. **Gate "sin iCloud" inexistente (producto).** El tab Grupos solo se filtra por sesión secundaria (`TabBarConfiguration.forMode`, `TabBarConfiguration.swift:104-118`) y por el beta gate. Un born-cloud sin iCloud con beta desbloqueado VERÍA el tab con empty-state/spinner sin explicación. Un invite sin iCloud produce error genérico de sync (`SplitSyncManager.swift:684-692` → `groups.sync.errorAcceptShare`), no "necesitas iCloud". El `GroupsICloudAvailabilityGate` que §i.8(c)2 planeó para I12 NO está implementado aún.
2. **Invite en sesión secundaria falla EN SILENCIO.** Con `container == nil` (engine nunca inicializado), `acceptShare` hace early-return con `noteAcceptFailed(recoverable: false)` + log (`SplitSyncManager.swift:630-636`) sin emitir `showGroupSyncError`. El invitado no ve nada; el invite queda en `PendingInviteStore` para un cold launch primario.
3. **GAP 1 (gap-estados) — real pero MENOS grave de lo documentado.** SÍ existe detección reactiva: el engine entrega `.accountChange` y `handleAccountChange` (`SplitSyncManager.swift:1206-1235`) limpia datos locales + resetea `stateSerialization` de ambos engines + limpia cache de identidad, respetando el gate export-only. **Laguna real:** `groups_currentUserRecordName` (UserDefaults, `GroupUserIdentityService.swift:18,24,41`) nunca se compara proactivamente al boot contra `CKContainer.userRecordID()` — si el Apple ID cambia con la app cerrada y el siguiente arranque no deja al engine procesar el evento (o cae en secundaria, donde el engine no arranca), Grupos opera con identidad vieja en silencio.

### 1d. Costo real de Grupos→backend (para dimensionar la puerta abierta)

- Superficie 100% CloudKit-specific: **~3.230 líneas en ~6 archivos** — `SplitSyncManager.swift` (2.176), `CKRecordTranslator.swift` (382), `SplitZoneManager.swift` (290), `InviteLinkService.swift` (170), `CloudKitConstants.swift` (132), `GroupUserIdentityService.swift` (77). Subsistema total ~12.150 líneas en ~40 archivos: bridge, balances, notificaciones y reconciliación (la mayor parte) son 100% transport-agnósticos (0 símbolos CloudKit).
- **Lo que NO es solo reescribir líneas:** no hay protocolo de transporte abstracto (`CKRecordTranslator` habla CKRecord directo); `SplitMember.id` = `SHA256("SplitMember:" + zoneID + ":" + recordName)` anclado a la identidad CloudKit (`GroupUserIdentityService.swift:61-76`) → migrar exige un identificador backend estable equivalente + remap multi-usuario; CKShare hay que reemplazarlo entero (invites, permisos, push — CloudKit da push gratis, el backend necesitaría APNs propio o polling); y la **migración de un grupo existente exige coordinar a TODOS sus miembros** (no controlas cuándo actualizan la app).
- **Riesgo heredado:** el motor propio pierde el dedup implícito por identidad de CloudKit — la clase de problemas C3 (representaciones divergentes por decisión per-device) reaparecería a escala multi-usuario real. Es exactamente la complejidad que Fase 0 (#1) difirió a propósito.

### 1e. El sub-caso "híbrido por aprobación" — evaluado y DESCARTADO

Grupos donde participa ≥1 cuenta Sign-in replicando vía backend = **doble fuente de verdad autoritativa por grupo**. Exige construir TODA la pieza backend igual (identidad, permisos, push) MÁS un reconciliador bidireccional CloudKit⇄backend que no existe en ninguna forma. Estrictamente más caro y más peligroso que la migración completa. Es la peor de las cuatro direcciones evaluadas.

---

## 2. Decisiones del owner (2026-07-13, AskUserQuestion)

| # | Pregunta | Decisión |
|---|---|---|
| D1 | Dirección para v1 | **(4) Endurecido + backend post-v1**: v1 lanza con Grupos en CloudKit + paquete de endurecimiento; Grupos→backend se compromete como **PRIMER incremento post-v1, antes de web/Android**. DIFERIDOS #3 pasa de "futuro-v2 sin gatillo" a "programado post-v1". |
| D2 | Paquete de endurecimiento | **Las 4 piezas** (§3): GroupsICloudAvailabilityGate + copys · boot-guard GAP 1 · invite en secundaria con error visible · test e2e bridge→drain→outbox. |
| D3 | Restricción "sin iCloud / secundaria = sin Grupos" en v1 | **Aceptada con gate honesto.** Es el comportamiento ya vigente (Grupos siempre exigió iCloud); todo invitado por link tiene iCloud por construcción, así que el caso real es raro. El gate + copy lo hace transparente en vez de roto. |

Direcciones descartadas: (2) híbrido por aprobación (§1e — peor de todas) y (3) backend completo adelantado a v1 (§1d — retrasa v1 semanas-meses y hereda C3 multi-usuario).

---

## 3. Paquete de endurecimiento v1 (alcance)

> Ticket ejecutable con spec completo: [[groups-endurecimiento-modo-nube-v1]] (spec-ready, 2026-07-13).

Trabajo NUEVO de v1 (encaja en la órbita de I12/M1; ninguna pieza toca el motor de sync):

1. **`GroupsICloudAvailabilityGate` + copys honestos** — el gate proactivo pure-logic ya diseñado (§i.8(c)2, patrón `GroupsBetaGateLogic`, riesgo A21): estado explícito "Grupos necesita una cuenta de iCloud" + CTA a Ajustes en la vista de Grupos, y error CLARO (no genérico) cuando un invite falla por falta de iCloud. Keys l10n × 16 locales.
2. **Boot-guard GAP 1** — al boot (con engine primario), comparar `groups_currentUserRecordName` persistido vs `CKContainer.userRecordID()` actual; si difieren, correr la misma limpieza de `handleAccountChange` (`.switchAccounts`). Cierra la laguna "Apple ID cambió con la app cerrada / en secundaria". Actualizar `gap-estados.md` GAP 1 al implementarlo.
3. **Invite en secundaria: error visible** — el early-return de `acceptShare` con `container == nil` (`SplitSyncManager.swift:630-636`) debe emitir un error localizado al usuario (copy propio de secundaria: "los grupos no están disponibles en esta sesión"), no solo log/telemetría.
4. **Test e2e bridge→drain→outbox** — crear gasto de grupo vía bridge → correr drain → assertar fila de outbox con `split_expense_id`/`split_group_zone_id` pobladas. Opcional en el mismo incremento: enrutar el gate de quiescencia del bridge remoto por `StorageModeSignalRouter` (corregir el accidente afortunado de §1a).

---

## 4. Efectos sobre otros documentos

- **[[MODO-NUBE-DIFERIDOS]] #3** — actualizado: sigue FUTURO (no entra a v1) pero con gatillo PROGRAMADO (primer incremento post-v1, antes de web/Android #10) y referencia a este doc + al dimensionamiento §1d.
- **[[MODO-NUBE-DIFERIDOS]] #11** — nota añadida: el paquete §3 entra a v1 por esta decisión.
- **[[MODO-NUBE-ROADMAP-FASE4]]** — fila #3 del Bloque E actualizada (programado post-v1) + paquete de endurecimiento referenciado.
- **[[gap-estados]] GAP 1** — la mitigación queda decidida aquí (§3.2); actualizar el gap al implementar el boot-guard.
- Riesgo **A32** (iOS-independiente→Android pierde Grupos, ENLACE-OPCIONAL) — su resolución ahora tiene fecha relativa: el incremento Grupos→backend post-v1.
