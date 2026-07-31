---
created: 2026-07-29
updated: 2026-07-31
tags: [modo-nube, grupos, rollback, runbook]
status: active
---

# ROLLBACK de Grupos — runbook

**Para qué existe.** Hasta ahora, si Grupos se rompía en producción había un botón: apagar
`groupsBackendEnabled` en remoto y el canal volvía a CloudKit en segundos, sin build nuevo. **La Fase 3
borra el transporte CloudKit**, así que ese botón deja de devolver nada: apagarlo dejaría Grupos sin
ningún canal. Desde entonces el único rollback es **revertir el build**, y eso hay que tenerlo escrito
ANTES de necesitarlo — cuando algo se rompa, nadie va a reconstruir esta lista.

Requisito de entrada de la Fase 3 ([[MODO-NUBE-PLAN-SIMPLIFICACION-GRUPOS]] §6).

---

## 0 · Este runbook ya está CALIENTE (desde el 2026-07-30)

El §0 anterior decía que todo esto estaba frío porque `groupsBackendCompiledDefault = false`. **Ese
enunciado murió con el paso 2 de D-R1**: el compilado está en `true`, así que el canal backend existe en
el binario y lo único que lo separa de estar vivo es el percent remoto. El §5 exigía borrar aquel §0 el
día del encendido, y esto es lo que ocupa su sitio.

**Lo que sigue siendo cierto y conviene no confundir:** el flip no encendió el canal por sí solo. El
getter compuesto exige además `CloudRemoteFlags.groupsBackendEnabled`, y
`GROUPS_BACKEND_ROLLOUT_PERCENT` sigue en `0` en producción hasta que el owner lo suba y despliegue
(paso 3). Mientras tanto Grupos sigue funcionando por CloudKit para todo el mundo.

**Lo que SÍ cambió el mismo día que el flip, y es lo que vuelve caliente este documento:** los paths de
**teardown** dejaron de leer el getter compuesto y leen la capacidad COMPILADA
(`CloudSyncFlags.groupsBackendCompiledCapability`) — o sea que **ya no están gateados por el percent**.
Un cierre de sesión o un borrado de cuenta en un device con sesión de nube ejecuta hoy la limpieza del
canal de Grupos aunque el percent esté en 0. Es deliberado: un kill remoto apaga el canal, no borra lo
que ya subió al servidor ni exime de olvidar la copia local. Detalle sitio por sitio en el §D-R1 de
[[MODO-NUBE-DECISION-RELEASE-2.1]].

---

## 1 · Los commits, por fase y en orden de revert

Revertir siempre **de abajo hacia arriba** dentro de cada bloque, y los bloques en el orden en que
aparecen aquí (Fase 3 antes que Fase 2 antes que Fase 1).

### Fase 2 — los 7 re-cableos (rama `2.0.5`)

| Pieza | Commit |
|---|---|
| 2.7 · seam del handover | `3e5f9740` |
| 2.6 · test de identidad (cierre del gap) | `45c27792` |
| 2.6 · identidad del miembro | `08298365` |
| 2.6-pre · el predicado se muda a `GroupBackendIdentityLogic` | `8e666074` |
| 2.5 · `syncNow` → drain del backend | `c3aee764` |
| 2.4 · consultas SwiftData → `GroupService` | `632c951f` |
| 2.3 · freeze en soft-delete | `4a51d9c0` |
| 2.2 · notificaciones de miembro | `ba95f62a` |
| 2.1 · notificaciones de grupo | `bed60a92` |

### Fase 2 bis — los arreglos que salieron de medir la Fase 2 · **NO REVERTIR**

Esta subsección existe porque su ausencia era una trampa: son commits de la épica, están entre los de las
fases, y quien recorriera la tabla de arriba hacia abajo los habría revertido con todo lo demás.

| Pieza | Commit | Por qué NO |
|---|---|---|
| `rollback()` del apply de una página | `b422565e` | cierra el laundering: sin él, un save fallido acaba re-empujando al servidor el grafo remoto a medias |
| gemelo del bridge en el canal backend | `f0a723e1` | el arm es del canal nuevo, pero el mismo commit mudó el retome que drena **los dos** |
| bridge remoto durable (canal CloudKit) | `ad937148` | cierra pérdida PERMANENTE del `TransactionItem` de un gasto de grupo, **con el flag OFF** |
| purga de identidad durable (cambio de Apple ID) | `7c7fb7f6` | sin él, matar la app deja al humano nuevo los grupos del anterior con sus 4 credenciales de re-join |
| la llave del re-join sale de la ficha, no de quién eres hoy | `62eeb8f0` + `40a4e417` | corrige el sexto resolvedor de identidad; alcanzable hoy |

**El criterio, para lo que venga después:** un commit de esta épica se revierte si su efecto SOLO existe con
el canal backend encendido. Si arregla algo que falla **hoy, con `groupsBackendEnabled` OFF**, revertirlo
reabre un bug de producción — va aquí, no en las tablas de fases.

### Paso 1 del encendido (D-R1) — configuración de producción

| Pieza | Commit | ¿Revert de git lo deshace? |
|---|---|---|
| `CloudBackendConfig`: URL + anon key de producción en `#else` | `3c49278c` | **Sí**, limpio — vuelve a `isConfigured == false` y toda la superficie de nube queda inerte |

Revertirlo NO deshace nada del servidor: el schema desplegado, el `revoke` y los percents del gateway
viven fuera de git (§2). Cuando se escribió esta fila tampoco tocaba Grupos, porque
`groupsBackendCompiledDefault` seguía en `false`; **desde el paso 2 sí lo toca**, porque sin backend
configurado no hay sesión de nube y con ella se caen todas las superficies del canal.

### Paso 2 del encendido (D-R1) — el flip COMPILADO del canal de Grupos

| Pieza | Commit | ¿Revert de git lo deshace? |
|---|---|---|
| `groupsBackendCompiledDefault` → `true` + los 8 sitios de teardown que pasan a leer el compilado | `5490544d` | **Sí**, limpio — no toca servidor ni gateway; devuelve el binario al estado del paso 1 |

**Revertir esto es seguro HOY y deja de serlo en cuanto el percent suba**, por el motivo del §2 «lo que no
se recupera de ninguna manera»: un grupo born-backend nunca tuvo zona CloudKit. Mientras
`GROUPS_BACKEND_ROLLOUT_PERCENT` siga en `0` no puede existir ninguno, así que el revert no quita acceso a
nada. Después del paso 3, sí.

Qué entra en este commit, además del flip:
- **`CloudSessionSignOut`** (5 lecturas), **`ProfileView.signOutRowPath`**,
  **`AccountDeletionService.Dependencies.live`** y el gate propio
  **`GroupBackendMembershipService.ensureEligibleForTeardown`** pasan del getter compuesto a
  `CloudSyncFlags.groupsBackendCompiledCapability`. Las ENTRADAS (arranque del loop, crear, unirse,
  invitar, aprobar, expulsar, salir, el batch D10) se quedan COMPUESTAS: eso es lo que el kill corta.
- **Consecuencia operativa que hay que tener presente en un incidente:** con el kill activo, un borrado de
  cuenta ejecuta igualmente `groups_forget_user`. Si el kill se activó porque `/groups/*` está roto, ese
  RPC falla y el borrado queda bloqueado hasta que se levante. Es retraso-de-borrado frente a
  retención-permanente-de-PII, y la dirección está elegida a conciencia (§D-R1).

> **Nota de proceso (§5):** el commit del flip no podía contener su propio hash, así que lo anotó el commit
> de docs inmediatamente posterior. Es la tercera vez que pasa en esta épica (el commit 0 de la Fase 3 y el
> paso 1 se anotaron tarde) y la primera en que la ventana es de un commit y no de días.

#### Correcciones posteriores al paso 3 — DOS bloqueantes, no uno

| Pieza | Commit | ¿Revert de git lo deshace? |
|---|---|---|
| `attestProvider` cableado en las 9 construcciones de producción cuyas rutas exigen App Attest + `AttestSessionProvider` | `c267db5d` | **Sí**, limpio — solo cliente, no toca gateway ni servidor |
| Descarte del keyId huérfano del Keychain + `AttestKeyRecoveryLogic` (recuperación ante fallo LOCAL del assert, no solo ante el `unknownKey` del gateway) | `bca6f775` | **Sí**, limpio — solo cliente. Pero revertirlo deja sin attest a todo device que haya reinstalado la app, y eso NO es un problema del Modo Nube |

**Cerrado y verificado en device el 2026-07-31 (build 8):** el tail de producción muestra
`/v1/attest/register`, `/push/register`, `/groups/pull`, `create_group` y `/rates/live` **todos en Ok y sin
una sola línea `[gw-err]`**. Los `ratelimiter/check` confirman que `enforce` está activo de verdad.

**Ninguno de los dos commits es parte del encendido: son lo que el encendido destapó.** Y el segundo **ya
estaba vivo en producción desde que existe App Attest** — el canal de Grupos solo le dio superficie visible.
Detalle completo en `.claude/rules/gateway-attest.md` §«El SEGUNDO fallo del mismo día».

Del primero: con el percent en 100 y
`ENFORCE = "enforce"`, crear un grupo devolvía 401 `yala_attest_required` — el device registraba App Attest
bien, pero el header `X-Yala-Attest-Session` no viajaba en `/groups/*`. Nueve construcciones de clients se
habían quedado con el default `{ nil }` de su init.

**Revertirlo devuelve el 401 y deja Grupos inoperativo con el percent en 100.** Si hiciera falta echar atrás
por otro motivo, el orden correcto es bajar primero el kill-switch (`GROUPS_BACKEND_ROLLOUT_PERCENT` → `0` +
`npm run deploy:production`) y solo después revertir el cliente: al revés se queda un canal encendido que no
sabe atestar.

**Por qué no lo cazó nadie, y qué implica para el runbook:** staging corre `ENFORCE = "observe"`
(`gateway/wrangler.toml`, `[vars]`) — ahí el token ausente se cuenta pero **no bloquea**, así que todo el
incremento G2 se construyó y se validó contra un gateway que no lo exigía. La regla durable está en
`.claude/rules/gateway-attest.md`; el invariante lo sostiene `YalaTests/CloudSync/AttestWiringTests.swift`
(source-scan, con conteo esperado por cliente). **En un incidente, NO bajes `ENFORCE` a `"observe"` para
diagnosticar**: apagaría App Attest para todo el tráfico del gateway, incluido el proxy de IA cuyas API keys
son la razón de que exista.

### Fase 1 — cierre del servidor y muerte de la migración

| Paso | Commit | ¿Revert de git lo deshace? |
|---|---|---|
| 1.1 · cerrar `migrate_group` en el gateway | `21dcd465` | **NO por sí solo** — ver §2 |
| 1.3–1.5 · borrar la maquinaria de migración en el cliente | `5010db6a` | **Sí**, limpio |
| `migrate_group` inerte de verdad (revoke) | `45c32a41` | **NO** — el commit solo mueve el snapshot `.ddl`; ver §2 |
| scripts de migración de D1 | `03ee208d` | irrelevante (solo `package.json`) |
| guard del umbral de forzado de versión | `69092b24` | irrelevante (solo un test) |

### Fase 3 — en curso (commit 0 hecho)

| Paso | Commit | ¿Revert de git lo deshace? |
|---|---|---|
| commit 0 · lo que NO muere sale de los ficheros condenados | `bc486c92` | **Sí**, limpio — es un movimiento de código, sin cambio de comportamiento |

Los commits 1 y 2 van AQUÍ, arriba de todo, y hay que **anotarlos en esta tabla en el mismo commit que los
crea**. Sin eso este runbook queda desactualizado el día que más falta hace. Ese fallo ya ocurrió una vez:
el commit 0 (`bc486c92`) y el paso 1 del encendido (`3c49278c`) aterrizaron sin anotarse y se añadieron
después, al validar el gemelo del bridge.

> **NO revertir** los commits ajenos intercalados: `66960f7d` (cover de la bandeja), `bd9435b8` (salir
> del último grupo), `5c84df88` (deeplink del smoke), `b1a5033f`, ni ningún `docs(...)`. No son de las
> fases y revertirlos reabre bugs que ya se pagaron.

---

## 2 · Lo que un `git revert` NO recupera

**Esta sección es la razón de ser del documento.** Varios de los efectos vivos en producción **no viven en
git**, así que un revert da una falsa sensación de haber vuelto atrás. Y la simétrica muerde igual: un
valor commiteado en `wrangler.toml` **no está en producción hasta que alguien despliega** — git puede decir
100 mientras el Worker sirve 0.

| Qué | Cómo se activó | Cómo se deshace de verdad |
|---|---|---|
| **`CLOUD_MODE_ROLLOUT_PERCENT` a 100** en producción (2026-07-30) — destapa la fila «Dónde viven tus datos» de Ajustes y las cards de sign-in nube del Welcome; **es el estado que exige la decisión de migración de 2.1**, no un valor de tránsito | el valor en `[env.production.vars]` **y un deploy** del Worker (`npm run deploy:production`) | volver a `"0"` **y re-desplegar**. Revertir solo el `.toml` no apaga nada. ⚠️ **Verificar que el deploy corrió**: si el valor está commiteado pero el Worker no se ha desplegado, git miente sobre el estado de producción |
| **404 de `migrate_group`** en el gateway | un **deploy** del Worker (producción, deployment `09bfa839`) | revertir el código **y volver a desplegar**: `npm run deploy:production` (= `wrangler deploy --env production`; su `predeploy` sincroniza el manifest, así que usar el script de npm y no `wrangler` a pelo) |
| **`REVOKE EXECUTE` de `migrate_group`** en Supabase | **SQL ejecutado a mano** en los DOS entornos | un `GRANT EXECUTE ... TO authenticated` explícito, entorno por entorno. Requiere OK del owner y re-enlazar el conector al entorno correcto |
| **Migración de D1 aplicada** | `npm run migrate:production` | a mano: `gateway/migrations/` solo tiene `0001_init.sql` y `0002_account_entitlements.sql`, **ninguna trae `down`** |

⇒ **revertir la Fase 1 en git NO reabre la migración de grupos.** Si algún día hiciera falta volver a
migrar un grupo vivo a la nube, el revert es el primer paso de tres, no el único.

### Y lo que no se recupera de ninguna manera

- **Los grupos born-backend.** Un grupo creado en el canal nuevo **nunca tuvo zona CloudKit**, así que un
  build sin canal backend no puede verlo por ninguna vía. No es pérdida de datos (siguen en Supabase),
  es **pérdida de acceso** hasta que vuelva a haber un build con el canal. Mientras el percent siga en 0
  no existe ninguno; pasa a ser el riesgo principal del rollback **en cuanto corra el paso 3**.
- **Los change tokens de CKSyncEngine** ya descartados en un device: CloudKit no reenvía lo que cree
  entregado. Lo cura `resetLocalGroupsSyncState()`, no el revert.

### ⚠️ RESIDUAL ABIERTO del paso 2 — el boot-wipe de Grupos no resetea los tokens de CKSyncEngine

**Decisión del owner (2026-07-30): queda documentado, NO se arregla en el commit del flip.** Va aquí, en
el §2, porque es exactamente lo que este apartado existe para recoger: un efecto que ningún `git revert`
deshace y que se activa por primera vez con este paso.

**Qué pasa.** Los dos boot-wipes que borran el store `YalaGroups`
—`SwiftDataConfiguration.performSignOutWipeIfArmed` cuando el marker `signOutWipeIncludesGroups` está
puesto, y `performGroupsOnlySignOutWipeIfArmed`— borran **solo los archivos del store**. Los change tokens
de CKSyncEngine viven fuera, en `Application Support/SplitSync/{private,shared}.json`, y ningún hook los
toca. Por el invariante que el propio repo escribe en `SplitSyncManager.resetLocalGroupsSyncState`
(«borrar filas sin resetear los tokens deja a CloudKit convencido de que este dispositivo está al día y
esos records no se reenvían nunca»), **los grupos del canal CloudKit que convivan en ese store no vuelven
al device jamás**. No es pérdida de datos —siguen en el iCloud del Apple ID— es pérdida de acceso
permanente.

**Por qué es del paso 2 aunque el código sea viejo.** Hasta ahora nada escribía esos markers: el path
`.groupsOnlySignOut` era inalcanzable y el marker `includesGroups` se gateaba por un flag que en
producción siempre era `false`. El flip vuelve alcanzable ese camino **por primera vez**, y la lectura por
capacidad compilada lo extiende además a los devices fuera del rollout, que son justo los que siguen
teniendo CloudKit como canal vivo de Grupos.

**Por qué no se cerró aquí.** El fix obvio —borrar los dos `.json` junto al store— **no es neutro**:
resetear los tokens provoca un re-fetch completo que re-hidrata también las zonas CloudKit **congeladas**
de los grupos ya migrados, con lo que tras un borrado GDPR parte del corpus de grupos reaparecería desde
el iCloud del propio Apple ID. Eso necesita una decisión de producto, no un apaño dentro del commit del
flip. Alternativas a evaluar cuando se retome: un predicado de **presencia** (¿hubo alguna vez estado del
canal backend en este device?) en lugar del marker todo-o-nada, o una purga **por filas** del subconjunto
backend (`isBackendGroup || movedToBackendAt != nil`, el mismo predicado de `GroupsIdentityPurgeGate`),
viable porque el store de grupos monta `cloudKitDatabase: .none` y borrar filas ahí no exporta nada.

**Gatillo: antes de la sesión de QA de dos dispositivos del paso 3**, que es cuando alguien va a cerrar
sesión de verdad. Anotado también en el docblock de `performSignOutWipeIfArmed`, para que se lea desde el
código y no solo desde aquí.

---

## 3 · Antes y después de la Fase 3

| | Antes de la Fase 3 | Después |
|---|---|---|
| **Mecanismo** | flag remoto `groupsBackendEnabled` → OFF | revertir el build + release por TestFlight |
| **Tiempo** | segundos | horas o días (incluye revisión de App Store si es release pública) |
| **Alcance** | inmediato, por device | ~40 ficheros + 4 `.ckdb` + re-deploy de schema a CloudKit Production |
| **¿Sirve de hotfix?** | sí | **no** |

**El flag remoto sigue existiendo después de la Fase 3, pero deja de ser un rollback.** Su único uso
pasa a ser apagar el canal backend **a sabiendas de que Grupos queda inoperativo** — contención, no
vuelta atrás. Documentado así a propósito: leerlo como rollback es el error que este runbook previene.

---

## 4 · Punto de no retorno

La Fase 3 es **caro** de revertir; la **Fase 4** (schema y entitlements) es **irreversible**: toca los
`.ckdb` y el schema de CloudKit Production, que no tienen vuelta atrás por git. ⇒ **el último momento
para decidir un rollback barato es antes de la Fase 4**, y la Fase 3 «se puede parar aquí» es el estado
final útil según el plan.

---

## 5 · Mantenimiento

- Los commits de la **Fase 3** se anotan en el §1 **en el mismo commit que los crea**.
- Si aparece una acción de infraestructura nueva (deploy, SQL a mano, migración), va al **§2** en el
  turno en que se ejecuta. Ese es el apartado que se queda obsoleto en silencio.
- ~~Cuando se encienda `groupsBackendCompiledDefault` en 2.1, **borrar el §0**~~ — **HECHO el 2026-07-30**
  con el paso 2 de D-R1. El §0 dice ahora lo contrario de lo que decía, que es justo el punto.
- **Cuando corra el paso 3** (subir `GROUPS_BACKEND_ROLLOUT_PERCENT` y desplegar el Worker), anotarlo en el
  **§2** — es una acción de infraestructura que git no refleja — y revisar el §3, porque a partir de ahí
  el flag remoto sí es un rollback de verdad hasta que la Fase 3 borre el transporte CloudKit.
