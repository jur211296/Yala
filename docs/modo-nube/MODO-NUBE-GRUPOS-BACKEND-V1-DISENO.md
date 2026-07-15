---
created: 2026-07-14
updated: 2026-07-14
tags: [modo-nube, grupos, backend, diseno, v1]
---

# Modo Nube — Grupos al backend EN v1: diseño (2026-07-14)

Sesión de replaneo tras la decisión owner del 2026-07-14 ([[groups-backend-v1]]): Grupos deja CloudKit y migra al backend nube DENTRO de v1 — supersede [[MODO-NUBE-GRUPOS-V1-DECISION]] (que lo programaba post-v1). Método: 2 exploradores paralelos (subsistema Grupos ~22.600 líneas de app; motor de sync propio + gateway) → 9 decisiones del owner vía AskUserQuestion → este diseño. Restricción heredada que NO se re-litiga: el híbrido "por aprobación" está DESCARTADO (doble verdad + reconciliador bidireccional) — la migración es completa.

**TL;DR: canal de sync APARTE para grupos (patrón `PrefsSyncClient`, no se toca el motor per-user de 16 entidades), RLS de Postgres por membership + RPCs SECURITY DEFINER puntuales, identidad de miembro = `sub` de la cuenta nube (sign-in obligatorio, también invitados), minimización + pgcrypto para los datos sensibles de grupo, APNs propio dentro de v1, migración de grupos vivos por "owner migra + re-invite", grupos por sesión en M1 (muere el `YalaGroups` compartido), y UN SOLO ENCENDIDO: el gate de flags del Modo Nube pasa a incluir Grupos-backend.**

---

## 0. Decisiones del owner (2026-07-14, AskUserQuestion ×9)

| # | Pregunta | Decisión |
|---|---|---|
| D1 | Canal de sync | **Canal aparte** (`GroupsSyncClient`, patrón `PrefsSyncClient`): tablas nuevas PK `(group_id, sync_id)`, seq por grupo, cursor propio, Merkle por grupo. Reusa HLC/LWW, codec c1, transporte/auth/attest. NO toca las 16 tablas per-user ni su RLS/cursor. |
| D2 | Autorización cross-user | **RLS por membership + RPCs puntuales**: policies `EXISTS(group_members)` para el CRUD; join-por-token/aprobar/expulsar/salir vía RPCs SECURITY DEFINER (molde `claim_account`/`claim_report`). El gateway sigue reenviando el JWT verbatim, jamás service_role. |
| D3 | Identidad de miembro | **Cuenta nube (`sub`) para todos** — también usuarios privacy-first `.icloud` y todo invitado. Resuelve de raíz M1-3, GAP 1 (G2/G3) y la doble identidad Apple-ID-del-OS vs cuenta-de-la-app que detonó el pivote. |
| D4 | Protección de datos de grupo | **Minimización + pgcrypto**: alias (no nombre real), sin email almacenado, consent honesto; Y cifrado de columnas sensibles (`amount`/`note`/`display_name`) con pgcrypto — adelanta [[MODO-NUBE-DIFERIDOS]] #5 como incremento propio. E2E por grupo DESCARTADO para v1 (llaves por membership, recovery, mata #22). |
| D5 | Entrada del invitado | **Sign-in obligatorio** al aceptar el link (SIWA/Google, un tap; Hide My Email disponible; solo se guarda `sub` + alias). Sin cuentas anónimas vinculables (linking + huérfanos + "perdí mi membresía al cambiar de teléfono"). |
| D6 | Push / latencia | **APNs dentro de v1** como incremento PROPIO al final del plan: push silencioso para sync-wake (paridad con el push de CKSyncEngine hoy) + fan-out server-side. Las notifs se siguen construyendo CLIENT-SIDE (sobrevive `GroupNotificationService` entero). |
| D7 | Migración de grupos vivos | **Owner migra + re-invite**: el dueño sube el historial one-shot al backend; el grupo CloudKit queda CONGELADO con marcador; los miembros re-entran con link nuevo y sus filas históricas se rebindean a su cuenta al entrar. Sin doble verdad. |
| D8 | M1 secundaria + wipes | **Grupos por sesión**: store local de grupos por archivo por sesión (patrón M1), tab Grupos VISIBLE en secundaria con los grupos de ESA cuenta; los wipes de sign-out BORRAN el store de grupos (re-descargable del backend). Muere el `YalaGroups` compartido. |
| D9 | Timeline / gate de flags | **Un solo encendido**: el gate de flags del Modo Nube INCLUYE Grupos-backend; la beta arranca cuando personal + grupos estén completos. Nadie vive el híbrido jamás. |

---

## 1. Qué muere / qué sobrevive (mapa verificado en código 2026-07-14)

El subsistema completo son **~22.600 líneas de app** (no las ~12k estimadas el 13/07 — aquel conteo excluía Views/ViewModels/Logic):

**Muere (~3.500-4.000 líneas, CloudKit puro):**
- `SplitSyncManager.swift` (2.255) — engines private/shared, delegate, state serialization, export-only gate, zone recovery, conflict handling. Sobreviven de él las **queries de dominio** (`group(for:)`, `currentUserMember`, `mostRecentGroup`, líneas 751-833) y la **API `enqueueSave/enqueueDeletion`** como COSTURA a re-implementar contra el canal nuevo.
- `CKRecordTranslator.swift` (382) — su catálogo de campos es la spec de columnas del DDL; `sanitizeAmount` y la regla de owner se mueven al server/apply.
- `SplitZoneManager.swift` (290) — zona-por-grupo + CKShare desaparecen como concepto.
- `CloudKitConstants.swift` (132), `GroupUserIdentityService.swift` (77) — identidad iCloud muere entera.
- Dedup services que existen por falta de `.unique` en CK (`SplitGroupDeduplicationService`, `GroupBridgePreferenceDeduplicationService`, ~212) — la PK server-side los vuelve innecesarios para grupos nuevos.
- `CKShareEntryHandler` (la parte CKShare.Metadata), `InviteLinkService` (la parte CKFetchShareMetadataOperation), `PendingLeaveShareTracker`.
- Gates que existen porque Grupos vive en el Apple ID del OS: `GroupsICloudAvailabilityGate` (+`GroupsICloudUnavailableView`), `GroupsIdentityBootGuardLogic` + `runIdentityBootGuard`, el filtrado del tab en secundaria (`TabBarConfiguration.swift:114-116`), la exención "grupos intocables" de los wipes.

**Sobrevive (~18.500 líneas, transport-agnóstico):**
- Los 5 modelos `Split*` (FKs por string plano, sin `@Relationship` — ya compatibles): pierden `ckSystemFieldsData` y ganan el pequeño delta de identidad de §2.
- `GroupService` (1.034), `GroupExpenseService` (672), `GroupTransactionBridge` (1.202), `GroupBalanceService` (390), `GroupNotificationService` (390), `BridgeModeResolver` (186).
- Toda la pure-logic de `App/Logic/` (~1.618): `MemberChangeNotificationLogic`, `GroupJoinReconcileLogic`, `GroupInviteOnboardingLogic`, `BridgeResolverLogic`, etc. (`GroupAcceptShareErrorLogic` se re-mapea de códigos CKError a errores del backend).
- ViewModels (1.983) y Views (9.932) — el refresh por `dataVersion`/`loadData()` (no `@Query`) es agnóstico al transporte.
- El patrón **intent persistente + reconciler** de join (`PendingJoinStore` + `GroupJoinReconciler` + `GroupJoinIntentTracker`) — la regla inviolable "post-accept = intent persistente reconciliable" se CONSERVA, re-targeteada al RPC de join (offline/retry siguen existiendo).
- El **router de quiescencia** (5/5 del paquete de endurecimiento, `StorageModeSignalRouter`): el mainContext sigue compartido — los apply del canal de grupos se gatean por la quiescencia del motor personal ACTIVO (la disciplina de la saga de Grupos no cambia).

---

## 2. Identidad y membership

**El miembro es la cuenta nube.** `member.user_id = sub` del JWT (Supabase Auth). `isCurrentUser` deja de ser un flag device-local reescrito por `refreshCurrentUserFlags` comparando `cachedRecordName` — se deriva de `member.user_id == session.sub`.

**`member_key` — el desacople que evita reescribir el historial.** Hoy TODAS las FKs de miembro en el historial (`SplitExpense.paidByMemberID`, `SplitSettlement.fromMemberID/toMemberID`, `SplitShare.memberID`) apuntan al string `cloudKitUserRecordID`, NO al `SplitMember.id`. El diseño introduce `member_key: String` = identificador estable del miembro DENTRO del grupo, al que apuntan las FKs del historial:
- Miembros nuevos: `member_key = sub`.
- Miembros migrados de CloudKit: `member_key = su userRecordID viejo` (el historial migra byte-idéntico, cero remap de filas de gastos).
- La fila de member porta `(group_id, member_key)` como PK + `user_id UUID` (el `sub`; NULL para miembros migrados que aún no re-entraron). El re-join rebindea `user_id` sobre la fila existente (§9), jamás toca el historial.

> **CORRECCIÓN (2026-07-15, verificada en código durante G3 — ⚠️ REPLICAR AL VAULT, esta nota vive solo en la copia del repo):**
> la premisa de arriba ("las FKs del historial apuntan a `cloudKitUserRecordID`") es **FALSA en el código real**:
> apuntan a **`SplitMember.id.uuidString`** (`MemberPickerView.swift:26` construye la selección con
> `member.id.uuidString`; `GroupBalanceService.swift:63-66` matchea por `id.uuidString`; `CKRecordTranslator`
> transporta esas FKs crudas a CloudKit). El desacople del diseño SIGUE en pie, con un eslabón extra:
> `member_key` identifica la **fila** de member, y las FKs del historial usan el **id determinista derivado de
> `(groupID, member_key)`** — CloudKit-era: `deterministicUUID("SplitMember", "{zoneID}:{recordName}")`
> (`GroupService.swift:90-93`); backend-era born-remote: `GroupBackendIdentityLogic.deterministicMemberID`
> (namespace `"SplitMemberBackend"`). La convergencia cross-device se sostiene DENTRO de cada mundo porque
> todos los devices derivan el mismo id desde el mismo `(groupID, member_key)`. Consecuencias:
> (a) las columnas wire `*_member_key` del canal G2 transportan `id.uuidString`, NO member_keys crudos —
> naming engañoso pero contrato CONGELADO por los goldens, no se renombra;
> (b) el rebind de §9 sigue sin tocar el historial (la fila de member rebindea `user_id`; las FKs ya apuntan
> al id derivado del member_key legacy, que no cambia);
> (c) nace el riesgo **R10** (§13) para G6 — el cruce de namespaces entre mundos.

**`SplitMember.id` determinístico** se conserva como molde con namespace nuevo: `SHA256("SplitMember:{groupID}:{member_key}")` — mismo usuario, mismo grupo ⇒ mismo UUID en todos sus devices sin coordinación (hoy: `GroupUserIdentityService.deterministicMemberID`, se reimplementa sin CloudKit).

**Requisito de cuenta (consecuencia de producto, decisión D3/D5):** crear o unirse a un grupo exige sesión nube. El modo "Solo Grupos" pasa de "iCloud sin cuenta" a **"cuenta nube usada solo para grupos"**: el store personal del invitado sigue LOCAL (su `storageMode` no cambia — cuenta nube ≠ storage nube). Si después activa Yala completo (`FullModeActivationView`) y elige nube, la MISMA cuenta claimea lo personal (`claim_account` ya existente). Esto **resuelve de paso**: [[MODO-NUBE-DIFERIDOS]] #17 ("solo grupos nube" deja de ser contradictorio), el riesgo A21/A32 (born-cloud sin iCloud SÍ puede usar grupos), GAP 1 de `gap-estados` (muere la dependencia de `CKContainer.userRecordID()`), y M1-3.

**UNA sola cuenta por sesión — invariante duro (pregunta owner 2026-07-14).** La app tiene UNA sesión de backend (un `sub`); el canal de grupos y el sync personal usan el MISMO JWT. NO existe "Apple para grupos y Google para personal": serían dos cuentas distintas = la doble identidad que este pivote mata. Enforcement (no solo convención): **con sesión viva, TODO flujo que active la nube (migración personal, born-cloud tardío, claim desde FullModeActivation) REUSA la sesión existente y NO muestra sign-in** — el patrón `startAdoptWithExistingSession` del trabajo de sign-out (H4) es el molde. El hazard concreto que esto cierra: usuario con Google-para-grupos que al migrar lo personal tocara "Sign in with Apple" crearía una SEGUNDA cuenta (grupos en A, personal en B). Bordes cubiertos por el guard de identidad post-sign-in ya diseñado (C4/A30: `GET /account/exists` + aviso de provider-mismatch + canario `cloudSignInProviderMismatch`). Identity-linking (vincular Apple Y Google a la misma cuenta) queda post-v1 — hasta entonces, el proveedor elegido en el PRIMER sign-in (aunque haya sido "solo para grupos") es el proveedor de la cuenta para siempre; el copy del sign-in de grupos debe decirlo ("usarás esta cuenta si algún día migras tus datos").

---

## 3. Modelo de datos server-side (Supabase)

**Identificador de grupo: se PRESERVA el string actual.** `group_id = SplitGroup.cloudKitZoneID` ("SplitGroup-{uuid}") — grupos migrados conservan su valor y grupos nuevos generan el mismo formato. Razón dura: las columnas `split_group_zone_id`/`group_zone_id` del store PERSONAL ya viajan por el backend como TEXT opaco (`tx_items`, `inbox_drafts`, `scheduled_payments`, `group_bridge_prefs`) — preservar el string evita un IdentityRemap-class multi-tabla sobre datos personales ya sincronizados. El nombre de campo local (`groupZoneID`) se conserva (rename cosmético diferido; el invariante §3.5.5 del mapa "el backend jamás remapea estas FKs" sigue intacto).

Tablas nuevas (todas con la cola uniforme del motor: `field_hlcs`, `hlc`, `deleted`, `deleted_hlc`, `server_seq`, `schema_version`, `updated_at`; DELETE revocado — tombstone = `UPDATE deleted=true`):

| Tabla | PK | Notas |
|---|---|---|
| `split_groups` | `(group_id)` | meta del grupo (name†, icon, color, currency, settings, `owner_user_id`) |
| `group_members` | `(group_id, member_key)` | `user_id UUID NULL` (sub; NULL = migrado sin re-join), `display_name`†, `role`, `status`, `joined_at` |
| `split_expenses` | `(group_id, sync_id)` | `sync_id = SplitExpense.id` (identidad inherente, sin syncID sintético per-device) |
| `split_shares` | `(group_id, sync_id)` | |
| `split_settlements` | `(group_id, sync_id)` | |
| `group_invites` | `(token)` | `group_id`, `created_by`, `expires_at`, `revoked`, `uses/max_uses` |
| `group_seq_counters` | `(group_id)` | trigger `stamp_group_seq()` — el eje del pull keyset ES POR GRUPO (gemelo de `sync_seq_counters` per-user) |
| `push_tokens` | `(user_id, device_token)` | registro APNs (D6), `platform`, `updated_at` |

† = columna cifrada con pgcrypto (D4): `amount`, `note`/`expense_description`, `display_name`, `split_groups.name`. La llave NO vive en la DB — el Worker la inyecta por request (`SET LOCAL app.enc_key`); las funciones autorizadas (apply/pull/merkle) desencriptan internamente y **el Merkle computa sobre el plaintext canónico** (determinismo garantizado — cifrar dentro del Merkle rompería la convergencia por nonce aleatorio). Patrón exacto a validar en el spike G0.

**Anti-abuso heredado de `sanitizeAmount`:** la validación de ingestión (|amount| < 1e12, hoy `CKRecordTranslator.sanitizeAmount` porque la zona CKShare es `.readWrite`) queda cubierta por los límites del canon c1 ya vigentes (|dinero| < 10¹⁴, rechazo de no-finitos) + validación en el RPC de apply — de serie, no trabajo nuevo.

## 4. Autorización: RLS por membership + RPCs (D2)

- **Policies** en las 5 tablas de grupo: `EXISTS (SELECT 1 FROM group_members m WHERE m.group_id = <tabla>.group_id AND m.user_id = (select auth.uid()) AND m.status IN ('active','pendingApproval'))` — lectura; escritura restringida a `active` con `canWrite` (la semántica de `SplitMemberStatus` existente). `group_invites` legible solo por members admin; `push_tokens` per-user clásico.
- **ENDURECIDO por el review adversarial de G1 (2026-07-15, aplicado en staging):** (S2) `pendingApproval` NO lee el contenido financiero — el SELECT de `split_expenses/shares/settlements` exige `is_group_writer` (active); la sala de espera ve solo grupo + roster (`split_groups`/`group_members` con `is_group_member`). (S3) `group_members` está CONGELADA a escritura directa (REVOKE UPDATE completo — el grant de columnas habría permitido a un member estampar HLCs futuros en la unidad membership y BLOQUEAR su remove/approve en el LWW de G2): rename SOLO vía RPC `update_member_display_name`; **`group_members` es PULL-ONLY en el canal de sync**. Residual aceptado documentado: un admin puede envenenar `field_hlcs` de la unidad `meta` de `split_groups` (display stale; `owner_user_id` es server-only y el server siempre tiene la verdad).
- **RPCs SECURITY DEFINER** (validación interna, molde `claim_account`): `create_group` (grupo + member owner atómico), `join_group(token, display_name, legacy_member_key?)` (valida token vivo → inserta member `pendingApproval`/`active` según settings, o REBINDEA `user_id` si `legacy_member_key` matchea un migrado, §9), `approve_member`, `remove_member`, `leave_group`, `revoke_invite`.
- **Gate de release nuevo:** el test cross-user 18/18 (`qa/cloud/cross-user-rls-test.sh`) se extiende con la matriz **cross-member**: (a) no-miembro no lee/escribe NADA de un grupo; (b) miembro `pendingApproval` lee pero no escribe; (c) member removido/`left` pierde acceso; (d) un member no puede escalar su propio `role`; (e) token revocado/expirado no une. Su fallo BLOQUEA el release (mismo rango que el gate 18/18).

## 5. Canal de sync cliente: `GroupsSyncClient` (D1)

Segundo canal de dominio sobre el mismo transporte (`SyncHTTPSession` + JWT + attest), hermano de `PrefsSyncClient`, corriendo piggyback en el ciclo de `CloudSyncRuntime` (paso nuevo 5.6, tras prefs) **o** en su propio loop si el usuario es "solo grupos" (cuenta nube sin `.cloud` personal — el runtime personal no corre para él; el canal de grupos necesita arranque independiente gateado solo por sesión viva).

- **Captura:** el drain de grupos lee la MISMA History del container único (personal+grupos+sync-meta comparten `mainContext`). El muro `personalEntityNames` (`CloudSyncEngine.swift:787-804`, anti-fuga deliberado) se conserva para el motor personal; el drain de grupos usa el set complementario `groupEntityNames` (los 5 `Split*`). **Cada canal ignora las entidades del otro — mismo token de History, dos consumidores con cursores propios** (el token es por-container; cada drain filtra por entity set y dedupea por su propio anchor `lastDrainedTxAt`, el molde del HALLAZGO 2). Anti-eco: los apply del canal de grupos escriben bajo el MISMO `outboxSaveAuthor`.
- **Outbox/cursor:** `GroupSyncOutbox` + cursores por grupo (`GroupSyncCursor`: filas `(group_id, server_seq_cursor)`) en el store sync-meta `.none`. Espejo App Group para durabilidad (patrón `SyncOutboxMirror`) — mismo A1.
- **Push:** RPC `apply_group_delta(p_group_id, p_entity, p_sync_id, p_op, p_fields, p_field_hlcs, p_row_hlc, p_schema_version)` — gemelo de `apply_delta` con scope de grupo; RLS + policies de §4 arbitran. PATCH por unidad de coherencia; grupos de coherencia de las entidades split (money del expense, el trío shares) se declaran en el manifest.
- **Pull:** `GET /groups/pull` con el mapa de cursores `{group_id: seq}` → deltas por grupo (keyset por `server_seq` DE GRUPO) + una sub-respuesta de **memberships** (`group_ids` actuales del `sub`) para descubrir grupos nuevos/perdidos sin endpoint extra. Grupo que desaparece de memberships ⇒ limpieza local (la semántica actual de `performRemovedSelfCleanup`).
- **Apply:** gemelo de `SyncApplyEngine` para los 5 `Split*` (appliers, tombstones, dangling refs cross-entidad p.ej. share→expense). Al terminar una página: `markRemoteChangePending()` → `dataVersion` (el refresh de las vistas de Grupos NO cambia) y el hook del **bridge remoto** (`processPendingRemoteChanges`) se dispara desde aquí en vez del fetch handler de CKSyncEngine — el gate 5/5 por `StorageModeSignalRouter.quiescenceSource` queda byte-idéntico.
- **LWW/HLC:** el MISMO `HLC.swift` (tenant-agnóstico — nodeID per-device arbitra entre escritores del grupo igual que entre devices propios). Conflicto = field-level LWW por unidad, política que SUSTITUYE el "server wins" actual de `handleConflict` (mejora, no regresión: hoy server-wins pisa ediciones concurrentes enteras).
- **Merkle por grupo:** `GET /groups/merkle?group_id=` — root sobre las filas del grupo (plaintext canónico, §3); el cliente verifica cada grupo a cadencia baja (30min, la de `merkleMinInterval`). N members convergen sobre el MISMO root — la red anti-divergencia que CloudKit daba implícito.
- **Manifest:** `group_capability_manifest.json` propio (o sección `scope: group` del existente — decidir en G1 por lo que simplifique los parity tests). `CloudCapabilityManifestParityTests` se extiende.
- **IMPLEMENTADO en G2 (2026-07-15) — precisiones sobre este diseño:** manifest PROPIO `group_capability_manifest.json` (raíz) con flags nuevos `pull_only` (`group_members` — consecuencia del freeze S3) y `push: update_only` (`split_groups` — los grupos nacen SOLO vía `create_group`; upsert de inexistente = noop `group_not_found`); unidades de coherencia: `gmoney` (amount+currency del expense), `gshare` (trío expense_id+member_key+amount), `smoney` (amount+currency del settlement), y server-side `{profile, membership}` en members + `{meta}` en groups (los RPCs estampan `field_hlcs` POR UNIDAD para que el LWW de G2 no pise una aprobación con un delta stale). `SplitMember` JAMÁS se emite desde el cliente; se aplica pull-only por `member_key`. Residuales dark documentados para G4+: paginación del pull (no re-pullea hasta agotar), `upstream_400` tratado como transitorio, noop `group_not_found` purga la fila de outbox de meta (garantizar orden create_group→sync en G3+), breadcrumbs del token guard pendientes de añadir antes de encender.
- **C3 a escala multi-usuario — por qué NO se hereda entera:** el miedo dimensionado en la decisión del 13/07 era perder el dedup implícito de CloudKit. Las entidades de grupo tienen **identidad inherente** (UUID creado UNA vez por el device autor, jamás syncID sintético per-device) + PK server `(group_id, sync_id)` ⇒ el upsert-por-identidad da el mismo dedup que CloudKit. La única C3 real sigue siendo la del BRIDGE (representación TX-real-vs-virtual por `bridgeOverride`), ya diseñada en §i.8(a)3 + reconciliador §d.4 punto 4 — sin cambios.

## 6. Invites sin CKShare (D5)

- **Link:** mismo dominio (`https://yala-app.pe/invite`) con parámetros nuevos (`g=<group_id>&t=<token>` + los cosméticos actuales n/i/c/m/u). El token se crea con `create_invite` (RPC o vía `group_invites`) — revocable, con expiración; **muere el problema "el CKShare URL cambia"** (el link es estable mientras el token viva; regenerable a voluntad).
- **Flujo de aceptación:** universal link → handler nuevo (sucesor de `CKShareEntryHandler`, mismas señales de routing que hoy son 100% locales: `hasCompletedOnboarding`, `onboardingMode`, `currentMemberStatus` — ahora consultado al backend o al cache local) → si no hay sesión nube: **sign-in SIWA/Google primero** → `join_group(token)` → intent persistente (`PendingJoinStore` re-targeteado: el join puede fallar offline → reconciler con los mismos 4 triggers) → `pendingApproval`/`active` según settings del grupo → onboarding de invitado (`GroupInviteOnboardingView`, mismo silent-setup, gate de quiescencia vía router).
- **La ventana export-only de 60s MUERE:** el join es un RPC síncrono contra el backend — el member existe server-side al confirmar, y el pull siguiente lo trae. El bug de Pia (2026-07-11) es estructuralmente imposible en el diseño nuevo; el reconciler queda como red de offline, no como cura de una ventana estructural.
- **Errores:** `GroupAcceptShareErrorLogic` se re-mapea (token inválido/expirado/revocado, sin sesión, sin red, cuenta suspendida) — copy claro, regla "cero silencios" intacta.

## 7. Push — APNs propio (D6)

- **Registro:** el cliente sube su device token a `push_tokens` (por `user_id`; se limpia en sign-out).
- **Fan-out:** tras un `apply_group_delta` exitoso, el Worker envía push **silencioso** (`content-available`) a los tokens de los demás members del grupo (excluye al autor). El cliente despierta → pull del canal de grupos → las notifs se construyen CLIENT-SIDE con la maquinaria existente (`GroupNotificationService` con su filtro de participación y rate-limit por grupo; `MemberChangeNotificationLogic` con autoexclusión + baseline — el baseline `initialMemberImportStartedAt` se re-ancla al PRIMER pull de un grupo recién unido, misma semántica).
- **Paridad honesta:** CKSyncEngine hoy también usa push silencioso (mismas restricciones de throttling de iOS) — esto es PARIDAD, no regresión. Push VISIBLE server-side queda fuera de v1 (exigiría PII en el payload o Notification Service Extension — evaluar post-v1 si el throttling muerde).
- **Spike G0 obligatorio:** APNs desde Cloudflare Workers (HTTP/2 + JWT p8 vía fetch) — verificar empíricamente antes de construir encima; y medir el comportamiento real del silent push en device.

## 8. Privacidad y consentimiento (D4)

- **Minimización:** el server guarda del miembro: `sub` (opaco), `display_name` = ALIAS elegido (el onboarding de invitado ya pide nombre — el copy lo re-encuadra como alias), y los datos del grupo. **No se pide ni almacena email** (SIWA lo permite; Hide My Email disponible para quien lo use).
- **pgcrypto** sobre las columnas † de §3 — permite decir "tus montos y nombres van cifrados" en el consentimiento; protege dumps/backups (el vector probable), no un compromiso del server vivo (honestidad en el copy interno, no en el marketing).
- **Consent screen de grupos** (nueva, al crear/unirse al PRIMER grupo): "los grupos son compartidos por naturaleza y viven en la nube de Yala; tus datos personales siguen donde tú elegiste (privado en iCloud o nube)". Registra `groupsConsentAcceptedAt`/`textVersion` (molde `cloudConsentAcceptedAt` §2.8). Keys l10n ×16.
- **La historia de producto:** "Tus datos personales, donde tú decidas. Los grupos, al ser compartidos, viven en la nube de Yala con lo mínimo: un alias y los gastos del grupo."

## 9. Migración de grupos vivos CloudKit→backend (D7)

Población: beta TestFlight gateada (`groupsBetaUnlocked`), grupos reales contados con una mano. Diseño proporcionado a eso:

1. **Freeze + marcador:** al actualizar, el DUEÑO de cada grupo corre la migración (automática al arrancar con el flag ON, con progreso visible): sube el historial COMPLETO (grupo, members con `member_key` = userRecordIDs viejos y `user_id` = NULL salvo el suyo, expenses/shares/settlements byte-idénticos) vía el canal de grupos, y al confirmar escribe en el `GroupMeta` de CloudKit el campo nuevo `movedToBackend` (⚠️ **regla inviolable: field key nuevo en el container de grupos = deploy a Production + `cloudkit-groups-production.ckdb` en el MISMO PR**, enforced por `CloudKitGroupsSchemaParityTests`). El owner tiene TODO el dataset localmente (cache completo del grupo) ⇒ el upload one-shot no depende de otros devices.
2. **Miembros al actualizar:** ven el marcador en su copia local → el grupo aparece "se movió — vuelve a entrar" con CTA → sign-in (si no tienen cuenta) → el owner comparte el link nuevo (o el marcador porta el token de re-invite, decidir en G6 — preferible: token en el marcador, cero coordinación humana) → `join_group(token, legacy_member_key: su userRecordID local)` → el server REBINDEA `user_id` sobre su fila de member existente ⇒ todo su historial (paidBy/from/to/shares) le pertenece de nuevo, sin tocar una sola fila de gastos. **AJUSTE de seguridad (review G1, S1 — implementado):** el rebind queda **`pendingApproval`, JAMÁS `active` directo** — el `member_key` legacy es ENUMERABLE por cualquier pending (el roster es visible en la sala de espera), así que active-directo era un bypass de aprobación + impersonación del historial migrado; el historial se recupera igual al aprobar (fricción mínima: un tap del admin por miembro re-entrante, coherente con el flujo de aprobación vigente).
3. **Residuales documentados:** (a) un miembro en versión VIEJA no ve el marcador y sigue escribiendo a la zona CloudKit congelada — esas escrituras se pierden (población beta diminuta, TestFlight actualiza rápido; sin gate de versión server-side posible en CloudKit); (b) un miembro que re-entra desde un device FRESCO sin datos locales no puede presentar `legacy_member_key` → entra como member nuevo y su historial queda en el member migrado sin claim (el owner ve ambos; merge manual diferido); (c) CloudKit NO se borra en v1 — zona congelada como red de lectura (borrado = decisión posterior, molde "Borrar mi copia antigua en iCloud" §m); (d) **DECISIÓN PENDIENTE DE G6 — namespace de derivación (hallazgo G3, 2026-07-15; ⚠️ replicar al vault):** el historial migrado lleva FKs derivadas del namespace CloudKit (`"SplitMember:{zoneID}:{recordName}"`), pero `applyMember` del canal backend deriva los ids born-remote con el namespace propio (`"SplitMemberBackend:{groupID}:{member_key}"`) → en un device FRESCO que pullea un grupo migrado, los members materializados NO matchearían las FKs del historial (balances rotos). Los devices con el member PREEXISTENTE no se ven afectados (la adopción dual-match de G3 conserva el id CloudKit-era). G6 debe elegir: derivación namespace-aware en el apply (usar el namespace CloudKit cuando el member_key es un recordName legacy / el grupo es migrado) o remap de FKs en el uploader del owner.

## 10. Impacto en la app

- **M1 secundaria (D8):** el store de grupos pasa al patrón por-sesión (`YalaGroups-Secondary` por archivo, junto a `YalaModel-Secondary`); tab Grupos VISIBLE en secundaria con los grupos de la cuenta de esa sesión. Mueren M1-2 (item fantasma en "Más") y M1-3 (invite respondido con identidad del dueño) por construcción. El diseño M1 (`MODO-NUBE-M1-DISENO-MULTICUENTA`) se re-evalúa con este delta: Grupos deja de estar excluido de la secundaria (`AppBootstrapper.swift:280`) y el `TabBarConfiguration.forMode` deja de filtrarlo.
- **Wipes/sign-out:** `performSignOutWipeIfArmed` (`SwiftDataConfiguration.swift:283`) pasa a borrar TAMBIÉN el archivo del store de grupos (hoy lo preserva "atado al iCloud del OS" — razón que muere); todo re-baja del backend al volver. El wipe secundario M1 igual. Re-decisión del guion de sign-out registrada.
- **Onboarding de invitado:** `.groupInvite` = link → sign-in → join → onboarding actual. `FullModeActivationView` mantiene su delta ya diseñado (§i.8 b1, selector de storage) — con la simplificación de que la CUENTA ya existe; elegir nube = claim de lo personal con la misma cuenta.
- **Bridge personal:** INTACTO a nivel API/escritura (transport-agnóstico confirmado). Cambian solo los triggers: el bridge remoto se dispara desde el apply del canal nuevo; el gate de quiescencia sigue enrutado por `StorageModeSignalRouter` (5/5). Las columnas `split_*` personales NO se tocan (§3, group_id preservado).
- **Paquete de endurecimiento 13/07:** sobreviven 1/5 (test e2e bridge→drain→outbox) y 5/5 (router); 2/5 (`GroupAcceptShareErrorLogic` — se re-mapea, el molde sirve), 3/5 (gate sin-iCloud) y 4/5 (boot-guard Apple ID) quedan obsoletas-según-diseño y se RETIRAN al cutover (no antes: siguen protegiendo el mundo CloudKit hasta G6).
- **Beta gate** (`groupsBetaUnlocked`): ortogonal, se conserva tal cual (decisión de producto aparte cuándo retirarlo).
- **Seguridad heredada que se simplifica:** muere la clase de incidentes de schema CloudKit para grupos NUEVOS (el `isOpeningBalance`-class); el canario `cloudkitGroupRecordSaveRejected` queda vigilando solo la época congelada hasta el retiro.

## 11. Plan de incrementos (G0–G8)

Dark shipping sobre trunk (estrategia vigente); flag nuevo `groupsBackendEnabled` subordinado a `cloudModeEnabled`. Cada incremento con sus gates (suite + goldens + builds; device-QA donde se indica).

| Inc | Alcance | Gates específicos |
|---|---|---|
| **G0** | **Spikes bloqueantes:** (a) APNs desde CF Workers (p8/HTTP-2 vía fetch) en device real; (b) pgcrypto con llave por request (`SET LOCAL`) + Merkle sobre plaintext — round-trip completo en staging; (c) silent push real (throttling) | ambos spikes VERDES antes de construir G1/G7/G8 encima |
| **G1** | **Schema server + autorización:** 8 tablas (§3) + trigger seq-por-grupo + RLS membership + RPCs (§4) en staging; goldens TS nuevos; **test-gate cross-member** (§4); server-side de eliminar-cuenta con grupos (anonimización de member + tombstone de grupos huérfanos, §15) | goldens + cross-member verde; DDL/manifest parity; golden de anonimización |
| **G2** | **Canal cliente:** `GroupsSyncClient` (drain `groupEntityNames`, outbox/cursores por grupo, push/pull/apply, Merkle por grupo, memberships discovery); manifest de grupos + parity tests; arranque para "solo grupos" sin runtime personal | e2e staging 2 cuentas × 1 grupo compartido convergiendo; suite completa |
| **G3** | **Identidad + membership cliente:** `member_key`, `isCurrentUser` por `sub`, retiro de `GroupUserIdentityService`, `refreshCurrentUserFlags` re-anclado, deterministicMemberID nuevo namespace | tests de identidad; regresión de balances (`GroupBalanceService` con member_key) |
| **G4** | **Invites + join:** tokens server-side, links nuevos, handler sucesor de `CKShareEntryHandler`, join intent re-targeteado (reconciler 4 triggers), sign-in del invitado en el flujo, errores re-mapeados; consent screen de grupos + l10n ×16 | e2e invite 2 cuentas staging; XCUI del flujo local |
| **G5** | **Cutover interno + M1/wipes + gestión de datos (§15):** escritura de grupos NUEVOS al backend bajo flag; store de grupos por sesión (D8); wipes incluyen grupos; tab visible en secundaria; retiro de gates obsoletos (3/5, 4/5) DETRÁS del flag; sign-out con la fila NUEVA "sesión solo-grupos" (matriz 3 filas); "Vaciar mis datos" con copy "tus grupos no se tocan"; eliminar-cuenta cliente; export ampliado con grupos | verificación sim 3 estados; suite M1 re-verde; matriz de sign-out ×3 testeada |
| **G6** | **Migración de grupos vivos (D7):** marcador `movedToBackend` (**deploy CloudKit Production + .ckdb mismo PR**), uploader one-shot del owner, re-join con `legacy_member_key`, UI "el grupo se movió"; "borrar copia congelada de grupos" (§15) | device-QA cross-device TestFlight (guion nuevo, 2 cuentas reales); paridad .ckdb |
| **G7** | **pgcrypto (D4):** cifrado de columnas † + migración de datos de staging + llave en Worker | round-trip + Merkle verdes con cifrado ON; cross-member re-verde |
| **G8** | **APNs (D6):** `push_tokens`, fan-out en el Worker, silent push → pull → notifs client-side; limpieza de token en sign-out | device-QA: notif de gasto nuevo con la app cerrada, 2 devices |

Post-G8: retiro del código CloudKit de grupos (SplitSyncManager/CKRecordTranslator/SplitZoneManager) en un incremento de limpieza SEPARADO, solo tras el período de convivencia con grupos congelados.

**Orden relativo con el trabajo personal pendiente:** los pendientes del gate de flags personal (CAS del `reverse_claim`, #30 drenaje KV, enforcement del freeze en `/sync/push`) corren en paralelo o antes — G0/G1 no los pisan (tablas y rutas disjuntas).

## 12. Gate de flags de v1 (ampliado, D9)

El encendido de `cloudModeEnabled` (beta) pasa a exigir, ADEMÁS de lo ya listado (IdentityRemap #29 ✅, huérfano #30, CAS reverse_claim, enforcement freeze, bug FX ✅):
- G1–G8 completos, con el test-gate **cross-member** al rango de gate de release.
- Device-QA de G6 (migración de grupos vivos) y G8 (push) VERDES en TestFlight.
- Canarios nuevos en TelemetryDeck: `groupPushRejected(code)`, `groupJoinFailed(reason)`, `groupMerkleDivergence(groupCount)`, `groupApnsSendFailed`, `groupLegacyRebindFailed` — todos 0 en dogfooding antes de abrir cohorte.
- Los guiones de QA parkeados se retoman re-evaluados: del guion M1 caen las fases G1–G3 viejas (gates iCloud) y entra la matriz secundaria-con-grupos; el guion sign-out incorpora el wipe de grupos.

## 13. Riesgos y residuales del diseño

| # | Riesgo | Mitigación |
|---|---|---|
| R1 | Retirar el muro `personalEntityNames` mal ⇒ fuga cross-canal (Split* al canal personal o viceversa) | dos sets COMPLEMENTARIOS explícitos + test de partición (toda entidad del container en exactamente un set) + canario de columna inesperada existente |
| R2 | pgcrypto × Merkle (determinismo/latencia) | spike G0(b) bloqueante; fallback documentado: pgcrypto solo en `note`/`display_name` y montos en claro (re-decisión owner si el spike muerde) |
| R3 | Silent push throttled ⇒ notifs tarde | paridad con CloudKit hoy (mismo mecanismo); post-v1: push visible con NSE |
| R4 | Miembro en versión vieja escribe a la zona congelada | pérdida documentada, población beta diminuta; el marcador + freeze evita la doble verdad (peor que la pérdida) |
| R5 | Re-join desde device fresco sin `legacy_member_key` ⇒ historial sin claim | residual documentado; merge manual/asistido diferido con gatillo |
| R6 | El invitado "solo grupos" necesita el canal corriendo SIN runtime personal | arranque propio del canal gateado por sesión (G2); es la única pieza donde el piggyback no basta |
| R7 | C3 del bridge (representación divergente) — SIN cambios respecto al diseño vigente | §i.8(a)3 + reconciliador §d.4 punto 4 tal cual |
| R8 | Costo Supabase con fan-out de grupos | el `observe` mode y el gate de costo §j.2 cubren también las rutas de grupos |
| R9 | Segunda cuenta accidental (Google-para-grupos + "Sign in with Apple" al migrar lo personal ⇒ grupos en cuenta A, personal en cuenta B) | invariante "una sola cuenta por sesión" (§2): sesión viva ⇒ reusar SIEMPRE, jamás re-ofrecer sign-in; guard C4/A30 (`/account/exists` + provider-mismatch) en los bordes; copy del primer sign-in avisa que esa será LA cuenta |
| R10 | Grupo MIGRADO en device fresco: FKs del historial (namespace CloudKit) vs ids born-remote (namespace backend) no matchean ⇒ balances rotos (hallazgo G3 2026-07-15, ver corrección §2 y §9.3d — ⚠️ replicar al vault) | decidir en G6: derivación namespace-aware en `applyMember` o remap de FKs en el uploader del owner; devices con members preexistentes NO afectados (la adopción dual-match de G3 conserva el id CloudKit-era) |

## 14. Matriz de personas — qué le pasa a cada tipo de usuario (owner-reviewed 2026-07-14)

Dos verdades transversales: **(a) cuenta nube ≠ datos personales en la nube** — el sign-in crea identidad (`sub`), el store personal sigue donde el usuario eligió; **(b) grupos es one-way** — la reversa §h es SOLO del store personal, un grupo en el backend jamás vuelve a CloudKit.

| # | Persona | Qué le pasa |
|---|---|---|
| P1 | `.icloud` que NO quiere nube, CON grupos | **El único con fricción nueva.** Lo personal no se toca jamás. Para seguir en sus grupos: sign-in (cuenta usada SOLO para grupos). Dueño ⇒ migración owner-migra (§9); miembro ⇒ "el grupo se movió" → re-join con rebind automático (`legacy_member_key`). Si RECHAZA la cuenta: grupos congelados en solo-lectura local con CTA — no pierde historial del device, no puede seguir participando. El consent copy (§8) se gana a este usuario o lo perdemos. |
| P2 | `.icloud` que NO quiere nube, SIN grupos | Cero cambios, cero avisos, cero cuenta — su app sigue siendo 2.x (el flag protege el runtime). Si algún día quiere grupos → P6. |
| P3 | `.icloud` CON grupos que migra completo | Camino feliz: UNA cuenta para todo. Sign-in → migra personal (I10) → grupos con la misma cuenta (dueño §9 / miembro re-join). Cero dependencia del Apple ID del OS. Matiz: si luego ejecuta la REVERSA, solo lo personal vuelve a iCloud — queda como P1-sin-fricción (cuenta ya viva sirviendo grupos). |
| P4 | `.icloud` SIN grupos que migra completo | I10 tal cual. Si algún día toca Grupos ya tiene cuenta: consent de grupos y listo. |
| P5 | Nuevo invitado por enlace | Link → sign-in (un tap, Hide My Email disponible) → `join_group` → onboarding de invitado actual. Personal LOCAL (modo solo-grupos nuevo). El bug de Pia es imposible por construcción (join = RPC síncrono). Activación full posterior: elige storage personal; la MISMA cuenta claimea si elige nube. |
| P6 | Nuevo, onboarding normal, elige privado (iCloud) | Onboarding actual intacto, sin cuenta. Primer grupo (crear o invite) → sign-in solo-grupos en ese momento (→ P5), lo personal se queda donde está. |
| P7 | Nuevo born-cloud | Una cuenta para todo desde el día uno. Mejora directa: **Grupos sin iCloud en el device** (muere el gate — resuelve A21/A32, #17). |
| P8 | "Solo Grupos" actual de la beta (`.groupInvite`) | Hoy: grupos vía iCloud sin cuenta. Al actualizar: sign-in → re-join (casi siempre miembro) → sigue solo-grupos pero con cuenta. P1 en miniatura, con conversión esperable alta (ya demostró que los grupos le importan). |
| P9 | Sesión secundaria M1 (invitada en device del dueño) | Con su cuenta ve SUS grupos (store por sesión, D8), tab visible. Mueren M1-2 y M1-3 por construcción. |
| P10 | Miembro en versión VIEJA (no actualizó) | No ve el marcador; sigue escribiendo a la zona CloudKit congelada ⇒ **esas escrituras se pierden** (R4, aceptado — población beta diminuta). Al actualizar → P1-miembro, recupera el grupo server-side sin sus escrituras de la ventana ciega. |
| P11 | Miembro que re-entra desde device FRESCO (sin datos locales) | Sin `legacy_member_key` ⇒ entra como miembro NUEVO; su historial queda en el member migrado sin reclamar (el dueño ve ambos). R5; merge asistido diferido. Único caso sin rebind automático. |

Patrón: **quien no toca grupos no nota nada; quien toca grupos necesita cuenta, tenga el storage que tenga.** La matriz es insumo directo del consent copy (§8) y de los guiones de QA de G4/G6.

## 15. Gestión de datos y sesión bajo grupos-en-backend — FRENTE ABIERTO (owner 2026-07-14)

Los botones de §m ([[MODO-NUBE-ARQUITECTURA]]) y el sign-out (H4) se diseñaron con "grupos = CloudKit intocable". Con grupos en el backend, CADA operación necesita re-especificación por escenario. Direcciones propuestas (a cerrar con el owner en el spec de G4/G5 — las marcadas ⚠️ requieren decisión):

- **"Vaciar mis datos"** — sigue siendo del store PERSONAL: en `.cloud` tombstones al backend, en `.icloud` el `DataWipeService` actual. **NO toca grupos**: los gastos de grupo pertenecen al GRUPO (borrarlos rompería los balances de los demás miembros). Salir de un grupo sigue siendo el flujo per-grupo existente (leave). El copy del diálogo debe decirlo explícito ("tus grupos no se tocan").
- **"Eliminar mi cuenta" (GDPR)** — ✅ DECIDIDO (owner 2026-07-14, 2 sub-decisiones): al eliminar, **anonimizar** las filas de member (`display_name` → "Usuario eliminado", `user_id` → NULL, status `removed`) y CONSERVAR los gastos históricos del grupo (registro compartido, interés legítimo de los demás miembros — se documenta en el consent §8); grupos donde es el ÚNICO miembro activo → tombstone completo del grupo. Si es DUEÑO de un grupo con otros miembros activos → **TRANSFERENCIA AUTOMÁTICA del ownership al admin más antiguo (o al miembro más antiguo si no hay otro admin) + notificación al grupo** — eliminar cuenta jamás se bloquea por ser dueño (fricción GDPR-hostil descartada).
- **"Cerrar sesión"** ⚠️ — gana un caso NUEVO que la matriz de H4 no tiene: **sesión solo-grupos con personal en `.icloud`/local (P5/P6/P8, y P3 post-reversa)**. Ahí cerrar sesión NO debe tocar lo personal (no está atado a la sesión): termina la sesión backend + **borra SOLO el store de grupos** (re-descargable al volver, D8) + limpia `push_tokens` del device. El camino `.cloud` actual (push-all verificado → wipe por archivos → relaunch) se AMPLÍA para incluir el archivo de grupos en el wipe (D8) y el push-all verificado del outbox de GRUPOS además del personal. La matriz de sign-out pasa de 2 filas (.icloud/.cloud) a 3 (+solo-grupos).
- **"Exportar mis datos"** — se AMPLÍA: la exportación (red anti-única-copia + portabilidad GDPR) debe incluir una sección de grupos (mis gastos/settlements por grupo, mis balances) — hoy solo cubre lo personal. Formato CSV/JSON igual.
- **"Importar datos"** (CSV) — sin cambios: escribe al store personal; los gastos de grupo jamás se importan por CSV (nacen del flujo de grupo).
- **"Borrar mi copia antigua en iCloud"** — gana un gemelo de grupos: la zona CloudKit congelada post-migración (§9.3c) tendrá su "borrar copia congelada de grupos" con la misma semántica (visible solo si migró grupos; borra la zona; no afecta el backend). Mismo molde §m, decisión de copy en G6.

Cada una entra al plan: sign-out + vaciar + copy en **G5**; eliminar-cuenta (server-side de anonimización + RPC) en **G1** (schema) con cliente en **G5**; export ampliado en **G5**; borrar-copia-congelada en **G6**.

## 16. Pre-flight — auditoría de los procesos actuales (3 exploradores, 2026-07-14)

Pasada de verificación sobre el código vigente ANTES de arrancar la implementación. Veredicto: **ningún bloqueante de diseño nuevo; el plan G0–G8 absorbe todos los hallazgos.** Lo verificado, por frente:

### 16a. Cuenta/sesión — el desacople físico YA existe; el acoplamiento es lógico

- **Tranquilizador:** la sesión (JWT+refresh) vive en Keychain propio (`com.yala.cloudauth`, ThisDeviceOnly) desacoplada de `storageMode` (UserDefaults). `CloudSyncRuntime.canRunDomain()` exige `.cloud` ANTES de mirar la sesión (`CloudSyncRuntime.swift:215,283-287`) ⇒ **una sesión viva con personal `.icloud` es hoy inerte y segura** — exactamente el hueco que la persona solo-grupos rellena. "Sesión sin claim" es un estado ya representable (`LiveCloudSessionProvider.claimAction → nil`; el sign-in NO claimea automáticamente — el claim vive solo en migración/adopt).
- **11 asunciones "sesión ⇒ `.cloud`" enumeradas** (lista exhaustiva en la auditoría); las de impacto alto que G3/G5 deben tocar:
  1. `CloudSignOutFlowLogic.path` es binario por storageMode (`CloudSignOutFlowLogic.swift:37-43`) — la sesión solo-grupos caería en `.privateReset`, que **mata la sesión incondicionalmente** (`CloudSessionSignOut.swift:74`). Es la fila nueva de la matriz de §15, ahora con coordenadas exactas.
  2. El Welcome sign-in siempre desemboca en adopt/secundaria/blocked (`WelcomeCloudSignInView.swift:331-360` + `CrossAccountEntryGuardLogic` — no contempla "sesión sin adoptar el personal"). G4 añade el camino "sign-in para grupos" que NO entra a la máquina de migración.
  3. La UI está keyed por storageMode, no por sesión (fila iCloud `ProfileView.swift:584`, "Migrar a la nube" en StorageSettings) — con sesión solo-grupos ofrecería migrar sin reconocer la sesión; el copy del diálogo de sign-out (`ProfileView.swift:229-236`) mentiría. G5.
  4. PrefsSync corre SOLO en `.cloud` (`CloudSyncRuntime.swift:603`, `PrefsSyncBehavior.resolve`) — las prefs de una sesión solo-grupos siguen en iKV/local. **Coherente, se documenta como comportamiento esperado** (grupos no arrastra las prefs personales al backend).
- **Detalle server-side que G1 debe resolver:** `/account/exists` == "hay fila en `profiles`" y el corpus asume esa fila para el PATCH. La sesión solo-grupos necesita fila `profiles` para la RLS de membership ⇒ **dirección: `create_group`/`join_group` garantizan la fila `profiles` server-side (claim LIGERO de identidad, sin semántica de migración/liderazgo)** — así `/account/exists` sigue significando "esta cuenta tiene algo" y el guard C4 del Welcome no cambia.
- **`/account/delete` confirmado INEXISTENTE** (3 rutas de cuenta: claim/exists/migration) — G1 lo hereda como estaba planeado (era alcance I12).

### 16b. Export/import/wipe — el diseño de §15 no contradice nada; dos precisiones

- **Export** (`TransactionsExportService`): cubre SOLO `TransactionItem`, ya incluye las TX bridgeadas de grupo (no filtra `splitGroupZoneID`) con columnas dedicadas `split_total`/`split_portion`. **Coherente con el diseño**: las TX bridgeadas SON datos personales; la sección de grupos del export ampliado (§15) es ADITIVA (gastos/settlements/balances por grupo), no un cambio del export actual. Asimetría conocida: el import CSV no reconoce columnas split (round-trip pierde esos campos — preexistente, sin acción).
- **Wipe**: `wipeAllUserData` NO toca grupos por ningún camino no documentado (verificado; la exención es explícita y consistente). **Precisión NUEVA para G5:** la señal de wipe cross-device vive en iCloud KV incluso bajo `.cloud` (`PreferenceSyncService` behavior `.cloudOutbox` procesa wipe/onboarding por iKV) — al re-especificar "Vaciar mis datos" en el mundo nube, la propagación del vaciado personal es por TOMBSTONES del backend (ya diseñado en §m) y la señal iKV queda solo para el mundo `.icloud`; grupos JAMÁS entra en esa señal.
- **Precedentes de leave/delete que las RPCs de G1 deben respetar:** `leaveGroup` permite salir CON saldo pendiente (warning, no bloqueo); `softDelete` (owner) BLOQUEA si cualquier miembro tiene balance pendiente (>0.01); `deleteGroup` destructivo está deshabilitado en release. `freezeForSoftDelete` (preservar el rastro financiero personal nileando IDs de split) queda intacto — es transport-agnóstico.
- Hallazgo lateral sin relación con grupos: `hasExportedData` es una señal huérfana (se lee y se limpia, nadie la escribe a `true`).
- "Eliminar cuenta" confirmado inexistente en UI y servicios — la §15 diseña sobre terreno virgen, sin precedente que contradecir.

### 16c. Push y links — la plomería base YA está; G8 es acotado y G4 reusa casi todo

- **APNs:** el entitlement `aps-environment` (Release=production) y el background mode `remote-notification` YA existen (CKSyncEngine los exigía); `registerForRemoteNotifications()` ya se llama al boot (`YalaAppDelegate.swift:21`). **Lo que falta es exactamente 3 piezas cliente** (G8): capturar el device token (`didRegisterForRemoteNotificationsWithDeviceToken` — hoy NO existe), subirlo al gateway (endpoint nuevo + limpieza en sign-out), y el handler de recepción (`didReceiveRemoteNotification` → `syncNow()` del canal de grupos + completionHandler). Durante la convivencia G6→retiro habrá DOS fuentes de push (CloudKit interno + gateway) — el handler debe ser idempotente (el `syncNow()` actual ya está debounced + quiescence-gated). El molde del pull-on-foreground ya existe (`AppBootstrapper.swift:1068-1075`: grupos no auto-fetchea sin push handled → syncNow en cada foreground).
- **Universal links:** el AASA declara `/invite` con query `?s=*` comodín ⇒ **el token de G4 viaja como param nuevo SIN tocar AASA ni entitlements**; la página SSR `invite.astro` y el doble entry point (universal link frío + `onOpenURL` warm + custom schemes `yala://invite`) se reusan tal cual. Lo único CloudKit-acoplado es la resolución `s=<CKShareURL>` (`fetchShareMetadata` con `CKFetchShareMetadataOperation`) — G4 la sustituye por token→backend conservando transporte, `PendingInviteStore`, diferido y routing.
- **R1 se RELAJA:** cero escritores de `Split*` fuera del app target (widgets, App Intents, share extension, colas App Group — todo verificado: alimentan SOLO el store personal). El drain del canal de grupos solo debe capturar el proceso principal; el test de partición de R1 sigue, pero el riesgo de escritor fantasma no existe hoy.

### 16d. Deltas que el pre-flight añade al plan (absorbidos, sin incrementos nuevos)

| Delta | Incremento |
|---|---|
| Claim LIGERO de identidad server-side en `create_group`/`join_group` (fila `profiles` garantizada, sin semántica de migración) | G1 |
| `/account/delete` GDPR (confirmado inexistente — ya estaba en G1/G5 vía §15) | G1 + G5 |
| Rama "solo-grupos" en `CloudSignOutFlowLogic.path` + copy del diálogo + preservar-sesión en el reset personal (coordenadas: `CloudSignOutFlowLogic.swift:37-43`, `CloudSessionSignOut.swift:70-96`, `ProfileView.swift:229-236`) | G5 |
| Camino Welcome/invite "sign-in sin adoptar" que NO entra a `CrossAccountEntryGuardLogic`/máquina de migración | G4 |
| UI de Ajustes reconoce sesión (fila de cuenta con sesión solo-grupos; "Migrar" reusa la sesión viva — R9) | G5 |
| Señal de wipe cross-device: iKV solo para `.icloud`; tombstones para `.cloud`; grupos fuera de ambas | G5 |
| RPCs respetan precedentes: leave-con-saldo permitido, softDelete-owner bloquea con balances, sin delete destructivo user-facing | G1 |
| Handler APNs idempotente con doble fuente de push durante la convivencia | G8 |

### 16e. VEREDICTO Spike B — pgcrypto VIABLE para G7 (corrida 2026-07-14, staging vía MCP)

Migración `g0_pgcrypto_spike` aplicada (historial de migraciones del proyecto; el SQL versionado en `qa/cloud/g0_pgcrypto_spike.sql` ganó el fix `search_path = public, extensions` — **gotcha Supabase: pgcrypto vive en el schema `extensions`**, un `search_path = public` pelado esconde `digest`/`pgp_sym_*`). `bash qa/cloud/pgcrypto-spike-test.sh` → **12/12 PASS**, y la auditoría de logs se AUTOMATIZÓ vía MCP (ya no es manual):

1. **Hash canónico ESTABLE tras re-cifrado** — rekey cambia el ciphertext (salt) y `content_hash` NO → **el Merkle de G7 computa sobre plaintext sin romperse**. El criterio estrella, verde.
2. **Cero fuga de la llave**: (a) logs Postgres — el caso llave-mala registra solo `yala_bad_key` SIN parámetros (sanitización de RPCs + `log_parameter_max_length_on_error=0`); (b) settings de staging: `log_statement=ddl` (las llamadas RPC ni se loggean), `log_min_duration_statement=-1`, params-on-error=0; (c) `pg_stat_statements` normalizado (`$1,$2`), búsqueda de la sentinela literal = 0 hits.
3. **RLS arbitra ANTES de descifrar**: user-B con la llave CORRECTA recibe `yala_not_found` (la fila ni se ve), y el acceso directo devuelve `[]`.
4. **Variante GUC (`set_config` local): NO aporta** — la llave entra igual como argumento y PostgREST es 1 tx por RPC; **G7 usa llave-como-argumento** (más simple). Hipótesis confirmada.
5. **Errores limpios**: llave mala → 400 `yala_bad_key` (jamás basura silenciosa ni la llave en el body).

**Condición para G7 (nueva, del veredicto 2b):** los settings de logging son la config ACTUAL de staging y son mutables — G7 debe ASSERTAR los 3 settings (`log_statement`, `log_min_duration_statement`, `log_parameter_max_length_on_error`) como parte de su gate (extensión del cross-user test o check propio), para que un cambio de config no reabra el vector en silencio. R2 del §13 queda RESUELTO (sin fallback necesario). Cleanup (`g0_pgcrypto_spike_cleanup.sql`) pendiente para el CIERRE de G0 (tras el spike A live).

### 16f. VEREDICTO Spike A (transporte) — Workers NEGOCIA HTTP/2 con APNs ✅ (corrida 2026-07-14, staging)

Con la APNs Auth Key `7H6BUZWKKS` cargada (secret vía stdin, jamás leída; `.p8` cubierto por el gitignore existente) y token DUMMY de 64 hex: `POST /v1/debug/push` → **`status:400` + `apnsId` + `{"reason":"BadDeviceToken"}` desde `api.sandbox.push.apple.com`**. Triple confirmación: (1) el `fetch` de Workers completó el request contra un endpoint HTTP/2-only (sin `transportError`); (2) el **JWT ES256 firmado en el Worker fue ACEPTADO** (no `InvalidProviderToken`/`ExpiredProviderToken`); (3) el topic es válido (no `TopicDisallowed`). APNs rechazó exactamente lo único falso: el token dummy. **La incógnita que condicionaba G8 está DESPEJADA — sin pivote.** Pendiente device (ya no veredicto, solo confirmación e2e): entrega real del push a un token verdadero + regresión CK (gate 7c) + matriz fase C del guion.

## 17. Efectos sobre otros documentos

- **[[groups-backend-v1]]** — actualizado con las decisiones y el plan (es el ticket madre).
- **[[MODO-NUBE-DIFERIDOS]]** — #3 pasa de "programado post-v1" a **EN v1 (este diseño)**; #5 (pgcrypto) se ADELANTA parcialmente (columnas de grupo, G7); #17 queda RESUELTO por D3 ("cuenta nube solo-grupos"); #11 se re-lee bajo el diseño nuevo al cerrar G5.
- **[[MODO-NUBE-ROADMAP-FASE4]]** — Bloque E fila #3 sale del bloque (entra a v1 como G0–G8); el gate de flags se amplía (§12).
- **[[MODO-NUBE-M1-DISENO-MULTICUENTA]]** — delta D8 (grupos por sesión) a foldear cuando M1 se retome.
- **[[MODO-NUBE-ARQUITECTURA]] §i.8** — el "(c) RESTRINGIDOS" muere con el diseño nuevo (el gate iCloud ya no aplica); §i.8(a)3/A29 siguen vigentes (bridge). Fold a v10 pendiente junto al resto.
- **Guiones QA parkeados** ([[MODO-NUBE-M1-GUION-DEVICE]], [[MODO-NUBE-SIGNOUT-WELCOME-GUION-DEVICE]]) — banner ya puesto; re-evaluación de fases al retomar (G5/G6).
- Riesgos A21/A23/A32 (born-cloud sin iCloud × Grupos) quedan resueltos por D3; A29 sin cambios.
