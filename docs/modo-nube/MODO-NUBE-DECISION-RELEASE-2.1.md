<!-- INDICE:inicio — generado por scripts/indexar_doc.py, no editar a mano -->

## Índice (13 entradas)

> **No hace falta leer este fichero entero** — son 58 KB. Localiza la entrada
> aquí y salta a ella.

- `—` [Paso 1 · QUÉ PROBAR EN TESTFLIGHT — lo único que el build no puede demostrar solo](#paso-1--qu-probar-en-testflight--lo-nico-que-el-build-no-puede-demostrar-solo)
- `—` [Por qué separados, y no en un build](#por-qu-separados-y-no-en-un-build)
- `—` [Por qué el flip espera al bridge, y los 4 apagones NO lo bloquean](#por-qu-el-flip-espera-al-bridge-y-los-4-apagones-no-lo-bloquean)
- `—` [El SEGUNDO bloqueante del paso 3 — y NO lo introdujo el Modo Nube](#el-segundo-bloqueante-del-paso-3--y-no-lo-introdujo-el-modo-nube)
- `—` [Descartado](#descartado)
- `—` [A3 · Los apagones S2 / S3b / S4](#a3--los-apagones-s2--s3b--s4)
- `—` [El TERCER bloqueante del paso 3 — el canal no sincronizaba DATOS (RESUELTO el mismo día)](#el-tercer-bloqueante-del-paso-3--el-canal-no-sincronizaba-datos-resuelto-el-mismo-da)
- `—` [A2 · Qué evidencia se concede al gate de frescura cuando desaparezca su brazo CloudKit](#a2--qu-evidencia-se-concede-al-gate-de-frescura-cuando-desaparezca-su-brazo-cloudkit)
- `—` [A4 · El vaciado manual de los grupos legacy — CANCELADO, no diferido](#a4--el-vaciado-manual-de-los-grupos-legacy--cancelado-no-diferido)
- `2026-08-06` [A6 · La reacción al cambio de Apple ID en Grupos — PÉRDIDA DECLARADA (owner, 2026-08-06)](#a6--la-reaccin-al-cambio-de-apple-id-en-grupos--prdida-declarada-owner-2026-08-06)
- `2026-07-31` [Paso 3 · EJECUTADO el 2026-07-31 — y los TRES bloqueantes que destapó en device](#paso-3--ejecutado-el-2026-07-31--y-los-tres-bloqueantes-que-destap-en-device)
- `2026-07-30` [Paso 1 · RESULTADO de la verificación en device (2026-07-30)](#paso-1--resultado-de-la-verificacin-en-device-2026-07-30)
- `2026-07-30` [Paso 2 · EJECUTADO el 2026-07-30 — el flip y los 8 sitios de teardown](#paso-2--ejecutado-el-2026-07-30--el-flip-y-los-8-sitios-de-teardown)

<!-- INDICE:fin -->

---
created: 2026-07-28
updated: 2026-08-04
tags: [modo-nube, decision, release, 2.1]
---

# Modo Nube — Decisión de release: todo en 2.1, encendido, sin escalonado

> **SUPERSEDE [[MODO-NUBE-ESTRATEGIA-RELEASE]] por completo.** Ese documento describe dark shipping sobre trunk único con `cloudModeEnabled` apagado y publicación de 2.x con el código dormido. **Eso ya no es el plan.** Lo único que sobrevive de él son los **3 vectores de no-regresión** (migración de schema SwiftData · deploy de schema CloudKit · código compartido) y su checklist: siguen aplicando, porque un usuario de 2.1 que NO migre debe seguir funcionando igual que en 2.0.

**Decisión del owner (2026-07-28), textual:** «todo lo que estamos montando en 2.0.5 será directamente release 2.1 con flag encendida y todo ON, ya no haremos escalonado. Todo de una, con pruebas en TestFlight primero. Todo en v1. Ya no aplacemos nada ni pensemos que subiremos una versión en dark.»

## Qué significa, operativamente

| Antes (dark shipping) | Ahora (2.1 encendido) |
|---|---|
| Se mergea inerte tras el flag; se publican 2.x con el código dormido | **2.1 sale con los flags ON**; no hay versión intermedia dormida |
| El encendido es un evento futuro, separado del release | **El release ES el encendido** |
| Un hallazgo DARK es deuda futura | **Un hallazgo DARK es un bloqueante de release** |
| Rollout escalonado por % con kill remoto | **Todo de una vez**, TestFlight primero y luego App Store |
| «Diferir a post-v1» era una salida válida | **Ya no se aplaza nada**: entra en v1 o no existe |

## Consecuencias inmediatas, y dos son duras

1. **Cablear el cliente contra el Supabase de PRODUCCIÓN es el bloqueante #1 de 2.1** — y es **código, no infraestructura**. Hoy `CloudBackendConfig.supabaseURL` y `anonKey` devuelven `nil`/`""` fuera de `DEV_BUILD` (`Yala/App/Services/CloudBackendConfig.swift:23-44`) ⇒ `isConfigured == false` ⇒ toda la superficie de nube y auth está inerte en un build de producción. **Lo que falta es meter la URL y la anon key de producción** en la rama `#else` de ese mismo fichero — **dos líneas**. **Corrección 2026-07-28: NO van por `Secrets.xcconfig`**, como decía la versión anterior de esta línea. La cabecera de `CloudBackendConfig.swift` documenta a propósito el patrón contrario («commiteada, per-scheme, SIN secretos… la `anonKey` es PÚBLICA por diseño… NUNCA la `service_role`»): es una JWT de rol `anon` gobernada por RLS, una clave *publicable*, y la de staging ya viaja commiteada en `:34`. La regla de CLAUDE.md sobre no hardcodear apunta a **secretos**, y ésta no lo es. Inspeccionado el 2026-07-28: el schema de producción está desplegado (18 migraciones, hasta `g10`); **queda por verificar PITR**, que el conector MCP no expone.

   > **Corrección del owner, 2026-07-28: el proyecto Supabase de producción SÍ EXISTE.** La versión inicial de este documento decía que no, y era falso. El error vino de tomar como hecho un **comentario obsoleto dentro del código**: `CloudBackendConfig.swift:22` afirma literalmente «producción PLACEHOLDER vacío (el proyecto de producción no existe aún)». **Ese comentario hay que corregirlo** — es drift dentro del fichero que gobierna el gate maestro de toda la épica, y ya indujo a error una vez. Nota de método: el MCP de Supabase solo ve **una Org a la vez**, así que para inspeccionar el proyecto de producción hay que reconmutar el conector; no dar por inexistente lo que el conector no está mirando.
2. ~~**`groupsBackendCompiledDefault` tiene que ir a `true`**~~ — **HECHO el 2026-07-30** (paso 2 de D-R1, `CloudSyncFlags.swift:285`; la coordenada `:239` que citaba esta línea llevaba desfasada desde antes). El flag remoto se queda **solo como kill-switch**, no como palanca de rollout — y, desde el mismo commit, **tampoco gatea los paths de teardown**: ver la tabla sitio-por-sitio del §D-R1.
3. **El owner y Pia tienen que estar en el MISMO build.** Con Grupos migrando de CloudKit al backend, un usuario en 2.0.x y otro en 2.1 no se ven entre sí. Si el plan de simplificación borra el transporte CloudKit, los grupos compartidos entre ellos **solo funcionan cuando ambos estén en 2.1**.
4. **Todos los hallazgos DARK de [[MODO-NUBE-AUDITORIA-ESCENARIOS]] se reclasifican a bloqueantes de release.** Los 10 bugs del encendido de [[MODO-NUBE-DECISIONES-ESCENARIOS]] §9 dejan de ser «trabajo antes de encender» y pasan a ser «trabajo antes de subir a TestFlight».
5. **D-A2 queda resuelta y cerrada**: no hay flag propio para escalonar el muro de Grupos, porque no hay escalonado. Todo se activa junto.
6. **La verificación deja de ser opcional.** Con dark shipping un fix podía aterrizar sin probarse en device porque nadie lo ejecutaba. Ahora cada pieza necesita QA real en TestFlight antes de App Store. **El coste de un fix mal dimensionado ya no es solo código muerto: es riesgo en producción.**

## Lo que NO cambia

- Los **3 vectores de no-regresión de 2.x** siguen vigentes y son más importantes que antes: la rama `.icloud` de un usuario que no migra debe quedar **byte-idéntica**. «Todo ON» significa que la nube está *disponible y funcional*, no que todo el mundo se mueva.
- **D-A3** (borrar la zona del container privado personal al cerrar el cutover) sigue en pie, con su orden obligatorio `zona → verificar → mapa`.
- El **ratchet de `qa/coverage-index.json`** y la paridad de l10n en 16 locales siguen siendo obligaciones del repo.

## Migración de los usuarios actuales: **opt-in silencioso** (decisión owner, 2026-07-28)

**Decisión.** Los usuarios que hoy están en iCloud **no se mueven**. La migración vive en Ajustes («Dónde viven tus datos») y la usa quien la busque. Sin prompt, sin banner, sin campaña.

**Consecuencias aceptadas:**
- La app queda **bimodal de forma indefinida**: iCloud y nube conviven, y toda la complejidad de dos modos se mantiene para siempre (los ~10 gates de quiescencia, las dos rutas de wipe, los dos caminos de sign-out, el doble copy).
- En la práctica **casi nadie migrará**, así que la nube arranca con una población mínima. Eso hace que el valor inmediato del modo nube para usuarios existentes sea casi nulo — y es coherente, porque **la motivación de la épica nunca fue mover a los actuales**: fue habilitar web, IA server-side y multiplataforma (decisiones de Fase 0). El modo nube es una capacidad, no una campaña.
- **De dónde vendrá la población de nube, entonces: de los usuarios NUEVOS.** Por eso **D-A7 (born-cloud en v1) deja de ser opcional y se vuelve la pieza central del valor de 2.1** — es el único camino por el que la nube crece. Un born-cloud sin construir + opt-in silencioso = nube vacía.

  > **Al construir D-A7, abrir [[MODO-NUBE-ONBOARDING-GRUPOS-POST-CLOUDKIT]] primero.** Anclado aquí a
  > petición del owner (2026-07-31) porque son cabos que solo se vuelven visibles cuando la nube es el
  > único camino, y la fecha en que eso pasa es ésta. **Uno de los tres bloquea a la población de la que
  > depende esta línea** — pero NO es el que este párrafo decía, y la corrección importa porque señala al
  > fichero equivocado:
  >
  > **CORREGIDO el 2026-08-06, medido en el árbol.** Este texto afirmaba que el muro
  > `GroupsICloudAvailabilityGateLogic` era «incondicional sobre `isAccountAvailable` y NO consulta el canal».
  > **Era falso ya cuando se escribió**: `7b5ff216` (2026-07-15, G5-C) había puesto el cortocircuito por flag
  > en el call-site **dos semanas antes** ⇒ ningún born-cloud estaba bloqueado ahí. Lo que sí estaba roto era
  > invisible y de otra naturaleza: esa condición vivía en un `else if` del `@ViewBuilder` de `ContentView`,
  > donde **ningún test la alcanzaba** —borrarla dejaba los 5564 en verde—, y eso lo cerró `965a4d86`
  > (validado por mutación el 06/08). ⇒ **el muro de Grupos no es un bloqueante de D-A7 y no lo era.**
  >
  > **El bloqueante REAL es su gemelo, en otro fichero:** `OnboardingView.swift:511` mira
  > `isAccountAvailable` sin consultar el canal, y **corta la única ruta a `.groupsOnly` del onboarding**
  > (`:512`) con el aviso «Activa iCloud para usar grupos / Los grupos se sincronizan por iCloud» — copy que
  > con el canal al 100% **miente**. Ése sí bloquea hoy, en el primer contacto, y **no muere con la Fase 3**
  > (`OnboardingView` no está entre los 14 ficheros que borra el commit 1). Es el **CHIP C4** de
  > [[MODO-NUBE-CHIPS-FASE3]], primero de la cola.
  >
  > Los otros dos cabos siguen como estaban: limpieza de la Fase 3 (dos flags que quedan muertos al borrar el
  > transporte) y el cierre del onboarding educativo de Grupos.
- La regla de no-regresión sube de importancia: como la inmensa mayoría se queda en `.icloud`, **cualquier regresión en esa rama afecta a todos los usuarios reales** y el modo nube no compensa nada.

## Trabajo que esta decisión cancela

- Todo el andamiaje pensado para **escalonar el encendido**: rampas por porcentaje, gates de rollout parcial, y los hazards que solo existen cuando dos poblaciones corren builds distintos con el mismo backend.
- **Corrección (misma fecha, error de este documento):** la versión original decía que **C-10** («grupo congelado sin salida durante el rollout») estaba «ya descartado». **No lo estaba: estaba commiteado.** El chip se descartó en la sesión de auditoría creyéndolo sin sentido por el giro de Grupos, pero el trabajo ya había aterrizado — `90ebabea` (06:54, +1.405) y `ed38c1ea` (07:20, +1.845), **3.250 líneas**, once minutos antes de que se escribiera esta línea. No es trabajo cancelado: es trabajo **pagado que se tira**. Lo que sí se cancela es su cola (device-QA, 26 keys × 16 locales, la UI de espera y el deploy pendiente de dos field keys a CloudKit Production). Queda como el ejemplo más caro de por qué las decisiones de alcance tienen que llegar a los chips ANTES de que corran, no después.
- La cláusula «diferir a post-v1» de [[MODO-NUBE-DIFERIDOS]]: los items cuyo gatillo era «cuando se encienda» pasan a tener gatillo **«antes de 2.1»**. Revisar el registro entero con esa lente.

---

## D-R1 · Cómo se enciende el canal de Grupos — DECIDIDO por el owner el 2026-07-30

**En DOS pasos separados, y el encendido después de cerrar el bridge.**

**Paso 1 — la configuración, ya.** Solo el bloqueante #4: las dos ramas `#else` de `CloudBackendConfig`
(`supabaseURL` y `anonKey`), en su propio build a TestFlight. NO mueve ningún dato de Grupos —
`groupsBackendCompiledDefault` sigue en `false`. Lo que hace es volver **verificable** lo que hasta hoy se
configuró a ciegas en el proyecto de producción: el sign-in real con Apple y con Google, los Authorized
Client IDs, el schema, el `revoke` de `migrate_group` y el aviso de versión obligatoria (que hoy no emite
tráfico porque `CloudRemoteConfig.refreshIfDue` gatea por `isConfigured`).

**Paso 2 — el encendido, después del fix del bridge remoto.** El flip de
`groupsBackendCompiledDefault` a `true`, en un segundo build. Ahí los dos canales quedan vivos a la vez y
**el kill-switch remoto todavía funciona** (el flag remoto solo puede MATAR): es la única ventana para
probar el recorrido completo con un segundo humano en dos devices y poder apagarlo en segundos.

> ⚠️ **El flip son DOS cambios, no uno. Con solo el compilado es un NO-OP.**
> `CloudSyncFlags.groupsBackendEnabled` es `groupsBackendCompiledDefault && CloudRemoteFlags
> .groupsBackendEnabled`, y `GROUPS_BACKEND_ROLLOUT_PERCENT` está en **0** en producción ⇒ el flag remoto
> lo mata igual. Hay que **subir ese percent y desplegar el Worker** además de flipar el compilado, o el
> build sale, la sesión de QA de dos dispositivos se monta, y nada cambia. Encontrado el 2026-07-30 al
> auditar los gates; queda también como comentario en la línea de `gateway/wrangler.toml`.
>
> Condición de entrada ya cumplida: el gemelo del bridge (`f0a723e1`) y el `rollback()` del apply
> (`b422565e`) están cerrados. Y el orden importa: el percent remoto se sube **después** de tener el build
> con el compilado en `true` instalado en los dos devices — al revés no enciende nada y solo mueve la
> ventana del kill-switch.

### Paso 1 · QUÉ PROBAR EN TESTFLIGHT — lo único que el build no puede demostrar solo

Está escrito en el mensaje de `3c49278c`, pero se busca aquí, así que va aquí. **Paso 1 ejecutado:
`3c49278c` (config) + `e32d2db6` (docs), 2026-07-30.**

1. **Sign-in con Apple contra producción, desde cero.** Completar el flujo y **volver a abrir la app**:
   la sesión debe sobrevivir (vive en Keychain `AfterFirstUnlockThisDeviceOnly`).
2. **Sign-in con Google contra producción.** Si responde `invalid client` o equivalente, el iOS client ID
   de producción **no** está en los Authorized Client IDs de Supabase. Es
   `295312853864-7dt8d2buik9nacg71aurdpqu56r0l4h8.apps.googleusercontent.com` (bundle
   `com.jurgenschmidt.yala`) — **OJO: distinto del de `Yala Dev`**. Es la única forma de comprobarlo; no
   se puede saber desde el código.
3. **Que tras el primer boot NO aparezca ninguna pantalla de «actualiza la app».** Confirma que `/config`
   responde y que el umbral desplegado sigue en `0`.
4. ~~**Que Ajustes NO muestre «Dónde viven tus datos» y el Welcome NO muestre cards de nube.**~~
   **INVERTIDO el 2026-07-30**: con `CLOUD_MODE_ROLLOUT_PERCENT` en 100 (ver abajo) la fila **debe
   aparecer**. La redacción original era una comprobación NEGATIVA que pasaba igual si el gateway estaba
   caído —sin snapshot, `absentDefault` es `false` fail-closed en producción— así que no demostraba nada.
5. **Que nada de Grupos cambie**: el canal sigue siendo CloudKit hasta el paso 2.

Verificado en el commit: los dos builds limpios, 169 tests en 18 suites con AMBOS schemes (18 pedidas =
18 reportadas), `validate-coverage` OK. Y confirmado aquí de forma independiente: los dos JWT decodificados
llevan cada uno su `ref` (`fostjbbwstyuunmmefuk` en `#if DEV_BUILD`, `kefvaiymtgytemwbltlz` en `#else`), sin
cruce, y `groupsBackendCompiledDefault` sigue en `false`. Los dos rojos ambientales del scheme `Yala`
desaparecieron, que era la señal esperada.

### Paso 1 · RESULTADO de la verificación en device (2026-07-30)

**La infraestructura alrededor de `3c49278c` está probada; el contenido del propio commit, NO.** Esa
distinción es el motivo de esta tabla: sin ella, «paso 1 ejecutado y verificado» se lee como si las
credenciales de producción estuvieran comprobadas, y no lo están.

| Qué | Estado | Con qué evidencia |
|---|---|---|
| `/config` alcanzable desde un build de producción, percents servidos, snapshot persistido | **VERIFICADO** | A/B: con el percent en 0 la fila de Ajustes no aparecía; tras subirlo a 100 y desplegar, aparece. La visibilidad sigue al valor servido |
| `GET /config` de producción sirve lo que dice `wrangler.toml` | **VERIFICADO** | consulta directa: `{cloudModeRolloutPercent:100, cloudOnboardingChoiceRolloutPercent:0, groupsBackendRolloutPercent:0, minSupportedBuild:0}`, `environment: production`, `enforce: enforce` |
| Umbral de forzado en 0 · sin pantalla de «actualiza la app» | **VERIFICADO** | primer boot del build limpio |
| Grupos sin cambios · el bridge del canal CloudKit sigue puenteando | **VERIFICADO** | gasto de grupo creado → aparece en el grupo Y su transacción personal en el Panel |
| **URL + anon key de Supabase de PRODUCCIÓN** | **SIN VERIFICAR** | nada las ejercita sin tráfico de auth. `/config` lo sirve el Worker de Cloudflare y **no toca Supabase** |
| **Google iOS client ID en los Authorized Client IDs** | **SIN VERIFICAR** | solo un sign-in real lo dice; no es consultable desde el código ni desde el conector MCP |

**Por qué los puntos 1 y 2 no se pudieron ejecutar, y no es un fallo del build:** la lista se escribió sin
comprobar que las tres entradas de nube dependen del **flag remoto**, no solo de `isConfigured`
(`StorageRowGateLogic.isVisible` exige `remoteEnabled || isEngaged`; `WelcomeAccountChoiceLogic
.visibleExistingOptions` exige `remoteCloudEnabled`; el sheet de invitación está DARK con
`groupsBackendEnabled` OFF). Con los percents en 0 **no existía ningún camino al sign-in**. Y con el percent
en 100 sí existe, pero **el sign-in es el cuarto paso DENTRO del flujo de migración** —consent → doble
confirmación → chooser Apple|Google → auth → progreso → relaunch—, así que alcanzarlo implica migrar datos
de verdad, que es justo lo que el paso 1 declara no hacer. ⇒ **se pliegan a la sesión del paso 2**, donde la
migración es parte del guion.

**Nota operativa que costará tiempo si no se sabe:** `RemoteFlagDecisionLogic.refreshMinInterval` son **6
horas**. Un device que ya arrancó con el percent viejo NO ve el cambio hasta que expire; para forzarlo hay
que **borrar y reinstalar la app** (el snapshot vive en `UserDefaults`, se va con el contenedor). Sin eso,
un flip de percent parece no haber funcionado.

**`CLOUD_MODE_ROLLOUT_PERCENT` queda en 100 de forma permanente**, no como valor de prueba: es lo que exige
la decisión de migración opt-in silencioso de este mismo documento («la migración vive en Ajustes y la usa
quien la busque»). Desplegado en `0b1283fe`; anotado en el §2 de [[MODO-NUBE-ROLLBACK]].

### Por qué separados, y no en un build

Son dos clases de fallo distintas: el paso 1 prueba INFRAESTRUCTURA, el paso 2 mueve DATOS reales.
Juntándolos, un fallo no diría cuál de los dos lo causó.

### Por qué el flip espera al bridge, y los 4 apagones NO lo bloquean

S2/S3/S4/S6 son consecuencias del **borrado** (Fase 3), no del encendido ⇒ no bloquean. El fix del bridge
remoto sí va antes, porque el flip mueve datos: **medido el 2026-07-30, ese defecto existe en los DOS
canales** — `GroupsSyncClient.scheduleBridge` (`:2009`) usa el mismo reintento en-sesión sin respaldo
persistente que `SplitSyncManager`. Encender antes de arreglarlo no lo empeora, pero pone datos nuevos
encima de un agujero conocido. **Corolario para el chip del bridge: su fix tiene que cubrir los dos
canales, no solo el viejo.**

> **✅ CONDICIÓN CUMPLIDA (2026-07-30). El paso 2 queda DESBLOQUEADO.** El gemelo está cerrado:
> `GroupsSyncClient.scheduleBridge` arma `GroupsPendingBridgeIntent` (canal `.backend`) **antes de su
> `guard`** —no «donde se acumula»: ese `guard` tira los IDs por dos caminos, `isReady == false` y la
> quiescencia diferida a un `Task` en memoria que además se cancela cuando entra otro lote— y `runBridge`
> confirma **por ID cumplido**, capturando el retorno de `bridgeRemote*` que antes descartaba. Al cablearlo
> apareció un segundo defecto que ningún reporte tenía: el retome clasificaba como *abandonado* todo ID de
> zona `isBackendGroup`, y **todos** los grupos del canal nuevo lo son ⇒ habría descartado entero lo que el
> flip enciende. El intent persiste ahora el canal de cada ID. Y el retome se mudó a
> `Yala/Services/Groups/GroupsPendingBridgeResume.swift` porque vivía en un fichero que la Fase 3 borra.
> Verificado por mutación (exit 65 con el `arm` neutralizado, 0 sano) y con las 17 suites del área en verde.
> Detalle en [[MODO-NUBE-FASE3-BRIEF]] §«Reportado y SIN dueño».
>
> **Lo que el flip sigue necesitando** es su propio build y su QA en TestFlight con un segundo humano en dos
> devices, con el kill-switch remoto a mano. `groupsBackendCompiledDefault` **no se ha tocado** aquí: sigue
> en `false`, porque el flip es una decisión de release, no de este fix. *(Párrafo histórico: lo escribió el
> commit del bridge y sigue describiéndolo bien. El flip llegó DESPUÉS, ese mismo día — ver la sección de
> abajo; y la coordenada, hoy, es `CloudSyncFlags.swift:285`.)*

### Paso 2 · EJECUTADO el 2026-07-30 — el flip y los 8 sitios de teardown

`groupsBackendCompiledDefault = true` (`CloudSyncFlags.swift:285`). Anotado en el §1 de
[[MODO-NUBE-ROLLBACK]] con su commit. **Sigue sin encender nada**: el getter compuesto exige el remoto y
`GROUPS_BACKEND_ROLLOUT_PERCENT` continúa en `0` hasta el paso 3, que hace el owner después de instalar
este build en los dos devices.

#### La pregunta abierta que dejó el docblock, resuelta

`CloudSyncFlags.groupsBackendEnabled` avisaba: «un kill remoto transitorio (…) cambia el shape de los
paths de teardown que leen este getter — revisar entonces si esos paths deben leer el compilado directo».
**Sí deben.** El criterio y su porqué:

> Un kill remoto apaga el **canal**, no borra lo que ya subió al servidor ni retira la copia local. Un
> teardown que se salta la limpieza porque el flag está muerto deja datos del usuario en el device tras un
> sign-out, y filas suyas en Supabase tras un borrado GDPR.

Y hay un segundo motivo, que resultó más fuerte que el primero al mirar el código: **el término remoto ni
siquiera es testigo de ese corpus.** `CloudRemoteFlags.decide` devuelve `absentDefault` (en producción
`false`) cuando no hay snapshot **o cuando el snapshot está corrupto**, y por debajo hay un bucket de
rollout. Un device con todo su corpus de grupos en el backend puede leer el flag `false` por razones que
no tienen nada que ver con él. Condicionar una limpieza irreversible a esa señal es condicionarla al azar.

Decisión por sitio (todos → `groupsBackendCompiledCapability`):

| Sitio | Qué gatea | Qué pasaba con el compuesto bajo kill |
|---|---|---|
| `CloudSessionSignOut:74` — dispatch de `CloudSignOutFlowLogic.path` | `.groupsOnlySignOut` vs `.privateReset` | `.privateReset` cierra la sesión y **no toca nada más**: sobreviven las filas de `GroupSyncOutbox` (que no tienen dueño — `pushPending` las sube con el bearer de la sesión que esté viva), el consent (⇒ la cuenta siguiente no ve la pantalla y el canal subiría bajo un `user_id` que jamás consintió) y las filas `Split*` del que se fue |
| `CloudSessionSignOut:117` — `exitYalaOnThisDevice` | purga in-session + consent + `armGroupsOnlyWipe` | es el **único** limpiador de esas tres superficies en este camino: aquí no se arma el wipe personal, así que el boot-hook que limpia el consent no corre, y el hook solo-grupos no lo limpia a propósito |
| `CloudSessionSignOut:263` — marker `includesGroups` en `.cloud` | que el boot borre el store de grupos | el boot ya mata `YalaSyncMeta` **incondicionalmente**, donde viven outbox y cursor ⇒ quedaba el par incoherente «filas RETENIDAS + cursor DESTRUIDO». Y `SplitGroup` no tiene scoping por usuario: en un device que ese hook deja «recién instalado», la cuenta siguiente vería grupos, miembros y montos de la anterior, sin nada que los retire después |
| `CloudSessionSignOut:460` — mismo marker tras borrar cuenta | ídem, post-GDPR | agravante: la sesión ya murió y las filas del servidor ya no existen ⇒ **nada refresca ni retira ese residuo nunca** |
| `CloudSessionSignOut:519` — `drainOnce` del push-all | capturar la History antes de cerrar | aquí el motivo NO es «limpiar aunque esté apagado»: es que **el término remoto nunca protegió nada**. El transporte no consulta el flag, así que con una sola fila viva el ciclo drena y empuja igual; el gate solo compraba un no-op cuando el outbox ya estaba vacío. Y no drenar no difiere nada: los dos boot-wipes destruyen los archivos donde vive esa History |
| `ProfileView:135` — `signOutRowPath` | la hoja de alcance y qué filas se pintan | **no estaba en la lista original y es pareja obligatoria de `:74`**: si divergen, la hoja resuelve `.signOutPrivate` (promete los grupos preservados) mientras el dispatch arma su borrado, y encima desaparece la fila de escape «Salir de Yala en este dispositivo» |
| `AccountDeletionService:93` → `:161` | ejecutar `groups_forget_user` | el `display_name` REAL del usuario queda vivo en `group_members` de otra gente, sin `status='removed'` y sin bump de HLC (⇒ los devices de los co-members ni convergen por LWW), y sus grupos con `owner_user_id = NULL`, que `transfer_group_ownership` clasifica como huérfano y no auto-cura. El header de la migración `g12_01` ya lo decía: la cascada de `auth.users` es una belt **incompleta** que «NO sustituye a `groups_forget_user`» |
| `GroupBackendMembershipService.forgetUser` — gate propio `ensureEligibleForTeardown` | el RPC anterior | **sin esto, cambiar `:93` solo habría empeorado las cosas**: `ensureEligible` es compuesto y `forgetUser` lanzaría `sessionExpired` ⇒ el borrado pasa de retención silenciosa a **bloqueo duro** durante todo el kill. Las dos mitades son inseparables |

**Lo que se queda COMPUESTO, y no por descuido:** todas las ENTRADAS — `startIfEligible`, crear grupo,
unirse, invitar, revocar, aprobar, expulsar, salir, renombrarse, la superficie de invitación, el tab de
la sesión secundaria y el batch D10 de `AppBootstrapper:449` + `UserDataResetView:62`. Eso es literalmente
lo que el kill-switch existe para cortar. `groups_forget_user` subsume lo que hace el batch, así que
congelarlo bajo kill es coherente.

**Trade-off aceptado, por escrito antes del incidente y no durante:** el motivo más probable de un kill
remoto es que `/groups/*` esté roto, y ahora el paso 1 del borrado de cuenta es obligatorio ⇒ el RPC falla
⇒ el usuario **no puede eliminar su cuenta mientras dure**. Es retraso-de-borrado frente a
retención-permanente-de-PII, y se elige lo segundo.

**Lo que NO se arregló, con permiso explícito del owner:** el residual de los change tokens de CKSyncEngine
en los dos boot-wipes de Grupos. Está en el §2 de [[MODO-NUBE-ROLLBACK]] con su gatillo (antes de la sesión
de QA del paso 3) y anotado también en el docblock de `performSignOutWipeIfArmed`. Resumen: borrar los
archivos del store sin resetear los tokens deja los grupos del canal CloudKit inalcanzables para siempre,
y el fix obvio no es neutro porque re-hidrataría las zonas congeladas de los grupos ya migrados —lo que
tras un borrado GDPR resucitaría parte del corpus desde el iCloud del propio Apple ID.

#### Verificado

Los dos builds limpios en `iPhone 17 Pro` (iOS 26.5, Xcode 26.6 — **esta** Mac, la que hará el archive),
cero warnings nuevos (los 3 de `ContentView`/`AccountEntitlementService` son la línea base). **28 suites
pedidas = 28 reportadas, 305 tests, con AMBOS schemes.** `EdgeCasesUITests` 2/2 (el XCUITest del área
determinista que casa por `codeGlobs`). `validate-coverage` OK.

**Mutación, con exit codes:** revertido el flip a `false` y recompilado, caen **dos** suites
independientes — `CloudRemoteConfigTests` exit 65 (2 issues:
`groupsBackend_remoteKillSwitch_cutsChannel_withCompiledOn` pierde su control positivo y la capacidad) y
`GroupBackendMembershipServiceTests` exit 65 (`forgetUser_survivesRemoteKill_whileEntriesStayClosed` caza
`.sessionExpired`). Restaurado desde backup explícito, no desde un trap.

**Un rojo PREEXISTENTE, ajeno a este trabajo:**
`GroupsSyncClientTests` › «Un save de página que falla no deja el grafo remoto a medias en el contexto
compartido» (`:346`) falla en `iPhone 17 Pro` / iOS 26.5. Verificado en **worktree limpio desde `3c091b7b`**
(exit 65, 65 tests, mismo fallo) y con el flip revertido ⇒ **no lo causa nada de este commit**. El síntoma
es que `context.rollback()` no revierte la mutación de `groupCursorsJSON` en el objeto en memoria
(`context.hasChanges == false` sí pasa), así que el cursor queda avanzado. `b422565e` se validó en iOS 27.0,
en la otra Mac: es un **cambio de comportamiento de SwiftData entre runtimes**, y tiene consecuencia real
—en iOS 26.x el `rollback()` no cierra del todo el laundering que ese commit quería cerrar—. Ticket aparte.

### Paso 3 · EJECUTADO el 2026-07-31 — y los TRES bloqueantes que destapó en device

`GROUPS_BACKEND_ROLLOUT_PERCENT` de `"0"` a `"100"` en `[env.production.vars]` (`98d6415d`), desplegado.
Con eso el canal quedó encendido de verdad por primera vez… y **no funcionó**.

**Síntoma medido en producción:** crear un grupo en un iPhone con TestFlight falla con «Error de
Yala.GroupsRPCError 2». `npx wrangler tail --env production` da la causa literal:

```
POST /v1/attest/register - Ok
GET  /groups/pull?cursors=%7B%7D&limit=500 - Ok
  (log) [gw-err] 401 yala_attest_required: Falta el token de sesión de App Attest.
```

El device **registra App Attest bien**. Lo que no viaja es el header `X-Yala-Attest-Session` en las llamadas
a `/groups/*`.

**Causa raíz:** los inits de los clients declaran `attestProvider: … = { nil }` y **nueve construcciones de
producción se quedaron con el default** — las 6 de `GroupsMembershipClient` que faltaban, el `.shared` de
`GroupsSyncClient` (que arrastra su `GroupsMerkleClient`) y las 2 de `PushTokenRegistrationClient`. `{ nil }`
es un valor legal ⇒ el compilador no dice nada.

**Por qué ninguna verificación previa lo vio, que es lo importante:** **staging corre `ENFORCE = "observe"`**
(`gateway/wrangler.toml`, `[vars]`) frente al `"enforce"` de producción. En `observe` el token ausente se
**cuenta pero no bloquea**. Todo el incremento G2 se construyó y se validó contra un gateway que no exigía
lo que producción sí exige, así que la suite, el dogfooding y cualquier e2e contra staging estaban verdes con
el canal roto. **Es una clase entera de fallo invisible en QA por construcción**, no un descuido puntual —
por eso la lección se guardó como regla durable (`.claude/rules/gateway-attest.md`) y no solo como fix.

**Fix:** `attestProvider: AttestSessionProvider.live` en las 9 construcciones cuyas rutas pasan por
`requireUserAndAttest`, decidido **ruta por ruta leyendo la guard de cada handler** del gateway. Sobreviven
cinco `{ nil }`, todos de `CloudAccountClient` y todos correctos: `/account/claim`, `/account/exists`,
`/account/migration`, `/account/siwa/exchange` y `/account/entitlement` van por `requireUser` y son flujos
PRE-SESIÓN — cablear attest ahí es justo lo que puede romper el alta. Cada uno lleva su porqué en el código,
citando el handler. El proveedor se mudó de `AccountDeletionService.Dependencies.liveAttest` a
`AttestSessionProvider`: que el proveedor de attest de Grupos viviera dentro del servicio de BORRADO DE
CUENTAS es la explicación más probable de que seis sitios no lo encontraran.

**Estado de verificación, explícito porque la asimetría lo exige:**

| Qué | Estado | Con qué evidencia |
|---|---|---|
| El cableado existe en las 9 construcciones y no puede nacer una décima sin él | **VERIFICADO** | `AttestWiringTests` (source-scan con conteo esperado por cliente) + 2 mutantes en exit 65: sin `attestProvider` y con `{ nil }` explícito, cada uno cazado por su propio test |
| El header viaja cuando el proveedor es no-nil, y no viaja cuando es nil | **VERIFICADO** | `AttestHeaderTransportTests`, los 3 clients, par completo por cada uno |
| **El 401 desaparece en device contra producción** | **VERIFICADO el 2026-07-31 (build 8)** — pero hicieron falta DOS builds, ver abajo | tail de producción con `/v1/attest/register`, `/push/register`, `/groups/pull`, `create_group` y `/rates/live` **todos en Ok y sin una sola línea `[gw-err]`**; `create_group` funciona en device y Yala IA vuelve en el segundo teléfono |

⚠️ **No se tocó `ENFORCE`.** Bajarlo a `"observe"` habría hecho «pasar» la prueba apagando App Attest para
todo el tráfico del gateway, incluido el proxy de IA cuyas API keys son la razón de esta épica.

### El SEGUNDO bloqueante del paso 3 — y NO lo introdujo el Modo Nube

**Que quede escrito, porque dentro de dos meses parecerá que esta épica rompió el attest y no es verdad.**
Con el cableado del header ya dentro (`c267db5d`, build 7) crear un grupo **seguía** dando 401. La causa era
otra, anterior, y de alcance mayor:

> **La key de App Attest muere con la INSTALACIÓN de la app** (vive en el Secure Enclave, atada a la
> instancia) **mientras el string del keyId SOBREVIVE en el Keychain.** Tras reinstalar, el keyId designa una
> key inexistente y `generateAssertion` falla con `DCErrorInvalidInput` teniendo todos los inputs bien
> formados (medido en device: `keyIdLen=44 challengeLen=76 hashLen=32`).

Y no se curaba nunca, por cuatro cosas que se sumaban: el fallo era un `DCError` **local**; el `catch` solo
cubría `AppAttestError.unknownKey`, que se lanza EXCLUSIVAMENTE al leer una respuesta del gateway ⇒ no
re-registraba; nada borraba el keyId ⇒ cada intento releía el mismo; y el `try?` de `AttestSessionProvider`
con logs bajo `#if DEBUG` no dejaba rastro en producción.

**Alcance real, que es lo que importa para 2.1:** cualquier usuario que hubiera reinstalado Yala se quedaba
sin Grupos, **sin Yala IA y sin proxy de tipos de cambio**, de forma permanente, viendo solo «Inténtalo en
unos minutos». Llevaba vivo desde que existe App Attest. El encendido de Grupos únicamente le dio una
superficie que alguien miró.

**Fix: `bca6f775`.** Descarte del keyId **acotado a `.invalidInput` y `.invalidKey`** — `DCError.h` manda
reintentar `serverUnavailable` con la MISMA key para preservar la risk metric del device, así que un `catch`
genérico quemaría una key en cada fallo de red. Decide `AttestKeyRecoveryLogic` (función pura), pinneado por
`YalaTests/AttestKeyRecoveryLogicTests.swift` con mutación en exit 65.

**Lección operativa que costó un desvío entero:** un build firmado en desarrollo **no puede validar attest
contra producción**. `verifyAttestation.ts:79` compara el AAGUID byte a byte y con `ATTEST_ENV = "production"`
exige el de producción, así que un build de Xcode siempre recibe `401 yala_attest_invalid`. Sirve para
**diagnosticar** (los logs de `#if DEBUG` viven ahí, y que aparezca un `POST /v1/attest/register` donde antes
no aparecía nada ES la prueba de que el lado local se arregló), nunca para validar. Está en
`.claude/rules/gateway-attest.md` con las cuatro hipótesis que se refutaron por el camino.

### El TERCER bloqueante del paso 3 — el canal no sincronizaba DATOS (RESUELTO el mismo día)

**Leer esto antes de concluir «el canal funciona».** Lo verificado el 2026-07-31 con dos iPhones reales es
que el 401 desapareció y que las operaciones de MEMBRESÍA funcionan: atestación (`register` y `assert`),
`create_group`, `create_group_invite`, `join_group`, `approve_member`, `GET /groups/pull` con su cursor
avanzando tras la aprobación, `/push/register` y `/rates/live`. **Todas ellas van por RPC o por el pull.**

**Lo que NO funciona: subir filas de datos.** `POST /groups/push` **no aparece ni una vez en ningún tail de
producción de ese día** — ni al crear un gasto compartido, ni al crear un segundo con el tail ya abierto, ni
tras pull-to-refresh en la lista de grupos y dentro del grupo. En el teléfono que lo crea todo parece bien
(el gasto está en el grupo y su transacción puenteada está en el Panel, con el importe de SU parte); en el
otro no llega nunca, y el cursor del pull se queda clavado. Deducción: `syncNowFromUI` sí se ejecuta (los
pulls lo demuestran), el drenaje corre y produce **cero filas**, el outbox queda vacío y por eso el push no
manda nada.

**SEIS hipótesis refutadas leyendo el código ese mismo día — no las vuelvas a recorrer:** (1) el grupo sin
`isBackendGroup` y el muro C2-bis (falso: `GroupBackendMembershipService.swift:100` lo pone, y
`backendGroupZoneIDs` es un fetch simple de ese flag); (2) el autor del contexto pegado en
`outboxSaveAuthor` (falso: los tres escritores lo restauran con `defer`); (3) el gasto guardado bajo ese
autor (falso: `GroupExpenseService` no lo menciona); (4) `drainOnce` sin call-sites, que ese día ya había
tenido dos precedentes (falso: `GroupsSyncClient:457` dentro de `syncNowFromUI`, más `syncNowFromPush` y el
loop de `startIfEligible`); (5) `SplitExpense` fuera del muro `groupEntityNames` (falso: `translate` tiene
rama explícita); (6) el mapa de emisión declarándolo no-emisible (falso: `GroupEntityEmissionMap.splitExpense`
está completo y en `emittableGroupEntityNames`).

⇒ **La respuesta no estaba en la lectura estática: había que instrumentar.** Y había un dato que apuntaba a
dónde: existe un test que afirma lo contrario de lo que hace producción — en
`YalaTests/CloudSync/GroupsSyncClientTests.swift` se crea un `SplitExpense`, se drena y se afirma que llega
al `GroupSyncOutbox`, y estaba VERDE. **La diferencia entre ese test y producción era el diagnóstico**, y una
sonda sobre `fetchHistory` lo cerró en una corrida. La causa, abajo.

#### La causa, y el fix

> **`DefaultHistoryToken` es POR-STORE.** `fetchHistory(predicate: $0.token > token)` devuelve lo posterior
> **del store de ese token** y **oculta por completo los demás stores del container** — ni siquiera surfacea
> una transacción de otro store posterior en el tiempo. El drain de Grupos anclaba su high-water con la
> última transacción procesada **fuera cual fuera su store**, y en producción el tráfico del store PERSONAL
> domina y llega antes ⇒ el cursor se anclaba ahí ⇒ el canal dejaba de ver su propio store. Y como sin verlo
> tampoco puede volver a anclar en él, es un **PUNTO FIJO**: cinco gastos seguidos, cero filas.

**El canal personal no lo sufre, y eso es suerte estructural, no diseño**: sus filas emisibles son
personales, así que su punto fijo natural cae en el store correcto. Comparte el mismo patrón.

**Lo que lo hacía permanente**, y es la parte que no se ve leyendo: `GroupExpenseService.createExpense`
puentea a `TransactionItem` justo después de guardar el gasto ⇒ esa transacción **personal** es posterior,
adelantaba `lastDrainedTxAt` por encima del gasto, y el guard del token —que compara
`tx.timestamp > lastDrainedTxAt`— lo daba por validado al relanzar. Pérdida definitiva, ni con dos
relanzamientos (medido: `incomparable=0 recovered=0`).

**Fix: `dbda8378`.** El fetch no se puede acotar por store (`storeIdentifier` **no** es keypath soportado en
el `#Predicate` de un `HistoryDescriptor`, medido), así que va por el ancla, en tres piezas: el avance solo
se mueve con transacciones del store de Grupos; `GroupSyncCursor.historyTokenStoreID` guarda la procedencia
del ancla y `nil` (build anterior) la descarta —**esto es lo que migra los cursores ya envenenados de todo
device con build 8, y no es opcional: el guard existente no los rescata**—; y el re-ancla de ese guard
también filtra por store. Pinneado por `YalaTests/CloudSync/GroupsDrainHistoryStoreAnchorTests.swift`
(9 tests), con las tres mutaciones en exit 65.

**Lección de método, que es la misma del segundo bloqueante:** `GroupsSyncClientTests` afirmaba lo contrario
que producción y estaba **verde**, porque su escenario limpio nunca drena después de una transacción
personal. La diferencia entre el test y producción ERA el diagnóstico, y **una sonda de tres `print` sobre
`fetchHistory` lo cerró en una corrida**, después de cinco hipótesis plausibles y falsas. Al escribir un test
de drain, mete tráfico del otro store entre medias o no estás probando producción. Está en
`.claude/rules/swiftdata-cloudkit.md`.

#### VERIFICADO EN DEVICE el 2026-08-02 (build 9) — la matriz de dos dispositivos, cerrada

Este bloque se escribió el 2026-07-31 diciendo «pendiente de verificar en device». Ya no lo está. Con build
9 (2.0.5) y dos iPhones reales contra producción, y **sin intervención manual en ningún paso**:

| Comprobación | Evidencia |
|---|---|
| `POST /groups/push` ocurre | primera vez en la historia del proyecto; cursor del pull 7 → 13 y los DOS devices convergiendo |
| Un gasto cruza A → B | aparece en el grupo del receptor y su transacción en su Panel |
| Un gasto cruza B → A | el reverso, que NO es simétrico: el que se unió depende de que su `SplitMember` resuelva por `user_id`, y ese camino quedó ejercitado |
| Liquidación | se propaga, y su borrado también |
| Borrados a nivel de grupo | propagan bien en ambas direcciones |
| **Lo llevó el backend, no CloudKit** | `GroupsSync ckEnqueueSkippedBackendGroup site=enqueueSave` en el log del device: el canal viejo vio el guardado y se apartó por ser grupo de backend |

Esa última fila es la que hace concluyente al experimento. Los dos transportes conviven —`SplitSyncManager`
arranca sin gate— y sin esa línea no se podría distinguir cuál movió el gasto.

Los gastos que se habían quedado varados con build 8 **no** se recuperaron, como estaba previsto: el fix
migra el ANCLA del cursor pero no el SUELO (`lastDrainedTxAt`, ya contaminado por el bridge), así que el
re-escaneo arranca por encima de ellos. El owner descartó rescatarlos. Al juzgar un fix de esta familia,
**crear un gasto nuevo**: juzgar con uno varado tiraría un arreglo que funciona.

**Consecuencias para el release, actualizadas:** la **Fase 3 queda DESBLOQUEADA** — la condición que la
frenaba era exactamente esta señal y está cumplida (§1 del runbook, con la tabla completa). Desbloquear no
es «adelante»: la fase borra el transporte CloudKit y sigue siendo irreversible, así que abrir los commits
1 y 2 es una decisión aparte. El **drill del kill-switch** también queda liberado, pero va **al final** de
cualquier tanda de pruebas: bajar el percent apaga en segundos del lado del servidor y los devices tardan
hasta 6 h en enterarse de que volvió a subir (caché de `refreshMinInterval`).

**Dos cosas abiertas, ninguna bloqueante:**

1. **El puente al Panel no se deshace en el que RECIBE un borrado** — el tombstone borra la entidad del
   grupo bien y deja huérfana la `TransactionItem` puenteada; el candado de solo-lectura
   (`splitExpenseID != nil || splitSettlementID != nil`, sin comprobar que resuelva) la deja imposible de
   borrar a mano. Gastos y liquidaciones, en las dos direcciones. **No lo introdujo el Modo Nube**:
   `SplitSyncManager.applyRemoteDeletion` tiene el hueco idéntico y afecta hoy a usuarios en producción por
   CloudKit. Chip `task_736f2831`, con las cuatro instancias y tres piezas (arreglo hacia delante,
   reparación de las huérfanas existentes y quitar el candado cuando el puntero no resuelve).
2. **El emisor en segundo plano no sube nada** hasta que se reabre la app — no hay BGTask ni despertar del
   emisor. Comportamiento correcto de iOS, hueco de producto sin ticket. Costó siete minutos de silencio
   mal interpretados el 2026-08-02: **ante un silencio del canal, descartar el segundo plano ANTES que el
   código.**

**Lo que hizo falta para medirlo, y no era el tail.** El `wrangler tail` no atribuye peticiones a un
dispositivo, así que con dos teléfonos no puede decidir cuál calló. Lo que cerró el caso fue **Console.app
sobre el iPhone conectado, filtrando por `GroupsSync`**: los breadcrumbs de este subsistema son
`logger.notice` **fuera de `#if DEBUG` a propósito**, así que emiten en TestFlight. Su docblock nombra la
firma útil: «un `session-expired` sin su `loopRestarted` posterior = canal muerto que nadie re-arrancó».
Ojo, el comando `log stream --device` **ya no existe** en macOS 26+; hay que usar Console.app.

#### Los DOS defectos que dejó la validación adversarial de `dbda8378`, cerrados el 2026-08-02

Ninguno de los dos es de migración: recuperar los cursores envenenados y los gastos varados lo **descartó el
owner** (población real: sus dos teléfonos, dos gastos de prueba). Estos afectan a usuarios FUTUROS.

**1 · En el teléfono que solo RECIBE, el barrido crecía sin tope en cada vuelta** — `eb353901`

Qué le pasaba al usuario: en el móvil de alguien que solo recibe gastos de un grupo —el caso más común, la
mayoría de los miembros lee más de lo que escribe— cada ciclo de sincronización volvía a repasar TODO lo
acumulado desde el arranque, y ese repaso se encarecía sin techo. No se perdía nada; se gastaba CPU y memoria
en el camino del sync, en silencio.

La causa es una línea que decidía dos cosas a la vez. El drain descartaba el ECO (`tx.author ==
outboxSaveAuthor`) con un `continue` colocado **antes** del avance del high-water. En un device que solo
recibe, las ÚNICAS transacciones de su store de Grupos son las que escribe su propio pull (`applyPulledPage`
persiste los `Split*` bajo ese autor) ⇒ `sawGroupsStoreTx` se encendía —bloqueando el suelo del barrido— y
`advancedToken` se quedaba `nil` —porque el `continue` llegaba antes— ⇒ **ninguna de las tres ramas escribía
el cursor**, jamás.

**La decisión, y es lo que no se ve leyendo:** «es mía, no la re-emitas» y «no es de mi store» son razones
DISTINTAS y estaban confundidas. La primera decide **qué se traduce**; la segunda, **dónde se ancla**. El fix
las separa: el eco sigue sin emitirse nunca, pero sí mueve el ancla si es del store de Grupos.

**Y el bucle que el comentario original daba como motivo para no avanzar («cada avance escribiría el cursor →
loop») ya no existe**, y por eso se pudo tocar: era real cuando el ancla no estaba acotada al store, pero hoy
los únicos writes del propio drain —`GroupSyncOutbox` y `GroupSyncCursor`— viven en `syncMetaSchema` y NO en
`groupsSchema`, así que avanzar no genera ninguna transacción del store de Grupos y la vuelta siguiente no
tiene nada nuevo que anclar. Eso no se dejó como argumento: lo mide
`drain_afterAnchoringOnEcho_idleTurnsWriteNothing`, que cae si alguien quita el guard de store.

Archivos: `Yala/Services/CloudSync/Groups/GroupsSyncClient.swift` (el bucle del drain, `performDrain`) ·
`YalaTests/CloudSync/GroupsDrainHistoryStoreAnchorTests.swift` (+6 tests, §«Device que solo RECIBE», uno de
ellos un contrato MEDIDO de plataforma: un `save()` que toca dos stores produce DOS transacciones, una por
store — que es la premisa de todo lo anterior) · `.claude/rules/swiftdata-cloudkit.md` (la regla durable) ·
`qa/coverage-index.json`. **2 mutaciones, exit 65 las dos**: reponer el `continue` del eco antes del avance
(2 rojos: el ancla y el suelo) y quitar el guard de store (7 rojos, incluido el del drain ocioso — el que
prueba que no hay bucle).

**2 · El test de la purga de History lo decidía el SCHEME** — `e80781a1`

`CloudSyncRuntimeTests › syncCycle_bothFlagsOn_purgesHistoryAfterCompletedCycle` pasaba con `-scheme Yala` y
daba exit 65 con `-scheme "Yala Dev"`, mismo commit y misma máquina. `Yala Dev` define `DEV_BUILD` ⇒ corre el
piggyback de Grupos ⇒ existe el `GroupSyncCursor` con su `lastDrainedTxAt` ⇒ ese valor entra como suelo en
`deleteHistorySafeCut` (que devuelve `floors.min()`) ⇒ la purga no puede bajar a 0.

**El arreglo fue del TEST y la aserción NO se relajó** (sigue siendo `== 0`): lo que cambia es que la
precondición pasa a estar **fijada dentro del test** (`groupsBackendEnabled = false` +
`defer { _testResetGroupsBackendEnabledOverride() }`) en vez de heredada del scheme. Y el caso que el scheme
ejercitaba por accidente —que es **el de producción** con el rollout al 100 %— gana test propio:
`syncCycle_bothFlagsOn_neverPurgesPastTheGroupsFloor` afirma que la purga llega EXACTAMENTE hasta el suelo
(nada por debajo del corte sobrevive, algo se purgó, y queda History por encima). El piggyback se inyecta por
`runtime.groupsSyncCycleRunner` con un `GroupsSyncClient` PROPIO, no el singleton, que arrastraría estado
entre tests y no tiene `_testReset()`.

**2 mutaciones, exit 65 las dos**: quitar la precondición devuelve el rojo ORIGINAL literal —exit 65 con
`Yala Dev`, exit 0 con `Yala`, o sea que reproduce el bug reportado con scheme y todo— y quitar
`groupDrainedBoundary` de `deleteHistorySafeCut` tumba el test nuevo por `after > 0`. Ficha de la Lista Negra
de `TESTING-STRATEGY.md` cerrada.

**Gate**: build ✓ en los dos schemes (solo los 3 warnings de línea base). Suite completa `Yala Dev`
**5380 tests / 502 suites, exit 0, 0 restarts**; `Yala` **5377 / 501, exit 0** saltando la suite de abajo.
`qa/validate-coverage.sh` → `RESULT: OK`. Conteos tomados DESPUÉS del rebase sobre `83051688` (el fix del
des-puenteo), que entró en el remoto mientras esta tanda estaba sin publicar y aporta su propia suite. Los
dos cambios se cruzan en tres ficheros y **ninguno choca de fondo**: `83051688` no toca el drain ni el ancla
(`advancedToken`, `sawGroupsStoreTx`, `outboxSaveAuthor`, `performDrain`, `isGroupsStoreTransaction`: cero
coincidencias) ni añade ningún `save()` fuera de `saveWithAuthor`, así que la premisa de este fix —el pull
escribe los `Split*` bajo el autor del canal— queda intacta. `GroupsSyncClient.swift` auto-mergeó; los
conflictos fueron de la regla y del índice, los dos «ambos añadimos», resueltos conservando las dos partes.

**Un rojo PREEXISTENTE que destapó el gate, y NO es de esta tanda.**
`InitialBalanceServiceMultiCurrencyTests` (3 tests) **crashea el proceso** —`SIGABRT`, no falla una
aserción— bajo `-scheme Yala`. Exonerado por medición: se reproduce idéntico en el árbol LIMPIO desde
`278fd608` con los ficheros del cambio revertidos por `git checkout --`. Frame del crash:
`persistRate(context:)` → SwiftData → `NSManagedObjectContext.performAndWait` → `objc_exception_rethrow`,
o sea una excepción de CoreData dentro del `save()`, de las que el `do/catch` de Swift no atrapa. Dos
hipótesis DESCARTADAS con medición, no con razonamiento: **no es el contenedor sucio del host** (desinstalados
`com.jurgenschmidt.yala` y `.dev`, sigue) y **no es flaky** — es determinista y depende del CONJUNTO: aislada
crashea en los dos schemes, y dentro de la suite completa crashea con `Yala` y **pasa** con `Yala Dev`.
Primera hipótesis a medir: su `ModelContainer` in-memory monta un `Schema` escrito a mano con 9 modelos en
vez de `SwiftDataConfiguration.personalSchema`. Registrado en la Lista Negra como ABIERTA.

### Descartado

- **Todo en un build**: más rápido, pero mezcla las dos clases de fallo.
- **Parar en la Fase 2** (que el plan admite como estado final válido): dejaría Grupos exigiendo iCloud a
  todos los miembros, que es exactamente lo que este épico existe para quitar.

---

## D-R2 · Las dos decisiones de la Fase 3 — DECIDIDAS por el owner el 2026-08-04

Salen del chip A1 (re-medición completa, commit `06926d43`), que las dejó inventariadas **sin veredicto** con
sus direcciones y su coste. El commit 1 de la Fase 3 sigue **CERRADO**; el orden acordado es
A1 mide → A2/A3 deciden → **A4 (vaciado manual, del owner)** → commit 1.

### A2 · Qué evidencia se concede al gate de frescura cuando desaparezca su brazo CloudKit

**DECIDIDO: dirección (iii) — sacar las zonas legacy del conjunto de CANDIDATAS del barredor**, en vez de
pedirle un veredicto a un brazo que se queda sin fuente. Toca `OrphanedBridgedTxSweeper` y **no** el gate puro,
así que el invariante «una sola primitiva para los dos consumidores» (`GroupChannelFreshness.swift:8-12`)
sobrevive y el editor (`NewTransactionView.resolveBridgedPointer`) sigue consumiéndolo.

**Por qué no «fallar cerrado» (dirección i), que parecía la conservadora:** sustituir el brazo por constantes
`false` hace que **`bridgedTxOrphanSweepDeferred` se emita en todos los arranques con candidatas** ⇒ el canario
deja de significar «el gate está frenando algo» y **se pierde la única superficie de observación del
subsistema**. Las dos direcciones dejan las mismas huérfanas legacy sin reparar; (iii) no quema el canario.

**El precio, declarado y no oculto:** las huérfanas de zonas legacy quedan sin reparar **en silencio**, y se
pierde la señal de cuántas hay en la flota. Se acepta porque la dirección que las repararía —(ii), conceder
evidencia— es **la que destruye**: un device recién reinstalado monta el store de Grupos vacío mientras el
espejo personal ya entregó las `TransactionItem`, y esas mutaciones **se exportan a los demás devices**.
La dirección (v) —dar a las zonas legacy un camino al backend— elimina la clase entera de huecos pero es un
épico, no un commit: hoy no hay uploader ni RPC (borrados y revocados el 28/07).

**El dato de flota que esta decisión pedía, consultado el 2026-08-04** en `yala_metrics` (producción; receta y
token en `qa/cloud/README.md` § «Telemetría propia»):

| | |
|---|---|
| `bridgedTxOrphanSweepDeferred` | **0 filas** — el barredor no está frenando ninguna candidata |
| `bridgedTxOrphansRepaired` | **2** — `deleted=3\|drafts=1` (20:43) y `released=1\|deleted=2\|drafts=1` (20:44), un device cada uno |

⚠️ **Esto NO es «medido en la flota», y la distinción es la mitad del valor del dato.** Hay **2 `register` en
todo el histórico** y los ~20 installs distintos son reinstalaciones de los dos teléfonos del owner (`install`
es por INSTALACIÓN). Los dos `repaired` son de la sesión de QA de ese mismo día, limpiando las huérfanas de la
matriz del 02/08. Lo que el dato **sí** aporta: el sweeper **corre de verdad en producción y supera sus dos
gates** —nunca se había comprobado— y en el único parque con historia CloudKit real no queda nada atrapado.
Lo que **no** aporta: nada sobre la flota de 2.1, que no existe todavía. **No reformular como evidencia de
ausencia de daño.**

**Y el punto ciego que hay que conocer antes de volver a leer este canario:** «el gate frenó al barredor» y
«no había candidatas» son **indistinguibles** en Analytics Engine —los dos son silencio— porque `sweep()` está
detrás de dos gates asíncronos y su rastro al rendirse es un `SaveBreadcrumb` (Console.app, no AE), mientras el
canario positivo sale detrás de un `guard !outcome.isEmpty`. ⇒ **en este subsistema solo la señal positiva
decide.** Documentado en `qa/cloud/README.md`.

### A3 · Los apagones S2 / S3b / S4

**DECIDIDO: declarar por escrito la pérdida de S2 y S3b; espejar S4.**

| | Decisión | Por qué |
|---|---|---|
| **S2** `movedToBackendAt` | **declarar la pérdida** | Coste de usuario **cero**: el campo es `nil` en todo el parque y no tiene un solo escritor que lo origine (los dos de `CKRecordTranslator` copian de un CKRecord). La pérdida ya está consumada, así que el freeze del miembro y el CTA «vuelve a entrar» nunca se activaron. Espejarlo sería reconstruir una épica borrada: columna + grant + RPC + ~537 líneas, tocando servidor y base |
| **S3b** `.remoteInsert` | **declarar la pérdida** | Barato de espejar, pero el repo ya midió que **el beneficio es nulo**: el reconciler no arreglaba el caso |
| **S4** «me sacaron del grupo» | **ESPEJAR** | **15–30 líneas, 1 fichero, 0 servidor**, más la cirugía obligatoria de `performRemovedSelfCleanup`. Es **el único de los tres con pérdida de datos real**: grupo fantasma editable hasta el cold boot, y se pierde lo escrito en esa ventana. La señal **ya llega al device** en `page.memberships` (`GroupsSyncClient.swift:2755`) — una escritura, cero lecturas |

**El brief tenía estos dos al revés**, y es la corrección que más cambia el trabajo: marcaba S2 como el
hallazgo caro y no vio que S4 tuviera espejo posible.

**S4 cierra además un bug vivo, y por eso no espera al commit 1.** Es el **B-1** del §10 de la re-medición:
`GroupsSyncClient.swift:2896` y `GroupsSyncBreadcrumb.swift:103` dicen por escrito «la limpieza llega por
memberships del pull» y **lo usan para justificar hacer `skip` sin canario ni remediación** cuando el Merkle
detecta corpus remoto vacío con local no vacío — la firma exacta de una remoción de membresía. Se apoyan en una
implementación que no existe. Misma familia que el `AppAttestClient.ensureRegistered()` de
`.claude/rules/gateway-attest.md`. **Al espejar S4 los dos comentarios pasan a ser verdad; si S4 se hubiera
declarado, habría habido que corregirlos.**

**S6** (`SoftDeleteObserverLogic`) no es de esta familia: es un huérfano total —su único consumidor de
producción es `SplitSyncManager.swift:2643`, que muere con el fichero— y se re-cablea o se borra dentro del
commit 1.

### A4 · El vaciado manual de los grupos legacy — CANCELADO, no diferido

**«No existen grupos en CloudKit legacy útiles en ningún usuario de Yala. Pueden morir sin que nadie los
rescate.»** (owner, 2026-08-04.) El §1 del plan de simplificación queda **cancelado**, y con él **desaparece
la única ventana que ordenaba el trabajo**: el commit 1 de la Fase 3 ya no espera a nada del owner.

**Y la premisa con la que se había justificado era FALSA, lo que importa más que la cancelación.** El punto de
control afirmaba que «lo que no se vacíe queda inalcanzable para siempre tras la Fase 4». Medido: el store de
Grupos monta `cloudKitDatabase: .none` en producción (`Yala/Utils/SwiftDataConfiguration.swift:747`), o sea
que es **local por dispositivo** y CloudKit es puro transporte ⇒ los datos legacy **no desaparecen ni se
vuelven inaccesibles**, siguen en cada teléfono. Lo único que se pierde tras la Fase 3 es la **propagación**
del borrado al otro device, que es exactamente lo que el §1.1 del plan decía y nadie había vuelto a leer. Era
una **inferencia escrita como medición** — el fallo que el punto 7 de `.claude/rules/swiftdata-cloudkit.md`
prohíbe por escrito, cometido en el documento que existe para evitarlo.

**Efecto sobre A2:** el precio declarado de la dirección (iii) —«las huérfanas de zonas legacy quedan sin
reparar en silencio»— **baja a cero**, porque no hay corpus legacy que merezca repararse. La decisión no
cambia; su coste sí, y por eso queda anotado aquí y no solo en el mensaje del commit `d686e661`.

**Residual cosmético declarado:** los grupos legacy que sigan en un teléfono continuarán **visibles** ahí
después de la Fase 3, cada device por su lado y sin sincronizar. No es dañino —nadie los usa— pero tampoco
se van solos, así que puede aparecer en un QA y no debe leerse como un bug nuevo.

### A6 · La reacción al cambio de Apple ID en Grupos — PÉRDIDA DECLARADA (owner, 2026-08-06)

El commit 1 se lleva **tres piezas a la vez**, y ninguna lista del brief las nombra juntas: el **disparador**
reactivo (`CKSyncEngine` entrega `.accountChange` → `handleAccountChange`, 10 referencias **dentro de**
`SplitSyncManager`), la **lógica** (`GroupsIdentityPurgeGate.apply`, cuyo **único** call-site de producción es
`SplitSyncManager.swift:1663`) y la **segunda red** (`GroupsIdentityBootGuardLogic`, también entre los 14).
⇒ tras la Fase 3 el dominio de Grupos **no reacciona a un cambio de Apple ID**.

**DECIDIDO: se declara la pérdida. Cero código.** Se sostiene en tres cosas medidas, no en conveniencia:

1. **Para el canal backend, no reaccionar es lo CORRECTO.** Su identidad es el `sub` de la cuenta Yala, así
   que un cambio de Apple ID del OS es un **no-evento** para esas filas y borrarlas sería pérdida
   permanente — es literalmente lo que la excepción C-3 de `.claude/rules/swiftdata-cloudkit.md` existe para
   impedir. La rama que se pierde ahí (`retainRevokingRejoinCredentials`) protegía un caso que el canal nuevo
   no plantea del mismo modo.
2. **El contenido que la otra rama borraba es basura**, desde que el §1 del plan quedó cancelado: no hay
   grupos CloudKit legacy útiles en ningún usuario.
3. **El relevo de humano sigue cubierto.** El camino principal es el «empiezo de cero» del Welcome
   (`DataWipeService.wipeLocalGroupsDomain`), que es de **INTENCIÓN** y no pasa por `SplitSyncManager` ⇒
   **sobrevive al commit 1**.

**Residuo declarado, para que nadie lo redescubra como bug:** un humano nuevo que herede el device **sin**
pasar por el «empiezo de cero» puede ver **cascarones de grupos legacy** del anterior (nombres, sin datos
útiles). No hay pérdida de dinero ni acceso a datos financieros vivos. Si algún día eso importa, la pieza a
reponer es solo la revocación de credenciales, cableada a un disparador que sobreviva —el boot, no
CKSyncEngine—, **no la purga entera**.

**Y G3 se cierra con esto:** `GroupsIdentityPurgeIntent` perdía armador y drenador a la vez (sus cuatro
call-sites funcionales viven en `SplitSyncManager`). Al declarar la pérdida, el intent **se retira con ellos**
en vez de quedarse como una intención que nadie arma ni drena — que es el patrón de `quotaFailedRecordIDs` y
es peor que no tenerlo.

Los chips (**A3-S4** y **A2-impl**, ambos ✅ HECHOS) están en
`$VAULT/Backlog/modo-nube/MODO-NUBE-CHIPS-FASE3.md`.
