# Tu segundo iPhone no puede activar la nube hasta recibir la señal del primero, y el aviso dice que la cuenta tiene datos ajenos

**Prioridad:** high
**Ticket:** tickets/backlog/settings-migrate-blocks-a-second-device-before-its-marker.md

## Objetivo

Quien tiene dos iPhone con el mismo iCloud y activa la nube en uno ya no lee en el otro «Esa cuenta ya tiene finanzas
personales», que es falso. El otro iPhone le dice qué pasa de verdad: otro de sus dispositivos está llevando los datos a
la nube. También le dice qué hacer: esperar a que termine o reintentar en ese dispositivo. La misma salida queda nombrada
cuando el primer iPhone se paró a medias o reinstaló Yala. Una cuenta con finanzas de otra persona sigue sin poder recibir
la migración.

**Decidido por Jürgen (2026-10-08 16:20): opción A.** Exponer `migration_in_progress` en `/account/exists` y, con el faro de esta cuenta, decir «Otro de tus dispositivos está llevando tus datos a la nube: termina o reintenta allí» en vez de «ya tiene finanzas personales». Copy nuevo en los 16 locales, español neutro latinoamericano.

**Orden:** esta va PRIMERO. `gk5w` (`reverse-exit-on-a-reverted-account-rejects-the-retry`) toca también el backend de la cuenta y se lanza después, rebasando sobre esta.

## Ficheros implicados

- `Yala/App/Logic/StorageMigrationIdentityGateLogic.swift:134` `check`: hoy convierte `.blockedAccountIsComplete` en
  `.blocked(.accountHasPersonalData)`. Haría falta un motivo nuevo, «migración en curso en otro dispositivo», distinto del
  de datos ajenos.
- `gateway/src/sync/account.ts` (`/account/exists`): exponer `migration_in_progress`. Cliente:
  `Yala/Services/CloudSync/CloudAccountClient.swift:274` `exists(jwt:)`.
- `Yala/Services/CloudSync/CloudBeacon.swift:99` `isCloudAccountLinked`: confirma que la cuenta es de este Apple ID.
- `Yala/App/Views/Settings/StorageSettingsView.swift`: el aviso y la nota de rechazo que recuerda `edc92f5af`
  (`storage.migrate.refused*`). Copy nuevo en los 16 locales.
- `Yala/App/UITestHooks.swift:165-184`: el seam de uitest de los motivos de bloqueo.

## Criterio de hecho

- Tests de lógica pura de `check` para estos casos: cuenta `complete` + migración en curso + faro de esta cuenta ⇒ motivo
  nuevo; cuenta `complete` sin migración en curso ⇒ `accountHasPersonalData` (la mitad que no se puede perder). Mutante
  verificado en las dos direcciones.
- Golden del gateway para el campo nuevo de `/account/exists`.
- XCUITest de Ajustes con el seam de uitest que pinta el aviso nuevo; `LocalizationParityTests` en verde.
- Device-QA con dos iPhone y el mismo iCloud: activar en el primero y, antes de que llegue la marca, tocar «Activar la nube»
  en el segundo ⇒ aviso verdadero con su salida.

## Deploy de backend: AUTORIZADO por Jürgen (2026-10-09 14:01)

Jürgen autorizó el deploy de backend de esta card. Se hace con la mejor práctica, en este orden, y sin saltarse pasos:

1. **Compatibilidad hacia atrás, obligatoria.** La app que ya está instalada (TestFlight y builds anteriores) tiene que seguir funcionando igual con el backend nuevo: solo cambios aditivos (campos nuevos opcionales, funciones que conservan la firma y los códigos de respuesta que la app vieja ya entiende). Fíjalo con un test o golden que use la respuesta tal como la lee la app vieja.
2. **Staging primero.** Migración SQL en el proyecto de Supabase de staging (`fostjbbwstyuunmmefuk`) con el camino del repo (`docs/RUNBOOK-staging-ddl.md`: `apply_migration` del conector de Supabase, o `psql -1 -f qa/cloud/<fichero>.sql "$SUPABASE_DB_URL"`), con su guarda de cuerpo previo (`md5(pg_get_functiondef(...))`) y su rollback escrito al lado. Si cambia el Worker: `cd gateway && npm run deploy:staging`.
3. **Verificación en staging.** La verificación SQL de conducta y los goldens del gateway contra staging, en verde; anota versión del Worker y `md5` de las funciones antes y después.
4. **Producción después.** La misma migración en producción (`kefvaiymtgytemwbltlz`) con la misma guarda, y si aplica `cd gateway && npm run migrate:production` / `npm run deploy:production`. Luego una **prueba de humo** en producción (la llamada mínima que demuestra el cambio y otra que demuestra que el camino viejo sigue igual), sin tocar datos de usuarios reales.
5. Deja el antes → después (md5, versión del Worker, resultado de la prueba de humo) en el ticket y en el `RUNBOOK` que corresponda, y en el PR.

**Si el deploy pide un secreto, una credencial o un login que la sesión no tiene** (Cloudflare, Supabase, Llavero), **para ahí**: no lo busques por otro camino, no pidas que lo peguen. Deja todo listo hasta ese paso y anótalo en «Necesita de ti» del cierre, con el comando exacto que falta correr. Si la sesión crea una clave nueva en el Llavero, dilo en el cierre para pasarla a 1Password.

En esta card el backend es el Worker del gateway (`gateway/src/sync/account.ts`, `/account/exists`): el campo `migration_in_progress` es nuevo y opcional, así que la app vieja lo ignora. Golden nuevo en `gateway/test/account.goldens.test.ts`.

## Ejecución
- `/cerrar-total` autónomo al terminar (PR a 2.1 con auto-merge, card bien puesta: in qa → jurgen si queda device-QA, done → frank si no; quitar worktree/tmux/DerivedData/cachés de XcodeBuildMCP de este worktree; ningún sim encendido).
- Pipeline serial de la Mini: limpiar sims muertos/DerivedData de sesiones cerradas/cachés de XcodeBuildMCP de worktrees que ya no existen sin preguntar; `xcodebuild -jobs 2` sin sim booteado; boot de 1 solo sim (si hay otro simulador o `xcodebuild` ajeno, no lo toques y espera); tests; apagar y borrar ese sim.
- Rebase al final, sin esperar a nadie: justo antes de abrir su PR, `git fetch` y rebase sobre `origin/2.1`, resolviendo ahí cualquier conflicto (el ruleset de `2.1` tiene strict=false). Si el rebase trajo cambios que tocan lo suyo, vuelve a compilar y a correr los tests afectados.

## Cierre: tickets nuevos al tablero
Tickets nuevos al tablero (antes del `/cerrar-total`): por cada ticket nuevo que abra esta sesión en `tickets/`, mira primero con `tablero listar --proyecto Yala --todas` que no tenga ya card y, si no la tiene, créala: `tablero crear --proyecto Yala --agente frank --asignado frank --estado backlog --prioridad <la del ticket> --titulo "<título claro en español neutro>" --contexto "<una línea>" --enlace "Ticket|https://github.com/jur211296/Yala/blob/2.1/tickets/backlog/<slug>.md" --enlace "PR #<N>|<url del PR>"`. Lista esas cards (título e id) en el aviso de cierre. Va SIN --fecha (la fecha de las cards es opcional desde el ADR-068; no pongas fecha de relleno).

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**Hechos medidos antes de decidir (árbol `encargo/…`, 2026-10-09).**
- `profiles` tiene los grants a nivel TABLA (`authenticated=arwDxtm`, `qa/cloud/g15_01_account_kind.sql:25-28`): el `SELECT`
  de `migration_in_progress` con el JWT del usuario ya está permitido. **No hace falta SQL**: el cambio de backend es solo
  el Worker (`handleAccountExists`).
- El cliente decodifica `/account/exists` con `Decodable` sin claves estrictas (`CloudAccountClient.ExistsResponse`): un campo
  nuevo lo ignora la app ya instalada.
- Los goldens 28-30 del bloque g15_01 comparan `exists` con `toEqual` exacto: un campo nuevo los rompe y se actualizan.
- `migration_in_progress = true` solo lo arma un claim con `migration` (la ida); el alta born-cloud lo deja en `false`. El faro
  (`CloudBeacon`) guarda el hash del `sub` de la cuenta que reclamó este Apple ID.
- **La salida «reintenta allí» no existe tras reinstalar en el mismo iPhone**: el sello `.proceedMigration` y la marca del claim
  sin respuesta viven en `UserDefaults` y se van con la app, y el `device_id` cambia. La puerta vuelve a parar.

**D1 · ¿Qué condición enciende el aviso nuevo?** → cuenta `complete` que este dispositivo no reclamó **y** `migration_in_progress`
**y** el faro nombra esta cuenta (`isCloudAccountLinked` + `accountHash == hash(sub)`).
Por qué: es la opción A tal cual. Sin el faro, la cuenta en curso puede ser de otra persona, y «otro de tus dispositivos» sería
falso. Alternativa descartada: solo `migration_in_progress`, que diría «tus dispositivos» a quien entró con la cuenta de otro.

**D2 · ¿Dónde decide?** → en `StorageMigrationIdentityGateLogic.check`, pura, con dos parámetros nuevos sin default
(`accountMigrationInProgress`, `beaconNamesThisAccount`). Solo cambia el motivo del bloqueo: sigue siendo `.blocked`.
Por qué: la mitad que no se puede perder («cuenta ajena no recibe la migración») queda cierta por construcción.
Alternativa descartada: decidir en el controller, que no se puede probar sin red.

**D3 · ¿También el claim que contesta `claiming_in_progress`?** → sí, con la misma condición de faro
(`blockForClaimRefusal(…, beaconNamesThisAccount:)`). El faro se lee ANTES de cerrar la sesión que abrió el intento.
Por qué: `claiming_in_progress` ES «otro dispositivo está migrando esta cuenta»; dejarle el texto falso dejaría el mismo bug por
la segunda capa (el D18 del ticket). Alternativa descartada: solo la comprobación previa, que deja la mentira a quien pasa la
comprobación antes de que el primero reclame.

**D4 · ¿Cómo viaja el dato?** → `ExistsOutcome.exists(_, kind:, migrationInProgress:)`, `ExistsRoute.accountFound(kind:,
migrationInProgress:)` y `CloudIdentityDiscovery.Outcome.discovered(_, userID:, migrationInProgress:)`, con default `false` en los
tres. Ausente en la respuesta = `false`, que cae al aviso de siempre (sigue bloqueando).
Por qué: un gateway sin desplegar no cambia nada; el default evita tocar ~20 construcciones de tests.

**D5 · Forma del campo en el gateway** → `migration_in_progress: true|false` solo cuando la fila existe y el valor es booleano;
fuera del dominio, se omite (molde de `kind`).
Por qué: el cliente lee la ausencia como `false` y no hay valor desconocido que cachear.

**D6 · Copy** → texto de Jürgen como título; cuerpo y nota de la tarjeta con su salida, en los 16 locales:
- `storage.migrateBlock.otherDeviceTitle`: «Otro de tus dispositivos está llevando tus datos a la nube»
- `storage.migrateBlock.otherDeviceBody`: «No cambiamos nada. Termina la activación en ese dispositivo o, si se detuvo,
  reinténtala allí. Cuando termine, podrás activar la nube aquí.»
- `storage.migrate.refusedOtherDevice`: «Otro de tus dispositivos está llevando tus datos a esta cuenta. Termina la activación
  allí o, si se detuvo, reinténtala en ese dispositivo.»
Por qué: no promete que se active solo (falso con un líder parado) y nombra las dos salidas. «Cuando termine, podrás…» es
verdad: al llegar la marca la tarjeta pasa sola a «Activar en este dispositivo». Alternativa descartada: «aquí se activará
cuando termine», que el ticket ya descartó.

**D7 · El caso de la reinstalación** → se queda con este mismo aviso y su residual va a un ticket nuevo.
Por qué: Jürgen decidió A, y A no abre ninguna salida nueva. Para ese caso el aviso nombra una salida que no existe
(«otro dispositivo», «reintenta allí»), y la salida real pide una decisión suya: un sello que sobreviva a reinstalar, o soltar el
lease. Alternativa descartada: inventar aquí un relevo o un sello en el Llavero (decisión de producto, fuera de A).

**D8 · Slug del canario** → `other_device_migrating`; el caso nuevo va al final de `Block` (el orden de `allCases` importa).

**D9 · Deploy** → sin SQL. Worker: tests offline + goldens contra staging con el código local → `deploy:staging` → goldens otra vez
→ `deploy:production` → humo en producción sin datos de usuarios (401 sin JWT en `/account/exists` y versión desplegada). Una
prueba de humo con JWT de producción pediría una cuenta real de producción: no se toca.
Por qué: el encargo pide no tocar datos reales; el comportamiento del campo ya lo prueban los goldens contra staging, con el
mismo código que se despliega.

**D10 · Review adversarial** → sí, corta (dos lentes): toca la puerta de la migración.

**D11 · Device-QA** → el ticket va a `qa` con guion para dos iPhone; la card a Jürgen.
