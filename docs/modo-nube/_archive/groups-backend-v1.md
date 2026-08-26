---
status: spec-ready
priority: critica
area: groups
tags: [modo-nube, grupos, backend, replaneo, v1]
created: 2026-07-14
updated: 2026-07-14
---

# Grupos al backend nube EN v1 (replaneo)

**Decisión owner (2026-07-14, durante el device-QA del batch M1):** Grupos deja CloudKit y migra al backend nube (Supabase/gateway) DENTRO de v1 — revierte la dirección (4) de [[MODO-NUBE-GRUPOS-V1-DECISION]] (que lo programaba post-v1). Verbatim del owner: "esto de los grupos me está complicando demasiado la vida, es confuso para los usuarios. Vamos a integrar lo de grupos a v1 y no importa que signifique replanear muchas cosas".

## Detonante (evidencia de la corrida device 2026-07-14)

El costo de producto del híbrido (Grupos=CloudKit/iCloud del OS, personal=backend) materializado en QA real — hallazgos M1-1…M1-4 en [[MODO-NUBE-M1-GUION-DEVICE]]:

- Invite en sesión secundaria enruta por el `YalaGroups` COMPARTIDO → "Ya perteneces" con la identidad del DUEÑO presentada a la invitada + botón muerto (M1-3).
- Tab Grupos fantasma en "Más" en secundaria (M1-2); rutas de grupos muertas contra el tab filtrado.
- Toda la superficie de Grupos depende de QUÉ Apple ID esté en el OS (gate sin-iCloud, boot-guard de identidad, CKShare) mientras la cuenta de la app es otra — dos identidades simultáneas que el usuario no entiende.

## Qué ya existe para arrancar el replaneo

- **La dirección técnica ya estaba diseñada como post-v1:** DIFERIDOS #3 de [[MODO-NUBE-DIFERIDOS]] (Grupos→backend, primer incremento tras v1) — ahora se adelanta. El descarte del híbrido "por aprobación" (doble verdad + reconciliador bidireccional) SIGUE vigente: la migración es completa, no híbrida.
- **Evidencia técnica de la decisión supersedida que sigue válida:** bridge→motor completo (columnas `split_*` con paridad testeada, test e2e 1/5 `GroupBridgeCloudSyncIntegrationTests`), cero acoplamiento Grupos↔storageMode, `GroupBridgePreference` ya es entidad personal sincronizada.
- **Inventario del subsistema:** [[inv-grupos]] + gap-docs (`gap-estados`, `gap-cross-feature`).
- **Del paquete de endurecimiento 5/5 (2026-07-13):** sobreviven 1/5 (test e2e bridge) y 5/5 (router de quiescencia); quedan obsoletas-según-diseño 2/5 (error invite secundaria — la secundaria cambia de forma), 3/5 (gate sin-iCloud) y 4/5 (boot-guard Apple ID) — son parches a problemas que solo existen porque Grupos vive en CloudKit.

## Alcance del replaneo — ✅ DISEÑADO (sesión 2026-07-14)

> **Diseño completo en [[MODO-NUBE-GRUPOS-BACKEND-V1-DISENO]]** (9 decisiones del owner + modelo de datos + canal de sync + invites + APNs + migración + plan de incrementos G0–G8). Resumen de las decisiones:

| Frente | Decisión owner (2026-07-14) |
|---|---|
| 1. Modelo multi-tenant + RLS | Tablas de grupo PK `(group_id, sync_id)` + `group_members`; **RLS por membership + RPCs SECURITY DEFINER** puntuales (join/approve/leave). El gateway sigue sin service_role. `group_id` PRESERVA el string `cloudKitZoneID` (las columnas `split_*` personales ya sincronizadas no se remapean). |
| 2. Invites sin CloudKit | **Tokens propios** (`group_invites`, revocables, con expiración) en el mismo dominio de link. Muere el CKShare URL y la ventana export-only del bug de Pia. Join = RPC + intent persistente (reconciler re-targeteado, red de offline). |
| 3. Canal de sync | **Canal APARTE** (`GroupsSyncClient`, patrón `PrefsSyncClient`): seq por grupo, cursores por grupo, Merkle por grupo. Reusa HLC/LWW + canon c1 + transporte/auth/attest. No toca los 4 invariantes per-user del motor de 16 entidades. |
| 4. Migración de grupos vivos | **Owner migra + re-invite**: upload one-shot del dueño + marcador `movedToBackend` en CloudKit (deploy Production + .ckdb mismo PR) + rebind de miembros por `legacy_member_key` al re-entrar. Sin doble verdad; residuales documentados (§9 del diseño). |
| 5. Identidad | **Miembro = `sub` de cuenta nube, sign-in obligatorio** (también invitados; alias + sin email + Hide My Email). Concepto `member_key` desacopla el historial (userRecordID viejo para migrados, `sub` para nuevos) — cero remap de filas de gastos. **Privacidad: minimización + pgcrypto** en columnas sensibles (adelanta DIFERIDOS #5); E2E descartado v1. Resuelve #17, A21/A32, GAP 1, M1-3. |
| 6. M1 + wipes | **Grupos por sesión** (store por archivo, patrón M1; tab visible en secundaria) y los **wipes de sign-out borran el store de grupos** (re-descargable). Mueren M1-2/M1-3 y el `YalaGroups` compartido. |
| 7. Timeline / flags | **Un solo encendido**: el gate de flags del Modo Nube INCLUYE Grupos-backend (G0–G8 + cross-member test-gate + device-QA de migración y push). Nadie vive el híbrido. **+ APNs propio DENTRO de v1** (push silencioso, notifs client-side — paridad con CKSyncEngine). |

**Plan de incrementos:** G0 spikes (APNs desde Worker + pgcrypto×Merkle) → G1 schema+RLS+RPCs → G2 canal cliente → G3 identidad → G4 invites+consent → G5 cutover+M1/wipes+gestión de datos → G6 migración grupos vivos → G7 pgcrypto → G8 APNs. Detalle y gates en el diseño §11-12.

**Añadido 2026-07-14 (2ª pasada con el owner):** matriz de personas P1–P11 (diseño §14 — insumo del consent copy y de los guiones QA de G4/G6) + frente de **gestión de datos y sesión** (diseño §15: vaciar/eliminar/exportar/importar/cerrar-sesión re-especificados por escenario; el sign-out gana la fila NUEVA "sesión solo-grupos") + invariante **una-sola-cuenta-por-sesión** (diseño §2 + riesgo R9: el primer sign-in — aunque sea solo-para-grupos — fija LA cuenta; la migración personal posterior reusa la sesión viva, jamás re-ofrece sign-in; Apple-en-grupos + Google-en-personal es imposible por construcción).

**Sub-decisiones owner ✅ CERRADAS (2026-07-14, pre-noche autónoma):** (a) eliminar-cuenta siendo DUEÑO → **transferencia AUTOMÁTICA** del ownership al admin más antiguo (o miembro más antiguo) + notificación — jamás se bloquea; (b) anonimización GDPR **CONFIRMADA** (member → "Usuario eliminado", gastos históricos se conservan; único-miembro → tombstone del grupo). **Alcance nocturno autorizado (owner): G1 + G2 + arrancar G3** — método por incremento (spec → plan → /review-plan → impl → gates → commit), DARK, staging-only vía MCP, jamás prod ni CloudKit schema; gate rojo = parar y documentar.

**Pre-flight COMPLETADO (2026-07-14, 3 exploradores — diseño §16):** ningún bloqueante nuevo; todos los hallazgos absorbidos por G0–G8 sin incrementos extra. Claves: el desacople sesión↔storageMode YA existe físicamente (sesión viva + `.icloud` es inerte por `canRunDomain()`) — el delta solo-grupos es lógico (11 asunciones enumeradas con coordenadas, las de impacto alto en sign-out/Welcome/UI); la plomería APNs base ya está (entitlement + background mode + register — faltan las 3 piezas de token/registro/handler); el AASA ya matchea el token de invite sin cambios; cero escritores de `Split*` fuera del app target (R1 relajado); `/account/delete` confirmado inexistente (G1 lo hereda); el export actual ya trata las TX bridgeadas como personales (coherente, la sección grupos es aditiva); la señal de wipe cross-device por iKV queda solo-`.icloud` (nube = tombstones).

**Siguiente paso:** ~~`/spec` sobre G0/G1~~ → **spec de G0 abajo (2026-07-14, `spec-ready`)**; G1 se especifica al cerrar G0 (sus resultados condicionan G7/G8).

---

# SPEC G0 — Spikes bloqueantes (diseño §11, fila G0)

> Alcance EXACTO: tres spikes empíricos que despejan las únicas incógnitas de plataforma del diseño. **Cero código de producción, cero UI de usuario** — todo DEBUG/staging/desechable. Sus veredictos condicionan G7 (pgcrypto) y G8 (APNs); un rojo NO bloquea G1–G6 (schema/canal/identidad/invites no dependen de ellos), solo fuerza la re-decisión puntual anotada.

## Analisis tecnico

### Archivos involucrados

| Archivo | Cambio | Impacto |
|---------|--------|---------|
| `gateway/src/push/apns.ts` | Crear (spike A — semilla del módulo real de G8: firma JWT ES256 + fetch a APNs) | Alto |
| `gateway/src/index.ts` | Modificar — ruta `POST /debug/push` staging-only (patrón `/v1/attest/dev`: `ENVIRONMENT === "staging"` + `DEV_SHARED_SECRET`) | Bajo |
| `gateway/wrangler.toml` | SIN cambio — secrets nuevos por CLI: `wrangler secret put APNS_AUTH_KEY` (p8) y `APNS_KEY_ID` (`APPLE_TEAM_ID` ya está en vars) | Bajo |
| `Yala/App/YalaAppDelegate.swift` (53 líneas hoy) | Modificar — 3 handlers: `didRegisterForRemoteNotificationsWithDeviceToken` (guarda hex, `#if DEBUG`), `didFailToRegister` (log), `didReceiveRemoteNotification:fetchCompletionHandler` (breadcrumb con timestamp + `.newData`) | Medio |
| `Yala/App/Views/Settings/CloudSyncDebugView.swift` | Modificar — sección "Spike APNs": device token copiable + botón "Enviar push de prueba" contra `/debug/push` | Bajo |
| Migración Supabase staging `g0_pgcrypto_spike` (vía MCP, patrón `i*`) | Crear — `CREATE EXTENSION pgcrypto` + tabla desechable `spike_enc` con RLS estándar + 3 RPCs (write/read/hash) | Medio |
| `qa/cloud/pgcrypto-spike-test.sh` | Crear (patrón `cross-user-rls-test.sh`: 2 JWTs de `i5-user-a/b` contra PostgREST staging) | Medio |
| `$VAULT/Backlog/modo-nube/MODO-NUBE-G0-GUION-DEVICE.md` | Crear — guion del spike C (matriz de entrega del silent push, corrida owner) | Bajo |

### Modelo de datos
Ninguno. Nada de SwiftData; la tabla `spike_enc` es staging-only y se retira con una migración de limpieza (`g0_pgcrypto_spike_cleanup`) al cerrar el spike — jamás toca el DDL contrato (`supabase-staging.ddl`) ni el manifest.

### Dependencias
- **`jose`** — ya es dependencia del gateway (firma el JWT ES256 de APNs sin lib nueva).
- **⚠️ Acción OWNER previa al spike A:** crear una **APNs Auth Key (.p8)** en Apple Developer portal (Certificates → Keys → Apple Push Notifications service), anotar el Key ID, y cargarla: `npx wrangler secret put APNS_AUTH_KEY` / `APNS_KEY_ID`. Una sola key sirve sandbox y producción.
- **Device físico con build Yala Dev** (spikes A/C — el push real no llega al sim). El entitlement Debug es `aps-environment = development` → host `api.sandbox.push.apple.com`.
- La plomería base YA existe (pre-flight §16c del diseño): entitlement, background mode `remote-notification`, y `registerForRemoteNotifications()` al boot — el spike solo añade los handlers que faltan.

## Plan de implementacion

### Incrementos (orden de ejecucion)

1. **Spike A — APNs desde Cloudflare Workers (device real)** — LA incógnita: `api.push.apple.com` exige HTTP/2 y hay que verificar empíricamente que el `fetch` del runtime de Workers lo negocia (hay precedentes públicos, pero es exactamente lo que un spike confirma).
   - Archivos: `gateway/src/push/apns.ts` (firma ES256 con cache de token ~50 min — APNs exige tokens <1h y >20 min entre re-firmas; headers `apns-topic`=bundle id, `apns-push-type: background`, `apns-priority: 5`; payload `{"aps":{"content-available":1}}`), ruta `/debug/push`, handlers en `YalaAppDelegate.swift`, sección en `CloudSyncDebugView.swift`.
   - Tests/criterios: (1) el Worker recibe **200 + header `apns-id`** de APNs sandbox; (2) el device con la app en background recibe el push (breadcrumb con timestamp); (3) latencia end-to-end anotada. **Si el fetch no negocia HTTP/2** → veredicto rojo documentado + evaluación de alternativas ANTES de G8 (proveedor de push intermedio, o servicio con HTTP/2 garantizado) — esa decisión es el entregable.

2. **Spike B — pgcrypto con llave por request + hash sobre plaintext (staging)** — valida el patrón de cifrado del diseño §3/§8 SIN tocar el Worker: la llave viaja como argumento del RPC (PostgREST ejecuta funciones en transacción propia — probar TAMBIÉN la variante `SET LOCAL app.enc_key` vía wrapper y elegir).
   - Archivos: migración `g0_pgcrypto_spike` (tabla `spike_enc(user_id, sync_id, amount_enc bytea, note_enc bytea, …)` + RLS `auth.uid()=user_id` + RPCs `spike_enc_write(p_key,…)` / `spike_enc_read(p_key)` / `spike_enc_hash(p_key)` con `pgp_sym_encrypt/decrypt`), script `qa/cloud/pgcrypto-spike-test.sh`.
   - Tests/criterios: (a) round-trip byte-idéntico; (b) llave equivocada → **ERROR limpio de pgcrypto**, jamás basura silenciosa; (c) **el hash canónico es determinista entre lecturas Y estable tras re-cifrar la misma fila** (el ciphertext cambia por el salt, el hash sobre plaintext NO — es el punto que decide que el Merkle de G7 es viable); (d) auditar si la llave-como-argumento queda en los logs de Postgres (statement logging) — si fuga, la variante `SET LOCAL` gana; (e) RLS sigue arbitrando (user B con la llave correcta NO lee filas de A). Cleanup: migración `g0_pgcrypto_spike_cleanup` al cerrar.

3. **Spike C — matriz de entrega del silent push (device, corrida owner)** — depende del A; mide el throttling REAL de `content-available` para calibrar la expectativa de notifs de G8.
   - Archivos: `MODO-NUBE-G0-GUION-DEVICE.md` (guion) — usa la plomería del spike A tal cual.
   - Tests/criterios: matriz de entrega con N=5 por celda (foreground / background reciente / suspendida horas / **killed por swipe — iOS NO entrega content-available, documentar como límite** / Low Power Mode), latencias por breadcrumb, comparación cualitativa contra el push de CloudKit actual (paridad esperada — mismo mecanismo). Entregable: tabla rellenada + decisión anotada en el diseño §7 (¿la entrega en background basta para las notifs de grupo de v1, o se adelanta la evaluación de push visible?).

Los incrementos 1 y 2 son PARALELIZABLES (no comparten archivos); el 3 exige el 1 verde y device del owner.

### Riesgos
- **HTTP/2 a APNs desde Workers falla** → es el resultado que el spike existe para descubrir; el fallback se decide con evidencia antes de G8, no se improvisa dentro de G8.
- **Llave visible en logs de Postgres** (spike B, criterio d) → la variante `SET LOCAL` es el plan B ya incluido en el mismo spike; si AMBAS fugan → re-decisión R2 del diseño (pgcrypto solo en `note`/`display_name`) con el owner.
- **Doble registro de push** — `registerForRemoteNotifications()` ya se llama hoy para CKSyncEngine; añadir los handlers NO interfiere (CloudKit enruta por `CKDatabaseSubscription`, el handler nuevo solo ve los push del gateway). Riesgo bajo, verificado en pre-flight §16c.
- **Deriva del spike a producción** — todo gateado: ruta staging-only + `DEV_SHARED_SECRET`, cliente `#if DEBUG`, tabla desechable con cleanup. Nada de G0 se enciende en prod.

### Estimacion
- Incrementos: 3 (2 paralelizables + 1 corrida device del owner)
- Complejidad: **media** (código acotado; el valor está en los veredictos, no en las líneas)
- Gate de cierre de G0: veredictos de A y B escritos en el diseño (§7 y §3/§8/R2) → G1 arranca con las incógnitas despejadas.

## Implementación

### 2026-07-14 — `ef4a23f9` (G0 pasos 1–5 IMPLEMENTADOS, todo DARK)

**Resumen:** plomería completa de ambos spikes lista para sus corridas; quedan los pasos 6–9 (owner: .p8 + migración + corridas + veredictos).

**Archivos (14, +796):**
- `gateway/src/push/apns.ts` — firma JWT ES256 (jose, claims solo iss+iat, `normalizePem`), cache module-scope TTL 50 min con invalidación por keyId, `sendPush` que separa status-vs-`transportError` (= el veredicto HTTP/2); semilla del módulo real de G8.
- `gateway/src/push/routes.ts` + `index.ts` — `POST /v1/debug/push`: 404 prod / 401 sin dev-secret / **503 sin secrets APNs (estado deployable PRE-.p8)** / 400 token no-hex64; respuesta 200 = diagnóstico completo.
- `gateway/src/env.ts` + `wrangler.toml` + `README.md` — `APNS_KEY_ID` (var, placeholder) + `APNS_AUTH_KEY` (secret, comando stdin documentado).
- `gateway/test/apns.sign.test.ts` — 9/9 OFFLINE (firma/claims, PEM con `\n` literales, cache+rotación con fake timers, guards vía `app.request` de Hono, transportError sin reject).
- `Yala/App/YalaAppDelegate.swift` — los 3 handlers que faltaban; `didReceiveRemoteNotification` clasifica **CK-primero → `.noData` sin tocar nada** (CKSyncEngine recibe por canal interno, doc Apple verificada) / key `yala` → `.newData`.
- `Yala/App/Logic/PushBreadcrumb.swift` — molde SaveBreadcrumb, category `Push`, fuera de `#if DEBUG`; tokens `PUSH TOKEN_OK/TOKEN_FAIL/RECEIVED`.
- `Yala/App/Views/Settings/CloudSyncDebugView.swift` — card `pushCard` (token copiable + push de prueba; degradación sin `YALA_DEV_SHARED_SECRET`).
- `qa/cloud/g0_pgcrypto_spike.sql` + `_cleanup.sql` — tabla `spike_enc` desechable + 5 RPCs (el **`rekey` sin tocar `content_hash`** es LA prueba de que el Merkle de G7 sobre plaintext es viable); errores sanitizados `yala_bad_key`/`yala_not_found`.
- `qa/cloud/pgcrypto-spike-test.sh` — 11 asserts + auditoría MANUAL de logs impresa (llaves sentinela; `log_parameter_max_length_on_error` = punto caliente).
- `qa/coverage-index.json` — área nueva `groups-backend-g0-spikes`.

**Decisiones técnicas:** sendPush jamás rechaza (el diagnóstico ES el entregable) · sin ampliar `YalaErrorType` (observar, no abstraer) · KEY_ID como var visible, solo la .p8 secret · URLRequest inline en el panel con comentario anti-precedente · key `debug.apnsDeviceToken` fuera de la auditoría del wipe (diagnóstica, `#if DEBUG`).

**Gates:** gateway suite offline verde (2 fallos de `account.goldens` PREEXISTENTES de estado: cuenta B claimeada por el QA parkeado del 14/07) · deploy staging + guard 401 verificado en vivo · builds Yala/Yala Dev limpios · validate-coverage OK.

**Guion device:** [[MODO-NUBE-G0-GUION-DEVICE]] (fase A = prueba live HTTP/2; fase C = matriz del silent push).

**Pendiente (pasos 6–9):** owner crea la APNs Auth Key → `npx wrangler secret put APNS_AUTH_KEY < AuthKey_<KEYID>.p8` + Key ID en `wrangler.toml` + redeploy → fase A del guion · ~~aplicar `g0_pgcrypto_spike.sql` en staging → correr el script + auditoría de logs~~ ✅ · ~~veredicto Spike B~~ ✅ · cleanup de la migración al cerrar G0 (tras el spike A).

### 2026-07-14 (2ª tanda) — SPIKE B EJECUTADO Y VERDE ✅

Migración `g0_pgcrypto_spike` aplicada vía MCP de Supabase (org staging verificada ANTES — prod ni aparece en la lista del conector). **Gotcha cazado en la primera aplicación:** pgcrypto vive en el schema `extensions` de Supabase → `search_path = public` pelado esconde `digest`/`pgp_sym_*` → fix `search_path = public, extensions` en las 6 funciones (SQL del repo actualizado, pendiente de commit). `bash qa/cloud/pgcrypto-spike-test.sh` → **12/12 PASS**. Auditoría de logs AUTOMATIZADA vía MCP (settings + pg_stat_statements + logs Postgres): **cero fuga de la llave** — veredicto completo en [[MODO-NUBE-GRUPOS-BACKEND-V1-DISENO]] §16e, con la condición nueva para G7 (assertar los 3 settings de logging en su gate) y la decisión **llave-como-argumento** (la variante GUC no aporta). **R2 del diseño RESUELTO.** G0 queda a la espera SOLO del spike A live (.p8 del owner).

### 2026-07-15 — SESIÓN NOCTURNA REMOTA (otra Mac): G1 ✅ + G2 ✅ + G3-arranque ✅ (3 commits pusheados)

> La sesión corrió con la spec INLINE del prompt nocturno (los docs del vault no sincronizan a esa Mac vía iCloud — resuelto después con copias trackeadas en `docs/modo-nube/` del repo). Los deltas de diseño que produjo están RECONCILIADOS en [[MODO-NUBE-GRUPOS-BACKEND-V1-DISENO]] §4/§5/§9 (notas fechadas 2026-07-15).

- **G1 (`ac579536`)** — los 9 RPCs SECURITY DEFINER (incl. `update_member_display_name`, nacido del review) + contrato `supabase-groups-staging.ddl` + **`cross-member-rls-test.sh` 71/71 PASS** en staging. Review adversarial de seguridad aplicó 3 SERIOS que ahora son diseño: **S1** rebind legacy → `pendingApproval` jamás active (member_key enumerable = bypass de aprobación); **S2** pending NO lee contenido financiero (SELECT de las 3 tablas de datos = writer); **S3** `group_members` FREEZE total a escritura directa → pull-only en el canal, rename solo vía RPC. `field_hlcs` POR UNIDAD en las escrituras de RPC. **INCIDENTE cazado y curado:** una sesión paralela de "limpiar residuos de spikes" (contexto stale "grupos van por CloudKit") DROPEÓ la infra g1_01 a las 20:24 — la nocturna la RESTAURÓ verbatim desde `supabase_migrations.schema_migrations` (`g1_01b_reapply_groups_infra_after_drop`). Verificado 2026-07-15: infra viva; `spike_enc` NO fue dropeada (su cleanup sigue pendiente del cierre de G0).
- **G2 (`b86dbf1c`)** — canal COMPLETO y DARK: `apply_group_delta` (SECURITY INVOKER, RLS arbitra; GET DIAGNOSTICS tras cada update — bajo RLS de grupos un UPDATE puede afectar 0 filas aunque el SELECT viera la fila); gateway `/groups/push|pull|merkle` (pull con memberships-primero + keyset por grupo); `group_capability_manifest.json` (flags `pull_only`/`update_only` nuevos); `GroupsSyncClient` Swift con drain PROPIO y muro `groupEntityNames` DISJUNTO del personal (review R1: partición SÓLIDA, cero fugas; un save mixto del bridge lo ven ambos drains y cada uno extrae solo su subconjunto); modelos `GroupSyncOutbox`/`GroupSyncCursor` en sync-meta; hook del bridge remoto byte-idéntico al gate 5/5; arranque por SESIÓN VIVA (persona solo-grupos). Del review: emisión de `split_groups.created_at` violaba el column-grant (rechazo del delta entero de meta) → eliminada + test de paridad emisión↔grants nuevo. Gates: goldens `groups.goldens.test.ts` 9/9 network-ON (convergencia byte-idéntica en órdenes inversos) · gateway 147 passed · suite 4271/390 en 0 fallos · builds ambas schemes.
- **G3-arranque (`2aed07d9`)** — `SplitMember.userID: String?` LOCAL-only (jamás viaja en CKRecord — cero deploy CloudKit); `GroupBackendIdentityLogic` con namespace PROPIO `SHA256("SplitMemberBackend:{groupID}:{member_key}")` (deliberadamente distinto del CloudKit — decisión del implementador documentada, corrige una imprecisión del brief); `isCurrentUser` por auth uid DETRÁS del flag con fallback record-name (flag OFF = comportamiento byte-idéntico). Suite 4281/391 en 0 fallos.
- **Restante de G3 (próxima sesión):** emisión/push de member-related ops del cliente (create_group vía RPC desde el cliente), backfill de `userID` en members CloudKit preexistentes, separación conceptual member_key↔cloudKitUserRecordID, encendido del flag. **Pendiente registrado para owner (G3/G5):** claim de migración personal sobre profile creado por grupos (`claim_account` devolvería `existing_stable` con corpus vacío + `migrated_at` NULL) — NO tocado (goldens 130 protegen `claim_account`); decidir el delta con el owner.

### 2026-07-14 (3ª tanda) — SPIKE A: VEREDICTO HTTP/2 POSITIVO ✅ (transporte despejado SIN esperar el device)

APNs Auth Key `7H6BUZWKKS` creada por el owner → secret subido vía stdin (jamás leído; el `.p8` en la raíz del repo ya estaba cubierto por el gitignore) → Key ID en `wrangler.toml` → redeploy staging → **prueba live con token DUMMY: `status:400` + `apnsId` + `BadDeviceToken` desde APNs sandbox** = el fetch de Workers negoció el transporte HTTP/2-only, el JWT ES256 fue ACEPTADO por Apple, y el topic es válido — APNs rechazó solo lo único falso (el token dummy). Veredicto completo en [[MODO-NUBE-GRUPOS-BACKEND-V1-DISENO]] §16f. **G8 desbloqueado — sin pivote.** Restante del guion device (confirmación e2e, ya no veredicto): entrega real a token verdadero + regresión CK + matriz fase C.

## Estado parkeado del QA (para retomar después)

Ver notas ⏸ en [[MODO-NUBE-M1-GUION-DEVICE]] y [[MODO-NUBE-SIGNOUT-WELCOME-GUION-DEVICE]]. Device QA: dueño A_QA `.icloud` (5 cuentas/2257 registros), cuenta B en staging (`0e5e8585`), FAKE secundaria pendiente de destrabar (M1-4). Pendientes ajenos a grupos que se retoman tal cual: guion sign-out formal (fix `c174a663` re-verificación device), repro routing TestFlight, fix `expensesOnlyMode` (en curso).

### 2026-07-15 — SESIÓN NOCTURNA (2ª noche): G3 COMPLETO ✅ (`e22a991d`) — G4 en curso

> Reconciliación del PASO 0.5: verificada punto por punto contra el diseño — el owner ya había foldeado
> los ⚠️ (S1/S2/S3, unidades, smoney, namespace, sentinel); cero migraciones de reconciliación. El LOG
> nocturno del vault (`groups-backend-v1-LOG-NOCHE-2026-07-14.md`) se BORRÓ (ya fusionado aquí).

- **HALLAZGO QUE CORRIGE EL DISEÑO §2** (verificado en código): las FKs del historial
  (`paidByMemberID`/`SplitShare.memberID`/`from-toMemberID`) apuntan a **`SplitMember.id.uuidString`**,
  NO a `cloudKitUserRecordID` (MemberPickerView:26, GroupBalanceService:63, CKRecordTranslator las pasa
  crudas). Como `id` es determinista por (groupID, member_key) dentro de cada mundo, la convergencia
  cross-device se sostiene — pero las columnas wire `*_member_key` transportan id.uuidString (naming
  engañoso; contrato G2 congelado, no se renombra). **Riesgo NUEVO para G6:** el historial migrado lleva
  ids del namespace CloudKit ("SplitMember") y un device fresco born-backend derivaría el namespace
  backend ("SplitMemberBackend") → los balances de un grupo migrado en device fresco NO matchearían.
  G6 debe decidir: derivación namespace-aware en el apply o remap en el uploader. ⚠️ Sincronizar esta
  corrección al diseño §2 del vault.
- **G3 (`e22a991d`)** — migración `g3_01_create_group_full_meta` (create_group +3 params default —
  cierra divergencia Merkle de simplify/show/members_can_invite; DDL contrato actualizado con el drop);
  gateway `/groups/rpc/:fn` (allowlist de 9 fns + params por fn, JWT verbatim, errores yala_* preservados
  como `yala_rpc_error` con code, 6 goldens nuevos → 15/15); Swift `GroupsMembershipClient` (9 métodos
  tipados, errores tipados con `.permanentRejected` para códigos desconocidos) +
  `GroupBackendMembershipService` (createGroup SERVER-FIRST: RPC → solo a éxito materializa grupo+owner
  con id determinista backend, memberKey=userID=sub, cloudKitUserRecordID="" — separación; resto de ops
  passthrough, el pull materializa); `SplitMember.memberKey` LOCAL-only + applyMember/fetchSplitMember
  dual-match con adopción legacy; guard A1 en los 2 backfills de refreshCurrentUserFlags (sin él, flag ON
  = fuga cross-canal a CKSyncEngine). Residual create→drain CERRADO por diseño server-first (la purga del
  noop group_not_found se queda como anti-storm legacy; G4 le pone breadcrumb). Método: review-plan Opus
  (3 SERIOS) → 2 impl paralelos → 2 reviews adversariales (seguridad SÓLIDO; correctness cazó el test
  tautológico de echo-suppression → fix discriminante por autor de History). Gates: suite 4306
  (4294 pass/0 fail/12 skip) · builds 0 warnings · gateway 153+2 preexistentes · validate-coverage OK.
- **Residuales documentados:** coexistencia flag-ON (SplitSyncManager podría encolar el SplitGroup del
  servicio backend — partición por-grupo en G5); 502→transient del cliente RPC (retry-loop latente de
  call-sites malformados futuros); backfill de userID en members CloudKit preexistentes DIFERIDO;
  **claim de migración sobre profile creado por grupos SIGUE PENDIENTE DEL OWNER** (no tocado).
- **Gotchas entorno:** ProUpsellServiceOneShot ×2 reaparecieron (StoreKit sandbox persistido en el sim) →
  `simctl erase 9D0F6D32` los curó; XCUITests (GroupsSmoke/IncomeExpense/ProfileSettings) fallan por el
  gotcha ambiental 2026-07-13 → gates locales con `-only-testing:YalaTests`. El MCP de Supabase tardó en
  conectar al arranque de la sesión — verificar `list_projects` antes de cada migración sigue vigente.

### 2026-07-15 — G4 ✅ (`2a2cf471`) — el canal queda funcionalmente completo DARK

- **G4 (ciclo de vida del canal)** — pull hasta agotar (terminación página-vacía + guard cursor-no-avanzó
  mirror del personal; cap 20 con breadcrumb; early-return idle anti-churn de History); dead-letter de
  `upstream_400` con código SANITIZADO slug yala_* (el adversarial cazó que `outcome.message` no está
  garantizado como slug — una data-exception 22P02 del RPC ecoaría el valor del cliente hasta
  TelemetryDeck) + **re-drive**: al aprobar al member propio (pendingApproval→active en el apply del
  pull) reviven las filas `upstream_400:yala_not_authorized` de ese grupo — la premisa "P0001 =
  permanente" era falsa para el pending que escribe contenido; purga del noop `group_not_found` se
  mantiene (anti-storm legacy) ya con breadcrumb; `GroupsSyncBreadcrumb` completo (token guard,
  dead-letter, deadLetteredCount al arrancar, apply-skips); loop de cadencia single-instance
  reutilizando `SyncCadencePolicy` (401 re-arrancable / 403 stopUntilRelaunch; sleeper inyectable;
  stopLoop sin wiring = cierre pre-flag); telemetría canario `groupPushRejected` (diseño §12, primera
  de las 5). Golden 7 TS de paginación (16/16) fija el contrato de terminación.
- **HALLAZGO DE PERF (chip de tarea creado):** `/groups/pull` es O(grupos×5 tablas) SECUENCIAL —
  ~42s/pull medidos con los 76 grupos del user de test. Paralelizar/batchear el fan-out del gateway
  ANTES de encender flags (wire congelado por los goldens).
- Gates: suite 4319 (4307 pass/0 fail/12 skip) · builds 0 warnings · gateway 154+2 preexistentes ·
  goldens grupos 16/16 · validate-coverage OK.
- **Estado del plan §11 tras esta noche:** G0 ✅ (veredictos) · G1 ✅ · G2 ✅ · G3 ✅ · canal-lifecycle ✅
  (esta G4 nocturna = los residuales del canal, NO el "G4 invites+consent" del plan — ese sigue
  pendiente junto con G5 cutover/M1, G6 migración de grupos vivos, G7 pgcrypto, G8 APNs).
- **Pendientes owner acumulados:** claim de migración sobre profile creado por grupos (delta con el
  owner); ~~chip de perf del pull~~ (cerrado `68f5555d`, ver entrada siguiente); reconciliar al vault
  la corrección del diseño §2 (FKs = id.uuidString) + el riesgo G6 de namespaces; cleanup del Spike B
  al cierre formal de G0.

### 2026-07-15 — perf del pull CERRADO (`68f5555d`) — el hallazgo de G4 resuelto pre-flags

- **Fix:** el fan-out O(grupos×5) de `handleGroupsPull` deja de ser secuencial — las 5 queries de cada
  grupo en `Promise.all` + pool de grupos con `PULL_GROUP_CONCURRENCY=6` (≤30 fetches en vuelo; Workers
  capa ~6 conexiones por invocación y encola el resto). Queries a PostgREST **byte-idénticas** (mismo
  shape y count de subrequests — 381 con 76 grupos, bajo el cap 1000 del plan paid) y respuesta
  indistinguible: filas por entidad en orden `GROUP_ENTITIES` antes del sort ESTABLE por `server_seq`,
  deltas en orden `memberGroupIds`, primer error upstream gana con el mismo 502.
- **Descartado el batch `group_id=in.(...)`** (documentado en el comentario del handler): el cursor
  `server_seq.gt` es POR GRUPO (cadenas `or=(and(...))` de URL sin cota) y el `limit` de PostgREST es
  GLOBAL por query → una truncación dejaría grupos de la cola sin filas de una tabla mientras el merge
  avanza el cursor con filas de otras tablas de `server_seq` mayor = **deltas perdidos silenciosos**.
- **Medido:** ~42s → ~2.5s por pull con los 76 grupos de i5-user-a; golden 7 entero (6 pulls) 15.3s vs
  ~250s. **Residual:** el count de subrequests sigue O(grupos×5) — con ~200 grupos el cap de 1000 de
  Workers sería el límite (batch con rediseño de cursor + detección de truncación; no aplica a v1).
- Gates: typecheck limpio · goldens grupos 16/16 · gateway 154 passed + los 2 preexistentes de
  account.goldens.

### 2026-07-15 (mañana, owner en sesión) — DECISIÓN + CIERRE del pendiente "claim sobre profile creado por grupos" ✅

**Decisión owner (AskUserQuestion): Opción A — promoción a `created`, implementada de inmediato** (autorización
explícita para tocar claim_account). Migración `g3_02_claim_promotes_groups_lite_profile` APLICADA en staging
(SQL versionado en `qa/cloud/`): columna `profiles.personal_claimed_at` + backfill one-shot (todo lo
preexistente = reclamado; verificado: las 4 filas reales eran cuentas personales legítimas) + rama de
PROMOCIÓN en claim_account — fila con `personal_claimed_at` NULL (el claim ligero de create_group/join_group)
y sin mip → estampa provider/leader/lease exactamente como el INSERT y devuelve **`created`** (TOCTOU-safe:
UPDATE con WHERE pca IS NULL; el perdedor de una carrera re-clasifica). **Cero cambios de wire ni de cliente**
— la máquina §g y FullModeActivation funcionan tal cual (`created` ya significa "siembra/migra").
- Review adversarial PRE-aplicación (Opus): **APLICAR** — trazó los goldens de claim uno a uno (sin regresión:
  la rama nueva no la ejercita ninguno), verificó paridad INVOKER/search_path/grants (or-replace con firma
  idéntica los preserva), TOCTOU serializado por EvalPlanQual, y confirmó que `AccountClaimDecision.decide`
  nunca trata `created` como anomalía (migración → proceedMigration; bornCloud → seedBornCloud).
- Verificación WIRE real one-shot: fila de A reseteada a ligera vía MCP → claim → `created` + pca/provider/
  leader estampados → re-claim → `existing_stable` → snapshot restaurado.
- Golden NUEVO autosuficiente en account.goldens.test.ts (simula la fila ligera con patchProfile own-row;
  robusto en corridas repetidas): 27 passed + los 2 preexistentes de exists (sin relación).
- **NOTA para el deploy a PROD** (del review): el backfill es correcto hoy porque grupos-backend está DARK —
  antes de promover esta migración a producción, verificar que no existan filas ligeras reales (no las habrá
  mientras el flag siga OFF).
- **NOTA G5**: el adopt del Welcome debe aceptar `created` como resultado válido cuando la cuenta era
  solo-grupos (semánticamente correcto: lo personal nace ahí); y `/account/exists` puede enriquecerse con
  `{personal_claimed, has_groups}` (aditivo) para el copy del solo-grupos que reinstala.

### 2026-07-15/16 — SESIÓN NOCTURNA (3ª noche): G4-INVITES/CONSENT ✅ + ENDURECIMIENTO PRE-FLAGS ✅ + CAS reverse_claim VERIFICADO YA-CERRADO — ⚠️ reconciliar al vault

> 4 commits (`09a66cbd` A1 · `d1395866` A2 · `b101f2c8` B1 · `53fe10d7` B2). Método íntegro: exploradores → briefs con
> contrato congelado → /review-plan Opus por brief (17 ajustes entre ambos, 4 CRÍTICOS/ALTOS reales) → impl Opus →
> reviews adversariales Opus (doble lente donde B2 tocó el canal personal) → fixes pre-commit → gates → commit+push.
> Con esto, **el "G4 invites+consent" del plan §11 (la fila real, no el lifecycle de la 2ª noche) queda COMPLETO** y
> el canal tiene TODAS sus redes pre-flags. TODO DARK tras `groupsBackendEnabled`.

- **A1 — invite por TOKEN (`09a66cbd`):** link `g=&t=` + `s` SIEMPRE presente como base64URL self-referential —
  hallazgo del explorador que corrigió el chip: el AASA (`?s=*`) exige la PRESENCIA de `s`, un link solo-g/t NO abre
  la app; el formato elegido no toca AASA/invite.astro y preserva g/t por el camino custom-scheme. Handler
  `GroupBackendInviteEntryHandler` (intent persistente ANTES de todo await; cold-launch persiste y retorna; el bug
  de Pia muere por construcción — join RPC síncrono), reconciler re-targeteado (`ensureCurrentUserMemberExists`
  PROHIBIDO para entries backend; `isBackendJoin` prioridad sobre el flag — rollback del flag jamás mis-enruta;
  FIX S1 del adversarial: la detección del member backend por `userID==sub`/`memberKey==sub`, NUNCA `isCurrentUser`
  que applyMember no setea — sin él el intent jamás se limpiaba y el canario `groupJoinIntentExpired` daba falso
  positivo), `GroupBackendAcceptErrorLogic` (12 casos → 5 kinds), canarios `groupJoinFailed`/`groupLegacyRebindFailed`,
  golden TS 3-bis (fija que `is_group_writer` transiciona con `status='active'`). displayName SIEMPRE no-vacío
  (btrim='' = `yala_bad_input` permanente) + corrección posterior vía `update_member_display_name`.
- **A2 — consent §8 + sign-in solo-grupos §16d (`d1395866`):** `GroupsConsentView` (BRAND-VOICE, "protegidos" sin
  prometer cifrado pre-G7; registro por `PrefSyncKey` nuevas ×2 — el review-plan verificó que el server de prefs es
  KV puro sin allowlist, cero cambios server-side; gate 36→38 del count test) + `GroupsSignInView` (SIWA que
  autentica y NADA MÁS — verificado que `signInWithApple()` no toca migración/adopt/StorageMode; R9: sesión viva
  jamás re-ofrece) + seam de presentación cerrado (`GroupsBackendInviteModifier`, continuación en `onDismiss`,
  blockers en la matriz de readiness, NO welcome-chain-tearable — las 4 reglas de presentaciones auditadas limpias)
  + onboarding del invitado fresco (GroupInviteOnboardingView reusada con metadata nil; intent nuevo
  `.presentGroupBackendInviteOnboarding`) + 10 keys l10n ×16 (voseo es-AR a mano).
- **B1 — Merkle client-side (`b101f2c8`), LA red anti-divergencia:** el /review-plan cazó DOS críticos que habrían
  invalidado el diseño: (1) reusar la proyección de EMISIÓN habría divergido en CADA grupo para siempre (la emisión
  omite `split_groups.created_at` por el column-grant y `group_members` entero es pull-only — el server hashea TODAS
  las columnas del manifest) → `GroupMerkleProjection` SEPARADA; (2) `merkle_fixtures.json` del personal es un golden
  del ENSAMBLADO, no de la PROYECCIÓN — la paridad de proyección no tenía red unit en NINGÚN canal (así se cazó la
  divergencia FX de I11, en device) → fixtures de PROYECCIÓN generadas ejecutando el código REAL del gateway
  (esbuild bundle de `canonRowC1Group` y cía.) + test Swift byte a byte. Guards en orden + política remoto-VACÍO
  (root vacío remoto = firma de remoción vía RLS, jamás falso canario) + canario `groupMerkleDivergence(groupCount)`
  + remediación por-grupo una-vez-por-sesión + cadencia `shouldRunMerkle` reusada. Golden TS 8.
- **B2 — resto del endurecimiento (`53fe10d7`):** `GroupsOutboxMirror` (durabilidad A1, Q3 byte-molde, dead-letters
  excluidas, re-drive re-espeja, rehydrate diff owner-scoped) · push chunking 50 con applyResults POR CHUNK ·
  `teardownForSignOut` en los 3 paths de CloudSessionSignOut (stopLoop deja de tener 0 call-sites) · **guardia de
  generación** (hallazgo MEDIA del lente-personal: un ciclo en vuelo resumía post-teardown y REPOBLABA el espejo
  recién purgado — montos sobreviviendo la purga M1) · piggyback paso 5.6 en `CloudSyncRuntime.performCycle` con las
  2 correcciones del review-plan (guard de SECUNDARIA — sin él el piggyback reintroducía grupos en la sesión de la
  invitada; abstención del loop propio por `canRunDomain()` — con `.cloud` a secas, grupos moría durante toda la
  migración transicional) · backoff RPC con exclusión TOTAL de retry para los one-shots creadores (hallazgo MEDIUM-1
  del lente-grupos: un 502 post-COMMIT reintentado en `create_group_invite` = token huérfano VÁLIDO; verificado
  contra el DDL que `join_group` reintentado NO doble-consume uso). Flag OFF: `performCycle` byte-idéntico
  (verificado línea a línea por el lente-personal; CloudSyncRuntimeTests 19/19 intactos).
- **CAS del `reverse_claim` + enforcement del freeze — AMBOS YA ESTABAN CERRADOS pre-sesión (verificado, no asumido):**
  la migración `i11_reverse_claim_cas` está aplicada en staging desde el 2026-07-11 (md5 de la función viva
  `1768ad02de1cb25bf3fbfe458d22771e` matchea el contrato de qa/cloud/README:427) con el golden 22 concurrente
  (dos `reverse_claim` por `Promise.all` → exactamente uno `ok:true`) verde en el baseline de hoy; el freeze
  enforcement vive en `handleSyncPush`/`handlePrefsPush` (check en la sombra del primer apply, fail-closed 502,
  409 `yala_account_reverting`) con los goldens 19-21 verdes — **los 2 pendientes del gate de flags personal se
  marcan CERRADOS con esta evidencia** (el chip nocturno tenía contexto stale de I11-3). Leak acotado del `delta[0]`
  = diseño aceptado documentado.
- **Residuales que quedan para el gate de flags / G5+:** semántica `status='left'` server-side vs vivo-local del
  Merkle (validar antes de encender) · fixture sin regeneración CI ni montos negativos · poison-en-chunk sin
  partitionBuildable (follow-up) · dead-letter revivible sin red de espejo en pendingApproval · transiciones de
  modo loop↔piggyback → relaunch media · branded params n/i/c no mostrados en el onboarding backend ·
  regionFallbackCurrency saltado en silent-setup backend (cosmético) · **no emitir links backend hasta que la base
  instalada tenga el parser (nota G5)** · el flag NO debe encenderse sin A2 ya mergeado (cerrado — A2 está en el
  mismo tren).
- Gates de cada commit: suite YalaTests completa 0 fallos · builds ambas schemes 0 warnings nuevos · gateway
  157 passed/2 skip (eran 155 al abrir — +3 goldens nuevos: 3-bis y 8; los 2 skip son los stateful condicionales) ·
  validate-coverage OK. Baseline del Paso 0: preventivo ProUpsell 4/4 (sin erase), gateway re-deployado a staging
  (`59971c70`) para paridad repo↔Worker.
- **Estado del plan §11 tras esta noche: G0 ✅ · G1 ✅ · G2 ✅ · G3 ✅ · canal-lifecycle ✅ · G4-invites/consent ✅ ·
  endurecimiento pre-flags ✅ — quedan G5 (cutover+M1/wipes+gestión de datos), G6 (migración grupos vivos + R10),
  G7 (pgcrypto), G8 (APNs).**

### 2026-07-15/16 — SESIÓN NOCTURNA (4ª noche): G5 COMPLETO ✅ (cutover + sign-out ×4 + M1/wipes + gestión de datos) — ⚠️ reconciliar al vault

> 6 commits (`e3af04ab` D1a-server · `a7de7cec` G5-A · `3e23acf1` G5-B · `7b5ff216` G5-C · `97e5c280` D1b/c ·
> `b63bbb90` D2). Método íntegro de las noches anteriores: 4 exploradores paralelos → 4 briefs con contrato
> congelado → /review-plan Opus por brief (los 4 dieron NECESITA AJUSTES — 12 críticos/altos reales foldeados
> ANTES de implementar, incl. la partición simétrica del drain que el brief de A omitía y la fuente del
> ModelContext de B) → implementadores Opus secuenciales (D1a-server en paralelo con A: gateway-only, cero
> solape) → reviews adversariales por incremento (DOBLE lente en A/B/C/D1 — canal personal, sign-out/wipes,
> multi-usuario) → fixes pre-commit → gates completos → commit+push verificado. **La fila G5 del plan §11
> queda COMPLETA.** TODO DARK tras `groupsBackendEnabled`.

- **G5-A (`a7de7cec`) — cutover interno de escritura:** `SplitGroup.isBackendGroup` LOCAL-only + partición
  POR-GRUPO **BIDIRECCIONAL**: guards hacia CKSyncEngine (enqueue*/createZone/createShare/zoneRecovery/
  `recoverUnsyncedRecordsIfNeeded` — un grupo backend siempre tiene `ckSystemFieldsData==nil`, el recovery
  del boot lo habría re-encolado) **+ el hallazgo CRÍTICO del /review-plan: el drain del canal backend no
  filtraba por-grupo** — con flag ON, editar un grupo CLOUDKIT habría drenado filas a un `group_id`
  inexistente (dead-letters permanentes + doble-sync) → `backendGroupZoneIDs` una vez por drain + skip en
  las 3 ramas. Routing: crear grupo (gate consent/sign-in ANTES de abrir el form — anchors distintos, el
  intent con el form abierto quedaría retenido peek-first), invitar (por `isBackendGroup`; CloudKit sigue
  CKShare hasta G6), membership SERVER-FIRST por `memberKey` (JAMÁS `member.id`). Guards defensivos en
  reject/changeRole (sin RPC de rol — evitar falso éxito). **NOTA G6 (del lente CloudKit): la adopción de
  un grupo CloudKit en pull backend DEBE setear `isBackendGroup=true` ATÓMICO o drain+Merkle lo pierden en
  silencio para siempre.**
- **G5-B (`3e23acf1`) — matriz de sign-out ×4:** fila NUEVA `.groupsOnlySignOut` (sesión viva + no-.cloud +
  flag ON) con push-all verificado de grupos (con el FIX SEV-2 del lente-grupos: `drainOnce` ANTES del
  pre-check — outbox vacío ≠ History drenada; sin él una mutación de segundos antes se perdía PARA SIEMPRE)
  + **gate de QUIESCENCIA a la entrada (HIGH del lente-personal: el path corre en `.icloud` con el mirror
  VIVO — la purga salvaba al mainContext compartido sin gate = la clase exacta del crash-loop de restore)**
  + teardown→purga de outbox/cursores (leak cross-cuenta)→consent clear (con la API NUEVA
  `PreferenceSyncService.remove(forKey:)` 3 ramas — sin limpiar iKV el consent RESUCITABA al boot)→signOut→
  wipe del store de grupos ARMADO al boot (4º hook, kill-safe, marker ÚLTIMO). `.cloud` AMPLIADO: push-all
  de grupos + re-verify S2 doble + marker `includesGroups` (marker-PRIMERO/arm-ÚLTIMO + clear incondicional
  del huérfano). Copy honesto + fila de cuenta. R9 RECORTADO (migrar-con-sesión re-pide SIWA — gap
  documentado, incremento propio). Seam `PushTokenSignOutSeam` (G8) en los 4 paths. **Flaky de ENTORNO
  cazado y arreglado de raíz:** víctima itinerante (pull_403/backfill colgaban sin terminar) por la tormenta
  IO de los containers on-disk `IdRemap-*` (cleanup en defer con Tasks huérfanos de save — ruido presente ya
  en el baseline verde) → cleanup no-op documentado; corrida post-fix sin UNA línea de tormenta.
- **G5-C (`7b5ff216`) — grupos por sesión (M1/D8):** `YalaGroups-Secondary` vía `GroupsStoreDecision`
  (espeja syncMeta — lectura directa de `isActive()`, jamás el testigo); wipe secundario con grupos (3ª
  condición del abort-S3); outbox/cursores per-sesión GRATIS vía `YalaSyncMeta-Secondary` (verificado + test
  de aislamiento por archivo); guards de arranque/cinturón B2/piggyback 5.6/tab/temporaryTab relajados bajo
  flag (5.6 ELIMINA la cláusula, no OR — el flag ya estaba ANDeado); gates 3/5 y 4/5 retirados DETRÁS del
  flag (tipos vivos). **HIGH del lente-ON: las superficies de JOIN-INTENT (`PendingJoinStore`/tracker/
  consent, `UserDefaults.standard` sin scoping) cruzaban la frontera secundaria — el intent de la invitada
  se habría presentado/ejecutado bajo el DUEÑO (redimir SU token con la cuenta equivocada)** → purga de
  frontera exhaustiva en ambas direcciones. ⚠️ CONDICIÓN DE ENCENDIDO documentada (H2): flag ON pre-G6 con
  grupos CloudKit vivos pierde el belt de account-switch (el encendido único D9 post-G6 lo hace seguro).
- **G5-D1a (`e3af04ab`) — /account/delete server-side (método g3_02):** RPC `delete_personal_account()`
  HARD DELETE de las 20 tablas per-user + `profiles` (WHERE `auth.uid()` en cada delete), APLICADO en
  staging tras review adversarial PRE-aplicación (veredicto APLICAR; SEV-3 pre-apply: enumeración VIVA de
  columnas `user_id` = 22, las 2 extra son del canal de grupos ya cubiertas por `groups_forget_user`).
  Ruta `POST /account/delete` con `requireUserAndAttest` (asimetría DELIBERADA con el resto de /account —
  la op más destructiva del canal). md5 registrado (`f1ab01670a85d3d72860b5aeae6cfe2b`). **Verificación
  WIRE one-shot VERDE sobre sub B** (seed→delete con counts reales tx:53/prefs:41/profiles:1→post-delete
  vacío→re-claim `created`) + suite gateway re-corrida (164/2). Golden network-ON EXCLUIDO por diseño
  (destructivo sobre users compartidos; sub A prohibido — sync.goldens pushea como A en paralelo; NO existe
  re-seed de counters documentado). Gateway re-deployado a staging (paridad).
- **G5-D1b/c (`97e5c280`) — eliminar-cuenta cliente:** `AccountDeletionService` con ORDEN ANTI-ZOMBIE
  (forget→teardowns [paran loops SIN matar la auth — un push en vuelo re-crearía corpus en el backend
  recién vaciado]→delete→seam SIWA→cierre local por modo reusando la red terminal por FASE VIVA); residual
  push-sobre-sentinel VERIFICADO IMPOSIBLE (`group_members` pull-only en ambos canales). Fila destructiva
  con doble confirmación. Sentinel `__deleted_user__`→`resolvedDisplayName` en los 12 sitios + builders de
  diccionario **+ FIX H1 del lente-GDPR: `GroupBalanceService` filtraba el sentinel crudo a la pestaña
  Balances (superficie fuera de la lista, cazada por el review)**. D1c: copy de vaciar verificado ×16 +
  test model-level `wipeAllUserData` preserva los 5 `Split*` (harness nuevo).
- **G5-D2 (`b63bbb90`) — export ampliado:** toggle "Incluir mis grupos" → CSV separado (10 columnas:
  gastos con MI parte, settlements, MI balance por moneda vía el MISMO `calculateBalances` de la pestaña —
  patrón `isCurrentUser`, jamás userID); SIN gate por flag (grupos CloudKit existen hoy, read-only);
  export personal BYTE-IDÉNTICO (invariante testeada); FIX F1 (cero-silencios: fallo del CSV de grupos
  AVISA en el alert de éxito); headers localizados (no se re-importa — documentado).
- **RESIDUAL 'status=left' VALIDADO CERRADO (lo pedía el gate):** el server deja la fila `deleted=false`
  con `status='left'`; los demás members la APLICAN como campo (fila viva → proyección Merkle converge);
  el que SALE pierde membership → el grupo desaparece de su pull → limpieza local + Merkle skip por
  política remoto-vacío. `removeMember` local también conserva la fila (`.removed`). Sin divergencia.
- **Pendientes que G5 DEJA para el gate de flags / G6+:** copy 401-vs-transient del delete (H2, retry
  engañoso con sesión muerta) · SIWA token revocation (Apple 5.1.1(v) — necesita el .p8 de SIWA en el
  Worker, decisión owner) · `auth.users` sobrevive al delete (PII de identidad — Admin API, decisión
  owner) · espejo D1 de attest sobrevive · **ratificación owner del HARD DELETE personal (decisión de
  SESIÓN, no estaba en §15)** · re-aplicar `g5_01` a PROD con los gates SEV-1/SEV-2 · adopción G6 setea
  `isBackendGroup` atómico · guard R9 de migrar-con-sesión (startAdoptWithExistingSession en
  StorageSettings) · branded params n/i/c del onboarding backend y regionFallbackCurrency (cosméticos,
  sin cambios) · transiciones loop↔piggyback → relaunch media (sin tocar — G5-B no cambió los modos).
- Gates de cada commit: suite YalaTests completa 0 fallos (creció 4402→4470 / 400→409 suites) · builds
  ambas schemes 0 warnings nuevos · gateway 164 passed/2 skip (+7) · validate-coverage OK (áreas nuevas
  `groups-backend-g5-cutover` + `account-deletion`; bumps session-sign-out/secondary-session/export-wizard).
- **Estado del plan §11 tras esta noche: G0 ✅ · G1 ✅ · G2 ✅ · G3 ✅ · canal-lifecycle ✅ ·
  G4-invites/consent ✅ · endurecimiento pre-flags ✅ · G5 ✅ — quedan G6 (migración grupos vivos + R10),
  G7 (pgcrypto), G8 (APNs).**

### 2026-07-16 (sesión gate §12, 7ª) — BLOQUES A+B DEL GATE COMPLETOS: PROD PROMOVIDA (13 migraciones, paridad 33/33) + Worker prod DESPLEGADO + SIWA revoke 5.1.1(v) REAL + auth.users muere con la cuenta — ⚠️ reconciliar al vault

> Chip `CHIP-GATE-12-ENCENDIDO.md` CONSUMIDO (retirado con este commit). Commits `8ed3f47f`+`c2725354`
> (Bloques B) + el de cierre. Decisiones owner del día (AskUserQuestion ×4): HARD DELETE RATIFICADO ·
> APNs prod REUSA `7H6BUZWKKS` · dirección B2 RATIFICADA (extender el RPC, no credencial de máquina) ·
> MCP re-conmutado a `yala-production` para la fase 2. Método íntegro: exploradores → briefs congelados →
> /review-plan → implementadores → reviews adversariales (4 en total, TODOS cazaron algo real) → gates.

- **BLOQUE B1 — SIWA revoke 5.1.1(v)** (`8ed3f47f`+`c2725354`): la app NO poseía token revocable (el
  delegate descartaba `authorizationCode`; expira ~5min) ⇒ canje EN el sign-in vía Worker
  (`/account/siwa/exchange`, requireUser — load-bearing: el sign-in precede al /attest/bind) + custodia
  del refresh token de Apple en Keychain del CLIENTE como PAR (token, appleUserID) + revoke al borrar
  (`/account/siwa/revoke`, requireUserAndAttest) con MATCH obligatorio del par (2 hazards cross-cuenta
  M1 cazados por los reviews: exchange-fallido-de-secundaria [par del dueño] y kill-entre-writes de una
  sobrescritura [(tokenDUEÑO, userSECUNDARIA)] → match + clear-antes-de-write). client_secret ES256
  molde apns.ts, SIN redirect_uri (flujo nativo). Best-effort ≤4s TODO dentro de la carrera. Residual
  población-CERO argumentado (flags DARK ⇒ nadie con sesión SIWA pre-capture). Worker staging
  redesplegado; `SIWA_AUTH_KEY` en AMBOS envs. 10 tests wire clase d49d2e47 + test de tabla del
  invariante del par + 8 units gateway offline.
- **BLOQUE B2 — `auth.users` muere con la cuenta** (`g12_01_delete_account_auth_users`, aplicada en
  staging Y prod): `delete_personal_account()` borra TAMBIÉN `auth.users where id = auth.uid()` AL
  FINAL — cierra el gap GDPR (email/nombre SIWA sobrevivían). Vía RATIFICADA tras PoC en vivo: Admin
  API descartada (service_role todo-o-nada en el Worker), rol de máquina descartado (borraría cualquier
  uuid); el RPC ata el borrado al caller POR CONSTRUCCIÓN. ⚠️ SUPUESTO LOAD-BEARING (review adversarial):
  `auth.users` tiene RLS sin policies — funciona por `rolbypassrls=true` de postgres (assert registrado,
  verificado en ambos envs). Hallazgos: `profiles` SÍ tiene FK CASCADE a auth.users (el explorador creía
  que no); el re-claim del JWT en vuelo ya NO renace la cuenta (violaría la FK — cierre de la
  resurrección que g5 permitía); JWT stateless post-delete verificado e2e (el revoke 4a sigue
  funcionando). WIRE one-shot VERDE con sub C DESECHABLE (A/B intactos; gotcha: GoTrue rechaza signups
  @test.yala → C se siembra por SQL molde A/B; el runbook viejo de re-claim quedó SUPERSEDED — violaría
  la FK). md5 nuevo `6bafd85a…`. Residual-owner: auth.audit_log_entries/flow_state sobreviven (= Admin API).
- **BLOQUE A — PROMOCIÓN A PROD (`kefvaiymtgytemwbltlz`) — DRIFT CERRADO:** fase 1 (extractor, org
  staging): SQL de las 17 migraciones candidatas extraído BYTE-EXACTO del historial
  (md5==md5(statements) 17/17); la terna del incidente (g1_01/enable_rls/drop_spike) se NETEA a g1_01b
  (probado por construcción); locales idénticos al historial (g5_01/g6_01 solo-comentarios). Fase 2
  (org prod): pre-flight baseline = solo los 3 bootstraps + §16e ya correcto (ddl/-1/0) +
  rolbypassrls ✓ → **13 migraciones aplicadas en orden** (g1_01b→g8_02 + g12_01) con **sandwich G7**
  (recrypt ×2 con la llave PROPIA de prod — `~/Secrets/yala-groups-enc/prod.key`, DISTINTA de staging;
  corpus vacío → 0s) → verificación: **paridad md5 33/33 funciones staging↔prod** · rol yala_push +
  proacl `{postgres,service_role,yala_push}` · estructural 29/96/22/55 cuadre EXACTO · golden invertido
  anon→42501 · advisors solo by-design (+1 WARN higiene stamp_group_seq → chip aparte). **Worker
  `yala-gateway-production` DESPLEGADO POR PRIMERA VEZ** (la app prod ya apuntaba a él): 7 secrets
  (OpenAI+ExchangeRate de Secrets.xcconfig [⚠️ pendiente-owner ROTAR la de OpenAI — extraíble en el
  archive del build 18], JWT_SIGNING_SECRET PROPIO de prod, GROUPS_ENC_KEY, PUSH_ROLE_JWT [acuñado y
  verificado 200 contra PostgREST prod], APNS_AUTH_KEY 7H6BUZWKKS, SIWA_AUTH_KEY) + `APNS_KEY_ID` var +
  smoke 401 en toda la superficie. `DEV_SHARED_SECRET` NO existe en prod.
- **Gotcha de método NUEVO:** el MCP de Supabase de esta sesión llegó tarde y conmutado a UNA org —
  la fase 1 se hizo con la org free (staging) y la 2 con `yala-production`; el runbook de 2 fases
  (briefs/RUNBOOK-BLOQUE-A-PROMOCION-PROD.md, gitignored) queda como molde para futuras promociones.
- **Gates:** gateway npm test **196/2 skipped** (15 files — nuevo baseline, +8 units siwa) · suite
  YalaTests **4563/422** TEST SUCCEEDED (nuevo baseline, +30/+4 de B1) · builds ambas schemes ·
  validate-coverage OK · budgets del gotcha re-tombstoneados ×2 (24+1, vía apply_delta sin service).
- **DEL GATE §12 QUEDA SOLO EL BLOQUE C (owner):** device-QA G6 ([[MODO-NUBE-G6-GUION-DEVICE]] con
  apéndice G7) + device-QA G8 ([[MODO-NUBE-G8-GUION-DEVICE]] incl. multi-device G8-3) + canarios en
  cero durante dogfooding → ENCENDIDO (cloudModeEnabled + groupsBackendEnabled, sesión propia D9).
  Pendientes-owner nuevos de hoy: ~~ROTAR OPENAI_API_KEY~~ (CERRADO mismo día: la subida a prod YA
  era la rotada, confirmación owner) · APP_STORE_API_KEY de prod si el webhook lo usa · residual
  GDPR de auth.audit_log_entries.

### 2026-07-16 (sesión nocturna, 6ª) — G7 pgcrypto ✅ + G8 APNs ✅ — EL PLAN §11 (G0–G8) QUEDA COMPLETO EN CÓDIGO — ⚠️ reconciliar al vault

> 3 commits (`cdd2b849` G7 · `fa7cb4cd` G8-2 cliente · `802e6a3e` G8-1 server). Método íntegro ×6ª sesión:
> 3 exploradores Opus → 3 briefs congelados (en `docs/modo-nube/briefs/`, gitignored) → 3 /review-plan Opus
> (G7 NECESITA AJUSTES con 5 CRÍTICOS [el estrella C1: el Merkle vía RPC lector habría recibido amounts como
> número JS → rama double del canon → divergencia LATENTE que ningún gate cazaba]; G8-server 2 CRÍTICOS
> [c.executionCtx lanza sin ctx → ~10 goldens a 500; modelo de amenaza de tokens FALSO en el brief];
> G8-client 2 CRÍTICOS [seam sin gate por flag = divergencia flag-OFF; unregister sin timeout = sign-out
> colgado offline]) → implementadores Opus (G7 gateway ∥ G8-2 Swift; G8-1 secuencial tras G7 por routes.ts)
> → reviews adversariales (G7-SQL PRE-aplicación con verificación EMPÍRICA read-only contra staging:
> APLICAR 0 críticos/serios; G8-2: COMMIT 0 críticos/serios) → aplicación ordenada → gates → commits.

- **G7 (`cdd2b849`):** 8 columnas † a bytea con pgp_sym_* (las del diseño + `split_settlements.note` [† genérico]
  + `split_shares.amount` [sin ella un dump reconstruye expenses.amount sumando shares] — ambas a RATIFICAR
  owner). Llave-como-argumento (§16e; residente-en-DB descartada: aparece en dumps). Migración SIN fuga: 2 DDL
  sin llave + recrypt intermedio vía execute_sql (336 names/592 display_names/239+59+3 amounts/186+45 notes;
  roundtrip 239/239 PRE-cutover; belt m12 en 0). Readers `groups_pull_rows_*` SECURITY INVOKER (RLS antes de
  descifrar) con amounts como TEXT escala-4 (resolución C1 — el canon toma la rama string decimal-exacta; el
  wire pasa de número a string, ÚNICO cambio de shape, WireValueDecoder compatible, cliente Swift INTOCADO,
  fixtures B1 intactas); `yala_try_decrypt` tolerante-POR-FILA (anti-DoS de bytea basura → NULL + Merkle
  divergence lo delata); cirugía de apply_group_delta († fuera de jsonb_populate_record, tri-estado NULL);
  column-UPDATE grants REGENERADOS (C5: atan por attnum — sin regenerar, push en noop SILENCIOSO); gate §16e
  AUTOMATIZADO (golden g7-logging-settings asserta ddl/-1/0 vía `yala_logging_settings()`). Worker:
  GROUPS_ENC_KEY secret (staging; llave en `~/Secrets/yala-groups-enc/staging.key` + `gateway/.dev.vars`;
  PROD necesita llave PROPIA), pull/merkle a callRpc POST (fan-out 68f5555d conservado 1:1; merkle keyset
  server_seq — entityHash ordena por syncId, verificado), guard 503 sin llave. Goldens con
  `readGroupRowDecrypted` + p_key de process.env (fail-fast; JAMÁS hardcodeada); cross-member adaptado
  (writes † vía apply_group_delta; asserts RLS re-apuntados a columnas no-†). md5s ×14 en qa/cloud/README.
  Endurecimiento gratis: el write directo PostgREST de † muere de facto.
- **G8-1 (`802e6a3e`):** RPCs `get_group_push_tokens` (co-members ACTIVOS, caller excluido, pendingApproval
  fuera) + `prune_push_token` (par exacto, guard de radio grupo-activo-compartido). ⚠️ Modelo de amenaza REAL
  documentado (RATIFICAR owner): un co-member puede ENUMERAR tokens de co-members vía PostgREST (estructural
  con jamás-service_role; token APNs inerte sin la Auth Key; griefing del prune auto-sana por re-registro al
  boot). Gateway: POST /push/register|unregister (upsert merge-duplicates, user_id DEL JWT) + FAN-OUT en
  handleGroupsPush (waitUntil sin bloquear; group_ids de applied por zip de índice; dedup cross-grupo; cap 50;
  sendPush content-available:1 priority 5, sandbox por platform del token; BadDeviceToken → prune; canario
  `[canary] groupApnsSendFailed`, token prefijo ≤8). Prod = no-op hasta APNS keys del owner. Goldens fan-out
  semi-WIRE (interceptor selectivo de fetch a Apple, PEM ES256 de test) 2/2 verdes tras aplicar. Residual
  multi-device del autor documentado (su 2º device espera cadencia).
- **G8-2 (`fa7cb4cd`):** PushTokenRegistrationClient + PushTokenRegistrar (inyectables molde ProUpsell;
  capture siempre-local, upload gateado flag&&sesión, canario groupPushTokenRegisterFailed solo en rechazo
  servidor; platform ios-sandbox/#if DEBUG vs ios-prod) + seam `PushTokenSignOutSeam.clearForSignOut()`
  RELLENO (async, DOBLE gate flag&&sesión [crítico byte-identidad: los paths .cloud son alcanzables con flag
  OFF y sesión viva], timeout 4s anti-cuelgue-offline, 6 call-sites con JWT vivo) + recepción push key `yala`
  → `GroupsSyncClient.syncNowFromPush(timeout: 20s)` (context STRONG retenido molde SplitSyncManager, asignado
  también en el path piggyback; completionHandler exactamente-una-vez; idempotente con la doble fuente
  CloudKit §16d — clasificación CK-primero intacta). Residual: launch puramente-background puede no ejecutar
  el .task del bootstrap → pull al próximo foreground (consistencia eventual v1). 16 tests/4 suites.
- **Gates finales:** gateway npm test **183/2 skipped** (14 files) · cross-member **71/0** (G7, con bloque
  legacy re-sembrado vía MCP) y 62/0 --skip-legacy (G8-1) · suite YalaTests **4531/418** TEST SUCCEEDED ×3
  corridas · builds ambas schemes ×3 (solo el warning preexistente) · validate-coverage OK (área nueva
  `groups-backend-g8-push`).
- **PENDIENTES OWNER (acumulados, para el gate §12):** ratificar columnas † extra (G7) + ~~modelo de amenaza
  de tokens (G8)~~ **RECHAZADO por el owner el mismo día → resuelto por G8-3 (abajo)** · llave GROUPS_ENC_KEY
  PROPIA de prod (+ re-aplicar g7/g8 a prod con sus gates — anotado drift pendiente) · APNS_KEY_ID/AUTH_KEY
  en el bloque production de wrangler.toml · device-QA G6 (guion [[MODO-NUBE-G6-GUION-DEVICE]] — ⚠️ CON
  APÉNDICE G7: los checks SQL de la Fase A ven bytea, usar `yala_try_decrypt`) · device-QA G8 (notif real
  2 devices, guion [[MODO-NUBE-G8-GUION-DEVICE]]) · los previos (SIWA revoke, auth.users Admin API,
  ratificar HARD DELETE, g5_01/g6_01 a prod).
- **Estado del plan §11: G0–G8 ✅ COMPLETOS EN CÓDIGO.** Lo único restante para el encendido es el gate §12
  (device-QAs + pendientes owner + canarios en cero).

### 2026-07-16 (misma sesión, owner en línea) — G8-3 ✅: credencial de máquina `yala_push` — la enumeración de tokens MUERE (decisión owner) — ⚠️ reconciliar al vault

> Commit `01f2d4cb` + migración `g8_02_push_machine_role` aplicada. El owner RECHAZÓ el modelo de amenaza
> aceptado en G8-1 ("co-members pueden enumerar device tokens") y fijó el riel "no diferir nada". Se
> implementó la arquitectura robusta: **rol Postgres `yala_push` de scope mínimo** (nologin, sin BYPASSRLS,
> EXECUTE sobre exactamente 2 funciones) + **JWT de máquina** (HS256 con el legacy secret del proyecto,
> verificado válido; acuñado con `gateway/scripts/mint-push-role-jwt.mjs`, secret `PUSH_ROLE_JWT` del Worker)
> + **REVOKE de los 2 RPCs a authenticated** (el golden se INVIERTE: authenticated → 403+42501, más fuerte).
> El invariante se REFINA: "el Worker jamás posee credencial que lea DATOS DE USUARIO" (yala_push no puede).
> De regalo: muere el griefing del prune, muere el residual JWT-expiry-en-waitUntil, y se CIERRA el residual
> multi-device del autor (header `X-Yala-Device-Token` en el push → el fan-out excluye solo el device emisor
> → el 2º device del autor SÍ recibe el silent push). El /review-plan cazó 1 BLOQUEANTE (un guard por
> `current_user` dentro de SECURITY DEFINER habría roto la función para TODOS — grants-only es el control)
> y el review pre-aplicación verificó EN VIVO los puntos sin precedente (primera migración del repo que crea
> un rol; PG17 ADMIN OPTION automático; SET ROLE vía authenticator). ACL final verificado:
> `{postgres, service_role, yala_push}`. Durabilidad documentada: si algún día se revoca el legacy secret,
> el fan-out muere en silencio (canario = 401 recurrente en el log del fan-out → re-acuñar). Gates: gateway
> **188/2 skipped** · suite **4533/418** · builds ×2 · validate-coverage OK. Pendiente-owner NUEVO al
> promover a prod: acuñar el PUSH_ROLE_JWT de prod con su propio legacy secret (mismo script).

### 2026-07-16 — G6 COMPLETO EN CÓDIGO ✅ (migración de grupos vivos D7) — schema CloudKit DESPLEGADO; queda el gate device-QA del owner — ⚠️ reconciliar al vault

> 4 commits (`658643f0` G6-1 · `0f6d5f42` G6-2 · `c1ad72d4` docs decisiones · `dac0042d` G6-3). Método íntegro:
> 3 exploradores → 3 briefs congelados → 3 /review-plan Opus (G6-server NECESITA AJUSTES [crítico: dup
> member_key → 502 retry-eterno]; G6-identity LISTO con 4 menores; G6-marker NECESITA AJUSTES [4 CRÍTICOS:
> guard simétrico de PULL, quiescencia del uploader, resume sin !isBackendGroup, lectura VIVA del seed]) →
> impl Opus (server en paralelo con identity; marker tras ambos) → review adversarial PRE-aplicación del SQL
> (APLICAR + fix P2 casts) + adversarial de G6-2 (COMMIT limpio) + DOBLE lente de G6-3 (ambos COMMIT; fixes
> LOW aplicados) → gates → commits. La sesión sufrió una caída de la Mac a mitad de G6-3 — el implementador
> se REANUDÓ desde su transcript con el working tree intacto, cero pérdida.

- **Decisiones owner del arranque (AskUserQuestion ×3):** R10 = derivación NAMESPACE-AWARE en applyMember
  (remap descartado — pisaría FKs locales de devices preexistentes, clase IdentityRemap) · el marcador
  PORTA el token de re-invite · deploy CloudKit coordinado (preparar → avisar → owner despliega → commit).
- **G6-1 (`658643f0`):** RPC `migrate_group(p_group_id, p_meta, p_members)` — grupo con meta HISTÓRICA +
  members legacy `user_id NULL` atómico; idempotente-suave (`{already, owner_user_id, server_seq}`);
  validaciones anti-retry-eterno (dup member_key + casts malformados → `yala_bad_input`); riesgo aceptado
  squat insider-only documentado. APLICADO en staging (md5 `e7863927e5cb58398ae1e36b84f268f9`, reproducible
  del archivo versionado). Goldens 3 nuevos ACTIVADOS (21/21): atómico+already+group_exists · **E2E R10
  server-side** (historial con FKs legacy byte-idénticas en el pull de B) · rebind + fila-reclamada
  idempotente. Gotcha del golden: settlements usan la unidad `smoney` (no gmoney).
- **G6-2 (`0f6d5f42`):** `isLegacyMemberKey` (UUID-parse — un sub siempre parsea, un recordName jamás) +
  rama R10 en applyMember (id BYTE-IDÉNTICO al del owner CloudKit-era ⇒ balances correctos en device
  fresco — CIERRA R10) + **adopción ATÓMICA de isBackendGroup** en applyGroupMeta existing≠nil (cierra la
  NOTA de G5-A: congela CloudKit + activa drain en UN commit) + seam legacyMemberKey completo
  (PendingJoinEntry back-compat; attemptJoin lo lee del entry). 65 tests/5 suites.
- **G6-3 (`dac0042d`):** los 2 field keys en GroupMeta (`movedToBackendAt` TIMESTAMP + `backendReInviteToken`
  ENCRYPTED, molde name/isArchived; ambos .ckdb actualizados, parity verde) + **GUARD SIMÉTRICO DE PULL**
  (crítico del review-plan: G6 estrena grupo simultáneamente en zona CloudKit VIVA e isBackendGroup=true —
  sin el guard, un member rezagado pisaría las ediciones backend del owner y el deleteZone del owner
  NUKEARÍA los datos del member re-joineado; skip en modifications/deletions/conflict/zoneDeletion con
  excepción quirúrgica para el conflicto del PROPIO marcador [rebase de system fields + re-encolar — sin
  ella el marcador se dropearía para siempre]) + seam `enqueueMigrationMarker` guard-free + boot-reconciler
  acotado por `markerEnqueuedFlag` + **UPLOADER kill-safe** (gate quiescencia+flag+sesión+consent; candidatos
  `isOwner && movedToBackendAt==nil && ckSystemFieldsData!=nil` — jamás !isBackendGroup [la adopción puede
  flipear antes]; orden migrate_group→invite[1 año, one-shot sin retry]→freeze→seed LECTURA VIVA
  [edición concurrente GANA por LWW]→push drenado[transient aborta SIN marcador]→marcador; resume por
  predicados sin journal) + FREEZE service-level (`GroupFreezeLogic`; mitigación #9: owner post-reinstall
  no-congelado) + tarjeta `.migratedFrozen` + CTA re-join (intent sintético → chain A2) + banner de
  progreso + C5 "borrar copia congelada" owner-only. 11 keys l10n ×16. Residuales aceptados: R2 rebase sin
  tope (converge post-freeze), R4 members sin recordName fuera del payload, R8 dead-letters no bloquean el
  marcador (Merkle degrada honesto), R3 deleteZone fire-and-forget.
- **DEPLOY CloudKit Production HECHO (owner, 2026-07-16):** los 2 field keys importados vía .ckdb en ambos
  containers (`iCloud.com.jurgenschmidt.yala.groups` y `.groups.dev`) ANTES del merge — el .ckdb del repo
  jamás mintió sobre Production (logística rama `g6-3-marker` + commit retenido, la clase isOpeningBalance
  cerrada por construcción).
- **PENDIENTE owner (gate §11 de G6): device-QA cross-device TestFlight** — guion NUEVO
  [[MODO-NUBE-G6-GUION-DEVICE]] (build QA con flag ON local; fases: migración owner + kill-test → marcador/
  freeze en member → re-join/rebind/aprobación → **R10 en device FRESCO (la prueba reina)** → borrar copia
  congelada → canarios). ⚠️ nota H2 del guion: no cambiar Apple ID del OS durante la corrida.
- **Estado del plan §11: G0-G6 ✅ EN CÓDIGO — quedan G7 (pgcrypto, con la condición §16e de assertar los
  settings de logging) y G8 (APNs, spikes ya verdes). El gate de flags §12 exige además el device-QA de
  G6 y G8.**

### 2026-07-15 (mañana) — Reconciliación §2 + R10 escrita en la COPIA DEL REPO del diseño

Las notas fechadas están en `MODO-NUBE-GRUPOS-BACKEND-V1-DISENO.md` (copia repo): corrección de §2
(las FKs del historial = `SplitMember.id.uuidString` derivado de `(groupID, member_key)`, no
`cloudKitUserRecordID` crudo; el desacople sigue en pie con el eslabón del id determinista; las columnas
wire `*_member_key` transportan uuidStrings — contrato congelado), residual §9.3(d) (decisión pendiente
de G6: namespace-aware en el apply vs remap en el uploader) y fila R10 en §13. **RESUELTO mismo día: el atasco era `cloudd` de ESTA Mac (vacuum SQLite perpetuo de una cloudd_db de 8 GB)
— daemon reiniciado + DB apartada → los archivos del vault materializaron y las notas quedaron REPLICADAS
al vault (repo → vault, superset verificado por diff).**
