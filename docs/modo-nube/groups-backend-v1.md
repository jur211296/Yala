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

### 2026-07-15 (mañana) — Reconciliación §2 + R10 escrita en la COPIA DEL REPO del diseño

Las notas fechadas están en `MODO-NUBE-GRUPOS-BACKEND-V1-DISENO.md` (copia repo): corrección de §2
(las FKs del historial = `SplitMember.id.uuidString` derivado de `(groupID, member_key)`, no
`cloudKitUserRecordID` crudo; el desacople sigue en pie con el eslabón del id determinista; las columnas
wire `*_member_key` transportan uuidStrings — contrato congelado), residual §9.3(d) (decisión pendiente
de G6: namespace-aware en el apply vs remap en el uploader) y fila R10 en §13. **⚠️ El diseño sigue SIN
sincronizar al vault de esta Mac vía iCloud (crear el archivo aquí generaría conflicto) → REPLICAR las 3
notas al vault desde la máquina principal** (protocolo del README de docs/modo-nube/).
