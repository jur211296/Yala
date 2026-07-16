# CHIP — Sesión nocturna autónoma: G7 (pgcrypto) + G8 (APNs) — cierre del plan §11

> Pegar este chip como prompt inicial de la sesión. Repo `/Users/jur/Yala`, branch `2.0.5`.
> Autorización del owner (2026-07-16): avanzar autónomo con el método probado de las 5 sesiones
> anteriores (4 nocturnas + G6 diurna); TODO DARK tras `CloudSyncFlags.groupsBackendEnabled=false`;
> sin preguntas salvo bloqueo real (documentar y seguir con lo no bloqueado).

SESIÓN NOCTURNA AUTÓNOMA — Grupos→backend, cierre del plan §11: **G7 CIFRADO PGCRYPTO + G8 APNs**.

ESTADO DE PARTIDA (tras `2a9ca330`): **G0–G6 COMPLETOS EN CÓDIGO** — canal completo con todas sus redes,
invites por token, cutover interno G5, migración de grupos vivos G6 (RPC `migrate_group` aplicado,
identidad R10 cerrada, marcador CloudKit DESPLEGADO a Production por el owner, uploader kill-safe con
guard simétrico de PULL). Staging `fostjbbwstyuunmmefuk` con la infra viva (8 tablas, ~13 RPCs incl.
`migrate_group` y `delete_personal_account`). RIEL anti-drop de staging VIGENTE (entrada [2026-07-15] de
CLAUDE.md — jamás dropear sin validar contra el DDL contrato). El device-QA de G6 es gate del ENCENDIDO
(§12), NO de esta sesión — no lo esperes.

LEER OBLIGATORIO antes de nada: `docs/modo-nube/MODO-NUBE-GRUPOS-BACKEND-V1-DISENO.md` (§3 columnas †,
§7 push, §8 privacidad, §11 filas G7/G8, §12 gate, §16e VEREDICTO Spike B pgcrypto [llave-como-argumento,
Merkle-sobre-plaintext, condición de assertar settings de logging], §16f VEREDICTO Spike A APNs [HTTP/2
verde, JWT ES256 aceptado por Apple]) + `docs/modo-nube/groups-backend-v1.md` (log completo; la sección
2026-07-16 lista lo que G7/G8 heredan) + la entrada [2026-07-15]+addenda de CLAUDE.md Decisiones
Recientes + `qa/cloud/README.md` (método de migraciones, md5s, guiones WIRE).

PASO 0 — DESBLOQUEO (en orden, TODO antes de implementar):
1. `git pull` — debe estar `2a9ca330` o posterior. `Secrets.xcconfig` en la raíz (gitignored — si falta, copiar a mano).
2. MCP Supabase: `list_projects` DEBE mostrar `fostjbbwstyuunmmefuk` ACTIVE_HEALTHY (tarda minutos en conectar — reintentar con ToolSearch). Producción JAMÁS. Re-verificar antes de CADA apply_migration.
3. Sim QA `9D0F6D32-1F49-46AD-8070-603D42B5220F`: preventivo `-only-testing:YalaTests/ProUpsellServiceOneShotTests` (si fallan los 2 de StoreKit → `simctl erase`, remedio estándar). Gates locales SIEMPRE `-only-testing:YalaTests` (XCUITests fallan por entorno en esta Mac). Scheme "Yala Dev", `-parallel-testing-enabled NO`. ⚠️ El cwd del shell PERSISTE entre comandos — xcodebuild siempre desde `/Users/jur/Yala` (gotcha de la 5ª sesión: un `cd gateway` previo rompió un run).
4. Baselines: `cd gateway && npm test` (esperado **167 passed / 2 skipped**; algo más rojo = PARAR y diagnosticar — los goldens G6 requieren la función `migrate_group` viva, ya aplicada) + suite YalaTests completa (esperado ~4515/414, 0 fallos) + builds ambas schemes (único warning tolerado: `hasLocalDataNow` de ContentView, preexistente documentado).
5. Paridad gateway repo↔staging: `npm run deploy:staging` al inicio (idempotente).
6. l10n: `qa/scripts/add-l10n-key.sh` + voseo es-AR a mano. Copy nuevo → BRAND-VOICE.md del vault.

## ALCANCE G7 — CIFRADO PGCRYPTO (D4, §3/§8; spike B verde §16e)

Columnas † a cifrar (bytea con `pgp_sym_*`): `split_groups.name`, `group_members.display_name`,
`split_expenses.amount` + `expense_description`/`note`, `split_settlements.amount` (+ evaluar
`split_shares.amount` — coherencia con gshare). Decisiones YA tomadas por el spike (§16e, NO re-litigar):
**llave-como-argumento** en los RPCs (la variante GUC no aporta), **Merkle computa sobre PLAINTEXT
canónico** (hash estable tras re-cifrado VERIFICADO — el rekey cambia el ciphertext, el content_hash no),
RLS arbitra ANTES de descifrar, errores `yala_bad_key` sanitizados.

- **G7-1 (server, método g3_02 EXACTO):** migración de columnas + re-cifrado del corpus staging existente
  + TODAS las funciones que leen/escriben las columnas † ganan el param de llave (`apply_group_delta`,
  `create_group`, `join_group`, `migrate_group`, `update_member_display_name`, `groups_forget_user`, el
  Merkle server-side). ⚠️ EXPLORACIÓN CENTRAL DE DISEÑO (el pre-flight NO la resolvió): **el PULL de hoy
  lee las tablas DIRECTO vía PostgREST** (`handleGroupsPull` per-tabla) — con columnas bytea devolvería
  ciphertext. Opciones a evaluar con exploradores ANTES del brief: (a) el pull pasa a RPC descifrador
  por grupo (cuidado con la perf ya optimizada ~2.5s — el fan-out paralelo de `68f5555d`); (b) vista/
  función `security barrier` con la llave; (c) columnas espejo descifradas jamás (descartado — doble
  verdad). La decisión condiciona el wire: si el shape de la respuesta del pull cambia, los goldens 21
  y `GroupMerkleProjection`/fixtures del cliente deben re-generarse con el MISMO método de B1 (ejecutar
  el código real del gateway). El cliente idealmente NO cambia (el descifrado es server-side).
- **G7-2 (Worker):** secret `GROUPS_ENC_KEY` nuevo (generarlo con openssl y subirlo vía
  `npx wrangler secret put` — staging; anotar que PROD necesita llave PROPIA del owner) + inyección del
  param en las llamadas RPC/pull del gateway. La llave JAMÁS en logs/código/tests (los tests usan la de
  staging vía env local — decidir el mecanismo con el molde de DEV_SHARED_SECRET).
- **GATE OBLIGATORIO §16e:** assertar los 3 settings de logging de staging como parte del gate de G7
  (`log_statement=ddl`, `log_min_duration_statement=-1`, `log_parameter_max_length_on_error=0`) — check
  automatizado (golden o script) para que un cambio de config no reabra el vector de fuga en silencio.
- Gates G7: round-trip + Merkle verdes con cifrado ON · cross-member re-verde (`qa/cloud/
  cross-member-rls-test.sh` — ADAPTARLO si los RPCs ganan el param de llave) · goldens 21/21
  re-generados si el wire cambió · suite completa · builds.
- ⚠️ Nota para el guion de G6: si el owner corre el device-QA DESPUÉS de G7, las verificaciones SQL de
  la Fase A ven bytea — apendear al guion la función de descifrado o la instrucción equivalente.

## ALCANCE G8 — APNs (D6, §7; spike A verde §16f)

La plomería base EXISTE del spike (`gateway/src/push/apns.ts` con firma ES256 + cache 50min + sendPush;
`YalaAppDelegate` con los 3 handlers [token capturado solo en DEBUG hoy; receive clasifica CK-primero →
`.noData` / key `yala` → `.newData`]; secret APNS_AUTH_KEY + KEY_ID ya cargados en staging).

- **G8-1 (server):** tabla `push_tokens (user_id, device_token)` (§3 — ya diseñada; método g3_02:
  migración + RLS per-user + registrar en el DDL contrato) + endpoint de registro en el gateway
  (`POST /push/register` con JWT; upsert; y `DELETE`/limpieza) + **FAN-OUT en el Worker**: tras un
  `apply_group_delta`/push de grupos exitoso, silent push (`content-available:1`, priority 5, topic =
  bundle id) a los tokens de los DEMÁS members del grupo (excluir al autor; resolver members → user_ids →
  tokens; batch con el sendPush existente; errores BadDeviceToken → limpiar el token muerto). Cuidado
  perf: el fan-out NO puede bloquear la respuesta del push (waitUntil / no-await).
- **G8-2 (cliente):** subir el device token al gateway (el handler de `didRegisterForRemoteNotifications`
  deja de ser DEBUG-only para el REGISTRO — el envío al gateway gateado por
  `groupsBackendEnabled && hasSession`; re-registro en cada boot es idempotente) + **rellenar
  `PushTokenSignOutSeam.clearForSignOut()`** (el seam no-op de G5-B, invocado ya en los 4 paths de
  sign-out + eliminar-cuenta) con el DELETE al gateway (best-effort, jamás bloquear el sign-out) +
  handler de recepción: push con key `yala` → `GroupsSyncClient.syncNow()`/ciclo coalesced del canal
  (debounced; idempotente con la doble fuente CloudKit durante la convivencia — §16d) → `.newData`.
- Gates G8: test e2e staging del fan-out (WIRE: push de A → sendPush invocado hacia el token de B —
  mockear APNs en goldens offline; el push REAL a device es la fase C del guion del owner) · suite ·
  builds · canario `groupApnsSendFailed` (§12).
- Los device-QA de G8 (notif real con app cerrada, 2 devices) son GATE DEL OWNER — dejar guion
  actualizado (el de G0 fase C sirve de base: `MODO-NUBE-G0-GUION-DEVICE.md`).

ORDEN SUGERIDO: G7 primero (toca el wire/goldens — mejor tenerlo asentado), G8 después (aditivo).
Si la exploración del PULL cifrado de G7-1 revela un rediseño mayor (p.ej. reescribir el pull entero
como RPC con regresión de perf), documentar las opciones con recomendación y DIFERIR esa pieza a
decisión owner, continuando con lo no bloqueado (G7 en push/RPCs + G8 completo).

MÉTODO (igual que las 5 sesiones): exploradores Opus paralelos → briefs con contrato congelado (⚠️ en
`docs/modo-nube/briefs/` del repo o scratchpad — si la Mac se cae, /tmp se vacía; los briefs en repo
sobreviven; NO commitearlos al final, `git clean` o .gitignore) → self /review-plan (revisor Opus por
brief) → implementadores Opus (secuencial si comparten archivos; gateway-only puede ir en paralelo con
Swift — JAMÁS dos implementadores Xcode a la vez [DerivedData]) → review adversarial Opus por incremento
(DOBLE lente si toca canal personal o superficie multi-usuario; el SQL de G7 con review PRE-aplicación
trazando los goldens 1 a 1) → fixes pre-commit → gates → commit atómico + push VERIFICADO. Si un agente
muere a mitad (crash de la Mac), SendMessage a su agentId lo REANUDA desde su transcript con el working
tree intacto (probado en G6-3).

RIELES DUROS: staging-only; JAMÁS producción ni deploy de schema CloudKit (G8 NO toca CloudKit; los
containers de grupos quedaron desplegados en G6); JAMÁS encender flags (encendido = gate §12 con
device-QA G6/G8); muro personalEntityNames INTACTO; canal personal SOLO-LECTURA (nada de G7/G8 lo toca);
con flag OFF TODO byte-idéntico (los reviews lo verifican); la llave de cifrado JAMÁS en logs/commits/
tests-hardcodeada; gates por commit = suite YalaTests completa + builds AMBAS schemes 0 warnings nuevos +
gateway npm test verde total + validate-coverage con coverage-index actualizado; commits estilo repo SIN
Co-Authored-By; push verificado tras cada commit. Gate ROJO o ambigüedad de diseño = parar ese
incremento, documentar, repo limpio y pusheado, seguir con lo no bloqueado. Si aparece OTRA sesión
activa sobre staging o docs/modo-nube/, coordinar por el ticket antes de migrar/editar.

AL CERRAR: apendear log al ticket `docs/modo-nube/groups-backend-v1.md` (nota "reconciliar al vault") +
STATE.md del vault (verificar que la edición PERSISTE — gotcha cloudd) + memoria
`project_modo_nube_fase4_progreso` + actualizar el gate §12 en el diseño con lo que quede + resumen
ejecutivo verde/rojo/pendiente. Con G7+G8 verdes, el plan §11 queda COMPLETO EN CÓDIGO y lo único
restante para el encendido es: device-QA G6 + device-QA G8 + los pendientes-owner acumulados (SIWA
revoke, auth.users, ratificar HARD DELETE, g5_01/g6_01 a prod, llave G7 de prod, canarios §12 en cero).
