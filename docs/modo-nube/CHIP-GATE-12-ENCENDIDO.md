# CHIP — Gate §12: promoción a PROD + pendientes del encendido (post G0–G8)

> Chip autocontenido y trackeado en el repo (lección 36ff14d5: los chips en /tmp o solo-vault no viajan).
> Creado 2026-07-16 al cierre de la 6ª sesión (G7+G8+G8-3). Al consumirse: retirarlo con el commit de cierre.

## ESTADO DE PARTIDA (tras `15d24b23`)

El plan §11 (G0–G8) está **COMPLETO EN CÓDIGO** y aplicado en STAGING (`fostjbbwstyuunmmefuk`), todo DARK
(`groupsBackendEnabled=false`). Entre el código y el encendido queda SOLO el gate §12. Ratificaciones owner
YA RESUELTAS (2026-07-16, en sesión): ✅ columnas † extra de G7 (`split_shares.amount` +
`split_settlements.note`) RATIFICADAS; ✅ modelo de amenaza de tokens G8-1 RECHAZADO → resuelto por G8-3
(credencial de máquina `yala_push`, commit `01f2d4cb`). Riel owner VIGENTE (memoria
`feedback_no_diferir_mejor_version`): **no diferir — siempre la versión robusta.**

LEER OBLIGATORIO: `docs/modo-nube/groups-backend-v1.md` (entradas 2026-07-16, incl. G8-3) +
`qa/cloud/README.md` (métodos g3_02, md5s por migración, sección PROD `kefvaiymtgytemwbltlz` con la paridad
2026-07-11) + `MODO-NUBE-GRUPOS-BACKEND-V1-DISENO.md` §12.

## BLOQUE A — Promoción del stack de grupos a PRODUCCIÓN (sesión Claude, con secrets del owner)

⚠️ Primera vez que el canal de grupos toca prod. El proyecto prod (`kefvaiymtgytemwbltlz`) se creó el
2026-07-11 con paridad del canal PERSONAL — **todo el stack de grupos (g1_01→g8_02) es drift anotado**.

0. **Pre-flight:** MCP `list_projects` (prod ACTIVE) + `list_migrations` de AMBOS proyectos → diff exacto de
   lo pendiente (no asumir la lista: derivarla). Re-verificar proyecto antes de CADA apply. Baselines de
   staging intactos (gateway 188/2, suite ~4533/418).
1. **Secrets de prod ANTES de las migraciones que los usan** (owner, protocolo ~/Secrets — jamás transcript):
   - `GROUPS_ENC_KEY` de PROD: `openssl rand -base64 32 | tr -d '\n' > ~/Secrets/yala-groups-enc/prod.key`
     (llave DISTINTA de staging) + `wrangler secret put GROUPS_ENC_KEY --env production`.
   - Legacy JWT secret de PROD (Dashboard prod → Settings → JWT Keys → Legacy) →
     `~/Secrets/yala-groups-enc/prod-jwt-secret` → acuñar con
     `node gateway/scripts/mint-push-role-jwt.mjs ~/Secrets/yala-groups-enc/prod-jwt-secret | npx wrangler secret put PUSH_ROLE_JWT --env production`.
   - APNs: `wrangler secret put APNS_AUTH_KEY --env production < <p8>` (la Auth Key `7H6BUZWKKS` sirve
     team-wide — decidir si se reusa o se crea una de prod) + `APNS_KEY_ID` como var en el bloque
     `[env.production]` de wrangler.toml (hoy FALTA — el fan-out de prod es no-op hasta esto).
2. **Aplicar las migraciones en ORDEN CRONOLÓGICO de staging** (verbatim de qa/cloud/*.sql + las que solo
   están en el historial de staging — usar `list_migrations` de staging como fuente del orden). ⚠️ G7 exige
   el sandwich: `g7_01` → `select g7_recrypt_corpus('<llave PROD>')` vía execute_sql → re-correr (belt) →
   `g7_02` — aunque el corpus de prod esté VACÍO, el orden se respeta (el recrypt devolverá 0s). Verificar
   md5s contra qa/cloud/README tras cada función (paridad byte-exacta, método 2026-07-11) y el proacl de las
   funciones de push (`{postgres, service_role, yala_push}`).
3. **Deploy** `npm run deploy:production` (verificar antes qué gates tiene el script) + smoke: `/groups/pull`
   sin sesión → 401; con los settings de logging de PROD assertados (los 3 del §16e: ddl / -1 / 0 — si prod
   difiere, corregir config ANTES de mover datos).
4. Actualizar qa/cloud/README (drift CERRADO, md5s prod) + ticket + commit.

## BLOQUE B — Pendientes de implementación heredados (sesión Claude; EXPLORACIÓN primero)

1. **SIWA revoke 5.1.1(v):** al eliminar cuenta, revocar el token SIWA (requisito App Store). Piezas: el .p8
   de SIWA ya existe (`~/Secrets/yala-siwa/`, Key ID PQ53RQ5D3G — memoria `reference_siwa_key_yala`); falta
   subirlo al Worker + endpoint/paso en el flujo de `/account/delete` que llame el revoke de Apple. Explorar
   el flujo actual de AccountDeletionService antes del brief.
2. **auth.users tras delete:** hoy `delete_personal_account` borra el corpus pero el usuario de GoTrue
   SOBREVIVE. Borrarlo exige la Admin API (service key) — TENSIÓN con el invariante del Worker. EXPLORACIÓN
   CENTRAL: opciones (a) pg: `delete from auth.users` vía SECURITY DEFINER machine-only (molde yala_push —
   evaluar si GoTrue lo tolera), (b) Admin API con credencial acotada, (c) job manual del owner. Con el riel
   no-diferir: llevar recomendación robusta al owner, no aceptar (c) por comodidad.
3. **Ratificar HARD DELETE personal** (decisión de sesión G5 pendiente) — preguntar al owner ANTES de B2
   (condiciona el diseño del borrado de auth.users).

## BLOQUE C — Gates del OWNER (device, no bloquean A/B)

- [ ] **Device-QA G6** — guion [[MODO-NUBE-G6-GUION-DEVICE]] (⚠️ con el APÉNDICE G7: los checks SQL ven
      bytea — usar `yala_try_decrypt`). Prueba reina: balances R10 en device fresco.
- [ ] **Device-QA G8** — guion [[MODO-NUBE-G8-GUION-DEVICE]] (incluye el caso multi-device de G8-3: el 2º
      device del autor SÍ recibe push).
- [ ] **Canarios §12 en CERO** durante el dogfooding: groupPushRejected, groupJoinFailed,
      groupMerkleDivergence, groupApnsSendFailed (log Worker), groupPushTokenRegisterFailed,
      groupLegacyRebindFailed, cloudkitGroupRecordSaveRejected (época congelada).
- [ ] Con TODO verde → **ENCENDIDO** (`cloudModeEnabled` + `groupsBackendEnabled`, un solo encendido D9) —
      sesión propia con su checklist.

## RIELES

Los de siempre + específicos: prod se toca SOLO en el Bloque A con el diff de migraciones derivado (jamás
asumido); las llaves de prod son DISTINTAS de staging y siguen el protocolo ~/Secrets; con flag OFF todo
byte-idéntico; gates por commit (suite completa + builds ×2 + gateway npm test con GROUPS_ENC_KEY y
PUSH_ROLE_JWT de STAGING en env + validate-coverage); briefs en `docs/modo-nube/briefs/` (gitignored);
método exploradores → brief → review-plan → implementador → adversarial; commits sin Co-Authored-By; push
verificado. Gate rojo o ambigüedad = parar ese bloque, documentar, seguir con lo no bloqueado.

## AL CERRAR

Log al ticket (⚠️ reconciliar al vault) + STATE.md (verificar persistencia) + memoria
`project_modo_nube_fase4_progreso` + retirar este chip + resumen verde/rojo/pendiente.
