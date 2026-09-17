# Sync personal: renovación sin red / 401 Attest ≠ sesión caducada

## Contexto
Ticket: `tickets/backlog/personal-sync-reads-an-offline-token-refresh-as-a-session-expiry.md` (medium, agujero caro 2.1).
Hermano de grupos ya separado (2026-09-15). En `.cloud`, `CloudAuthService.accessToken()` → nil se lee como sesión caducada en push/pull/prefs/migración/etc., para el loop y frena grupos. También 401 `yala_attest_required` mapeado a sessionExpired.

Must-fix nube sin callejones: sin esto el aviso Attest personal (#177) a menudo no puede salir y la gente ve «vuelve a iniciar sesión» por un blip de red.

## NOCHE (21:00–6:00 Lima)
Elige lo recomendado **sin** AskUserQuestion. Si es demasiado gordo, aparca y avisa a Frank.
Recomendado: criterio del canal de Grupos (`sessionStillOnDevice` / equivalente): con sesión guardada → pasajero; sin ella → caducada. En migraciones/borrados: medir cada call site; si un pasajero reintenta mal, ticket aparte o aparca ese sitio — no inventes producto.

## Que se pide
1. Dejar de tratar nil-por-red / attest-required como sessionExpired donde el patrón de grupos ya aplica.
2. Tests según el repo.
3. Gate, commit, tickets + docs/TICKETS.md, PR, merge 2.1, `/cerrar-total`. Bugs → ticket. No Kanban.

## MODO AUTÓNOMO HASTA TERMINAR
Gate/commit/board/merge/cerrar-total sin preguntar. Noche: aparca si decisión demasiado importante. UI CI advisory.

## Que NO
marketing/; no reopen #177 salvo patrón.

## Como se sabe que esta bien
Sin red + token caducable renovable: no «sesión caducada» ni stopUntilSignIn permanente. Attest 401: pasajero como grupos. Board + cerrar-total.

## Avisos Frank
Webhook Mini local: (1) decisión/acceso; (2) PR; (3) cerrar-total + resumen; (4) idle una vez. NO: test rojo a reclasificar, build retry, CI advisory.

## Paso 0 — decisiones

> Resueltas en autónomo (sesión nocturna, 21:36 Lima): las recomendaciones se dan por buenas. Se discuten en el PR.
> Hechos medidos en `a0e362b57` (el inventario por sitio, con coordenadas, va al ticket).

**D1 · Token nulo en el push, el pull y las preferencias del canal personal** → pasajero (`.transient`) si el SDK conserva
la sesión (`canRenewSession`); caducada solo si la borró. El canario `cloudSyncBlockedByExpiredSession` solo sale en el
segundo caso.
Por qué: es el criterio del canal de Grupos desde el 2026-09-15, y el SDK ya separa los dos casos. Alternativa
descartada: `hasSession`, que lleva el seam `-uitest-fake-cloud-session`.

**D2 · Cómo llega `canRenewSession` a los tres clientes** → parámetro `canRenewSession: @MainActor () -> Bool` con
default `{ false }` (el trato de hoy); las cinco construcciones de producción lo pasan desde su proveedor de sesión, y un
source-scan con conteo lo fija (molde `AttestWiringTests`).
Por qué: el default de hoy deja intactas las 53 construcciones de la suite (medido por la review); el scan impide que producción lo herede.
Alternativas descartadas: default al singleton (un simulador con sesión guardada vuelve pasajero el token nulo y los
tests del loop cuelgan, trampa (2) de `swiftdata-cloudkit.md`) y parámetro obligatorio (53 construcciones de test
tocadas sin ganar nada que el scan no dé).

**D3 · 401 `yala_attest_required` en esos tres clientes** — *ESTRECHADA tras la review: no suma a la racha (ver «Revisión»)* → `.transient`, con rastro `CloudSync attestRequired edge=…` y
un rechazo en la racha del teléfono. Los demás 401 siguen siendo sesión caducada.
Por qué: decisión de Jürgen para Grupos (2026-09-15), y el encargo lo pide igual aquí.

**D4 · Qué borra la racha desde el canal personal** — *RETIRADA tras la review (ver «Revisión»)* → el 200 de `/sync/push`, `/sync/pull` y `/prefs/*`, y ya no el
token conseguido en `CloudSyncRuntime.resolveAttest`.
Por qué: con el acierto en el token, un token de la caché que el gateway rechaza borra la racha en cada ciclo antes del
401, y el aviso fijo del #177 no puede salir nunca (la consecuencia anotada en el ticket). Molde Grupos: cuenta la
palabra del servidor. Coste aceptado: un teléfono que recupera el attest con el backend caído conserva el aviso hasta el
primer 200. Alternativa descartada: acierto con un token RECIÉN acuñado y no con uno de caché (pide cambiar la API de
`AppAttestClient`, compartida con la IA y los tipos de cambio).

**D5 · Testigo del ciclo para ese 401** — *RETIRADA tras la review (ver «Revisión»)* → cada cliente cuenta sus 401 `yala_attest_required`; el runtime fotografía la
suma al empezar el ciclo y `stoppedByUnavailableAttest(for:)` la compara.
Por qué: sin testigo, con la racha terminal el Panel diría «este teléfono no puede sincronizar» y el cierre de sesión
«revisa tu conexión». Alternativas descartadas: un caso nuevo en `PushOutcome`/`PullOutcome` (arrastra `PullApplyOutcome`
y comparaciones con `==` que el compilador no ve), un flag por llamada (se queda viejo cuando el pull no corre, `.busy`)
y un callback (cableado escondido en el init).

**D6 · Migración: los 8 guards de `MigrationWorkExecutor`, el snapshot, `verify` y la reversa** → sin cambio.
Por qué: medido, `.sessionExpired` y `.transient` colapsan en la misma parada retomable (o en el `.networkTimeout` de
`verify`) en todos, así que D1 no altera nada ahí. El único que distingue es el claim del adopt del Welcome, y lo que
enseña con el token nulo («No pudimos verificar tu cuenta. Revisa tu conexión…» + «Reintentar») ya es honesto.

**D7 · Alta en la nube (`BornCloudSignUpService.signUp`)** → token nulo con la sesión guardada = `.transient`.
Por qué: es el caso que nombra el ticket y los dos consumidores ya tienen el camino pasajero con su copy: «Activar Yala
completo» pasa de «Tu sesión caducó» (solo «Cerrar») a «No pudimos activar tu cuenta · Revisa tu conexión…» con
«Reintentar», y el Welcome deja de cerrar la sesión.

**D8 · Borrado de cuenta, revocación SIWA, entitlement, tipo de cuenta, descubrimiento de identidad y la sesión usable
de «Migrar a la nube»** → sin cambio de comportamiento.
Por qué: ninguno enseña «sesión caducada» ni para nada por el token nulo; tratan igual los dos casos o devuelven la caché,
`false` o `.unavailable(retryable: true)`. Solo se corrige el docblock de `failNoUsableSession`, que da por hecho que el
SDK ya limpió la sesión.

**D9 · `SyncMerkleClient`** → sin cambio: su `.sessionExpired` acaba en `.skipped` y no para nada.

**D10 · Docblocks que dan el attest ausente por una sesión muerta** (`CloudAccountClient` `:13-14` y `:55`,
`SyncPullClient` `:61`, `PushOutcome`) → se corrigen.

**D11 · «Todo sincronizado» con cambios sin subir mientras no hay red** → ticket aparte.
Por qué: con D1 esta población deja de ver «Inicia sesión para subir N cambios» (falso: sin red tampoco puede entrar) y
pasa al check verde que ya ve hoy quien está sin red con el token vigente. Decir «sin conexión» es copy nuevo: producto.

**D12 · Un 401 `yala_attest_invalid` en el canal personal no reintenta con el refresh forzado** (Grupos sí, H-2026-07-18-4)
→ ticket aparte si no existe. No es de este ticket: aquí el JWT llega y el servidor lo rechaza.

**D13 · Verificación** → unit en las dos direcciones por sitio que cambia, mutantes, review adversarial (toca sync) y
guion de device-QA en el ticket para Jürgen. El 401 del attest no se puede provocar en staging (`observe`): lo cubren
los unit y los mutantes. El ticket queda en `qa`.

### Revisión tras la review adversarial (cuatro lentes, 2026-09-16)

> Resuelta en autónomo. Tres lentes llegaron por separado al mismo fallo de D3-D5, y la medición lo confirma.

**D3 se estrecha, y D4 y D5 se retiran.** El 401 `yala_attest_required` sigue siendo `.transient` con su rastro, pero **no
suma a la racha del teléfono**, la puerta vuelve a tomar el token conseguido como acierto y el testigo del cierre vuelve a
ser solo la puerta.
Por qué: en el canal personal `CloudSyncRuntime.resolveAttest` corre ANTES de subir y filtra los fallos de App Attest del
teléfono. Una petición que llega al gateway lleva un token que el teléfono acuñó bien, así que su 401 dice «el servidor
rechaza un token bueno»: reloj atrasado, una regresión de build que no manda la cabecera o el servidor. En Grupos no hay
puerta y el 401 mezcla las dos causas; aquí no. Contarlo en la racha del TELÉFONO daba tres falsos positivos medidos:
(1) con el reloj atrasado 24 h y el proceso vivo, la puerta ya no borraba la racha que Grupos suma tras su refresh forzado,
y el cierre en la nube ofrecía «Cerrar sesión y perderlos» a un teléfono que sí atesta; (2) una regresión de build de
`/sync/*` acababa, a las 24 h, diciendo a todo el parque «usa otro teléfono» y ofreciendo perder lo personal que el hotfix
subiría; (3) una subida que falla por otra cosa dejaba el aviso puesto para siempre.

**D14 · Canario `cloudSyncAttestRequired`** (una vez por proceso y ruta). Por qué: sin él, esa regresión de build no la
cuenta nada; antes salía, mal etiquetada, en `cloudSyncBlockedByExpiredSession`.

**D15 · El aviso fijo a quien el gateway rechaza un token bueno** → ticket aparte para Jürgen. Por qué: el aviso dice «este
teléfono no puede sincronizar» y abre la salida con pérdida, y para esta población no es el teléfono. Cambiar cuándo sale
es tocar el #177 y es producto.

**D16 · Test del gateway para la guard de `/sync/*` y `/prefs/*`** (`gateway/test/sync.attest401.test.ts`, molde
`groups.attest401.test.ts`). Por qué: desde hoy el cliente personal depende de que esa guard separe los dos 401, y ningún
test lo fijaba.

**D11 se amplía:** «Todo sincronizado» con cambios sin subir también le sale a quien el gateway le rechaza el attest con la
red bien, y ahí no se cura al volver la red.

**Aceptado a sabiendas (como en Grupos):** una sesión que el SDK conserva pero el servidor rechaza sin borrarla
(`user_banned`) se lee pasajera: la activación ofrece «Reintentar» y el Welcome no suelta la sesión. Población ~0.
