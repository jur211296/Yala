---
created: 2026-07-29
updated: 2026-08-03
tags: [modo-nube, grupos, rollback, runbook]
status: active
---

# ROLLBACK de Grupos — runbook

**Para qué existe.** Hasta ahora, si Grupos se rompía en producción había un botón: apagar
`groupsBackendEnabled` en remoto y el canal volvía a CloudKit, sin build nuevo. **La Fase 3
borra el transporte CloudKit**, así que ese botón deja de devolver nada: apagarlo dejaría Grupos sin
ningún canal. Desde entonces el único rollback es **revertir el build**, y eso hay que tenerlo escrito
ANTES de necesitarlo — cuando algo se rompa, nadie va a reconstruir esta lista.

> **Corrección del 2026-08-03 — este documento decía «en segundos» y era FALSO.** Lo dijo en dos sitios
> (aquí y en el §3) durante todo el encendido, y es una frase que se lee en mitad de un incidente. Hasta
> ese día el percent no cortaba nada para los devices; ahora sí, y el §6 nuevo explica el mecanismo, su
> límite y las dos cosas que el kill NO apaga.

Requisito de entrada de la Fase 3 ([[MODO-NUBE-PLAN-SIMPLIFICACION-GRUPOS]] §6).

---

## 0 · Este runbook ya está CALIENTE (desde el 2026-07-30)

El §0 anterior decía que todo esto estaba frío porque `groupsBackendCompiledDefault = false`. **Ese
enunciado murió con el paso 2 de D-R1**: el compilado está en `true`, así que el canal backend existe en
el binario y lo único que lo separa de estar vivo es el percent remoto. El §5 exigía borrar aquel §0 el
día del encendido, y esto es lo que ocupa su sitio.

**Lo que sigue siendo cierto y conviene no confundir:** el flip no encendió el canal por sí solo. El
getter compuesto exige además `CloudRemoteFlags.groupsBackendEnabled`, o sea el percent remoto.

~~`GROUPS_BACKEND_ROLLOUT_PERCENT` sigue en `0` en producción hasta que el owner lo suba y despliegue
(paso 3). Mientras tanto Grupos sigue funcionando por CloudKit para todo el mundo.~~ **FALSO desde el
2026-07-31**, cuando corrió el paso 3: el percent está en **100** (`gateway/wrangler.toml`,
`[env.production.vars]`, verificado con `curl .../config`) y el canal backend es el vivo para todo device
con `5490544d` y sesión de nube. Esta frase sobrevivió tres días diciendo lo contrario del estado real —y
es la primera que se lee al abrir el runbook—; corregida el 2026-08-03 al cablear el kill server-side.

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
  **Precisión del 2026-08-03, que es la que importa aquí:** «roto» y «apagado» dejaron de ser lo mismo. El
  kill server-side EXCEPTÚA `groups_forget_user` (§6), así que un apagado deliberado **no** bloquea el
  borrado — solo lo bloquea que el canal esté de verdad caído. Lo que el apagado sí bloquea es **cerrar
  sesión**, que exige drenar el outbox por `/groups/push`.

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

### Fase 3 — DESBLOQUEADA el 2026-08-02 (commit 0 hecho; 1 y 2 siguen sin abrir)

> ✅ **La puerta que bloqueaba la fase está cumplida.** El 2026-07-31 este bloque decía que el canal backend
> no subía filas de datos y que `POST /groups/push` no había ocurrido ni una vez. **Eso dejó de ser cierto
> el 2026-08-02**, con build 9 (2.0.5) y dos iPhones reales contra producción.
>
> Verificado en device, sin intervención manual en ninguno de los pasos:
>
> | | |
> |---|---|
> | `POST /groups/push` | ocurre; cursor del pull avanzando (7 → 13) y **ambos** devices convergiendo |
> | Datos A → B y B → A | un gasto creado en cualquiera de los dos aparece en el otro |
> | Bridge en el receptor | su transacción en el Panel, en los dos sentidos |
> | Liquidación | se propaga, y su borrado también |
> | Borrados a nivel de grupo | propagan bien en ambas direcciones |
>
> El reverso NO era redundante: el dueño del grupo y el que se unió van por caminos distintos —el segundo
> depende de que su `SplitMember` resuelva por `user_id`, cosa que no ocurre al unirse sino después—, y ese
> camino quedó ejercitado.
>
> **Y lo llevó el canal nuevo, no CloudKit.** El log del device lo prueba: `GroupsSync
> ckEnqueueSkippedBackendGroup site=enqueueSave` — el canal viejo vio el guardado y se apartó por ser grupo
> de backend. Sin esa línea, el experimento no habría distinguido entre los dos transportes.
>
> Los tres bloqueantes arreglados a ciegas quedan confirmados en device: `c267db5d` (header de App Attest),
> `bca6f775` (keyId huérfano tras reinstalar) y `dbda8378` (ancla por-store del cursor del drain).
>
> **Lo que esto NO significa.** Desbloquear no es «adelante»: la Fase 3 borra el transporte CloudKit y sigue
> siendo irreversible. Lo que se levanta es la condición concreta que la frenaba. Abrir los commits 1 y 2
> sigue siendo una decisión deliberada con sus propias comprobaciones.
>
> **Dos cosas abiertas que conviene tener delante al decidir** — ninguna bloquea, pero constan:
>
> 1. **El puente al Panel no se deshace en el que RECIBE un borrado.** El tombstone borra la entidad del
>    grupo bien, pero deja huérfana la `TransactionItem` puenteada, y el candado de solo-lectura
>    (`splitExpenseID != nil || splitSettlementID != nil`, sin comprobar que resuelva) la deja **imposible de
>    borrar a mano**. Afecta a gastos y liquidaciones, en las dos direcciones. **No lo introdujo el Modo
>    Nube**: `SplitSyncManager.applyRemoteDeletion` tiene el hueco idéntico y le está pasando hoy a usuarios
>    en producción por CloudKit. Por eso no bloquea la fase — borrar CloudKit no lo empeora. Chip
>    `task_736f2831` con las cuatro instancias y las tres piezas del arreglo.
> 2. **El emisor en segundo plano no sube nada** hasta que se vuelve a abrir la app. Es comportamiento
>    correcto de iOS (no hay BGTask ni despertar del emisor), pero es un hueco de producto sin ticket.
>    Costó siete minutos de diagnóstico el 2026-08-02 antes de entenderlo; si vuelve a aparecer un silencio
>    del canal, mirar esto ANTES que el código.

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
| **Mecanismo** | `GROUPS_BACKEND_ROLLOUT_PERCENT` → `"0"` + deploy del Worker | revertir el build + release por TestFlight |
| **Tiempo** | segundos — **y esto es cierto solo desde el 2026-08-03**, ver §6 | horas o días (incluye revisión de App Store si es release pública) |
| **Alcance** | inmediato y GLOBAL (lo aplica el gateway, no el device) | ~40 ficheros + 4 `.ckdb` + re-deploy de schema a CloudKit Production |
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
- **Si se añade una ruta nueva bajo `/groups/*` o un RPC nuevo a `PARAM_ALLOWLIST`, clasificarlo en el §6**
  y en `gateway/src/groups/killSwitch.ts`: ¿es una ENTRADA (gate compuesto en el cliente → el kill la
  corta) o un TEARDOWN (gate compilado → exenta)? Sin esa decisión, una ruta nueva nace **sin kill** y el
  §6 vuelve a describir un botón que no apaga todo lo que dice. El conteo de exentos lo vigila
  `gateway/test/groups.killswitch.test.ts`.
- **Una afirmación de LATENCIA de este documento no se escribe sin medirla.** El «en segundos» del §3 y de
  la cabecera sobrevivió a todo el encendido siendo falso, y las frases de este runbook se leen justo
  cuando nadie tiene tiempo de verificarlas. Hoy hay dos latencias distintas conviviendo (el kill de
  Grupos, inmediato y server-side; los otros dos percents, hasta 6 h y solo cliente): al tocar cualquiera
  de las dos, decir CUÁL.

---

## 6 · El kill-switch de Grupos: qué apaga, en cuánto, y las DOS cosas que no apaga

**Hasta el 2026-08-03 este runbook mentía sobre su propio botón.** `GROUPS_BACKEND_ROLLOUT_PERCENT` lo
leían solo `gateway/src/config.ts` (para publicarlo en `GET /config`) y `gateway/src/env.ts` (para
declararlo). Las rutas de grupos —`/groups/push`, `/groups/pull`, `/groups/merkle`, `/groups/rpc/:fn`— no
lo consultaban **jamás**. Consecuencia medida: bajarlo a `"0"` y desplegar cambiaba la respuesta de
`/config` en segundos, pero **un device que ya tenía el 100 cacheado seguía usando el canal 6 horas o más**,
y el gateway se lo aceptaba. Medido también en la dirección contraria el mismo día: un iPhone real se quedó
con `groupsBackendEnabled == false` durante horas DESPUÉS de subir el percent a 100 — el invitado abría el
enlace de invitación y la app no hacía nada. Mismo mecanismo, mismo retraso, síntoma distinto.

**Y «6 horas» es el PISO, no el techo** (medido al cablear el kill): `refreshMinInterval` es el intervalo
MÍNIMO entre dos fetches de `/config`, y los únicos disparadores son el boot, el `onAppear` de Ajustes →
Almacenamiento y el del onboarding — **no hay refresh en foreground ni por timer**. Para un device que no
relance la app ni pase por esas pantallas, un flip del percent puede tardar **indefinidamente**. Es la razón
de fondo de que el corte tenga que vivir en el servidor.

**Qué lo arregla.** `gateway/src/groups/killSwitch.ts`: las cuatro rutas consultan el percent y, con 0,
responden **403 `yala_groups_disabled`** antes de tocar PostgREST. El pin es
`gateway/test/groups.killswitch.test.ts` (offline: staging sirve los tres percents al 100 y corre
`ENFORCE = "observe"`, así que ahí esta familia de fallos es invisible — y a producción no se puede
llamar desde un test).

### Lo que el kill NO es: un rollout

`0` ⇒ rechaza. **Cualquier valor > 0 ⇒ NO rechaza**, y decide el cliente con su bucket. No puede ser de
otra forma: el bucket sale de `RemoteFlagDecisionLogic.stableBucket(seed:)` sobre un seed de
**instalación** que jamás sale del device (al gateway solo llega un SHA-256 truncado, y solo en el payload
de `/metrics`). Calcularlo server-side desde otra cosa —el `sub`, el keyId, la IP— produciría una
partición DISTINTA de la del cliente: devices ON por un lado y OFF por el otro, split-brain que no se ve
hasta que alguien pone un valor intermedio.

⇒ **poner `"50"` no frena a nadie en el gateway.** Para un escalón gradual sigue mandando el cliente, con
su ventana de 6 h. Lo inmediato es solo el 0.

### Lo que el kill NO apaga, y por qué

| | Qué pasa con el kill activo | Por qué |
|---|---|---|
| **Borrar la cuenta** | **Funciona.** `groups_forget_user` está EXENTO | El cliente ya lo exceptúa: `GroupBackendMembershipService.forgetUser()` usa `ensureEligibleForTeardown()` (capacidad COMPILADA) porque el kill «no debe dejar al usuario sin poder ejercer su derecho de supresión mientras durase». Un servidor que corte más que el cliente reintroduce esa retención de PII por el otro lado |
| **Cerrar sesión** | **BLOQUEADO** mientras el kill esté activo, pero **con vía de escape** | El sign-out exige drenar el outbox de grupos por `/groups/push` y **jamás descarta filas** (`CloudSessionSignOut`, los dos caminos que empujan grupos). Con el push rechazado queda `.blocked` con el alert de conexión de siempre — reintentable, outbox intacto. Es el precio de que el kill pare las ESCRITURAS, que es la mitad peligrosa. Ratificado por el owner el 2026-08-03. **Si alguien queda atascado en un incidente, la salida existe y no hay que improvisarla:** la fila «Salir de Yala en este dispositivo» (`rowLayout` → `.groupsSignOutPlusExitYala`) NO hace push-all y siempre completa |

Los otros 9 RPCs de la allowlist (crear, invitar, revocar, unirse, aprobar, expulsar, salir, renombrarse,
transferir ownership) son ENTRADAS, todos con gate COMPUESTO en el cliente, y el kill los corta.

### Qué ve la app, y qué hace con ello

El 403 no es cosmético: es lo que hace el rechazo distinguible de un transitorio **sin bucle de
reintentos**. `GroupsSyncClient` (push y pull) y `GroupsMerkleClient` ya mapeaban 403 →
`.accountUnavailable` → `SyncCadencePolicy.stopUntilRelaunch`; lo que se añadió es el breadcrumb que
distingue el apagado deliberado de una cuenta suspendida (con un 503 habrían caído en `.transient` →
backoff exponencial para siempre contra un veredicto definitivo, que es la clase de bug del 2026-07-31).
Y en los RPCs, `GroupsRPCError.channelDisabled`: no entra en el retry, **conserva** el intent de join y le
dice al invitado `groups.invite.channelUnavailable` («el enlace es bueno, el canal está apagado») con el
canario `groupJoinIntentDeferred|backendChannelOff` — la MISMA copy y el MISMO canario que el camino en
que el flag local ya estaba OFF, porque es el mismo estado del mundo visto por el otro lado.

### El poder que se le está dando, dicho aquí a propósito

**Un percent mal puesto tumba el canal para todo el mundo al instante.** Antes un error de tecleo se
notaba despacio y a medias; ahora se aplica. Eso es exactamente lo que se pidió —parada inmediata— y por
eso hay que escribirlo donde se lee antes de tocarlo: es una palanca global, no un escalón.

**Y lo que NO cambia:** tras la Fase 3 (que borra el transporte CloudKit) un percent a 0 dejará Grupos
**inoperativo**, no «vuelto a CloudKit». Eso ya está en el §3 y este cambio no lo altera: solo hace el
apagado inmediato, lo que lo vuelve **más** peligroso, no menos.
