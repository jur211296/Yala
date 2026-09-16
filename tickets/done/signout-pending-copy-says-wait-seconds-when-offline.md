---
id: signout-pending-copy-says-wait-seconds-when-offline
status: done
priority: low
area: "sesión, copy"
created: 2026-09-15
updated: 2026-09-16
source: "decisión de Jürgen en `groups-push-reads-an-offline-token-refresh-as-a-session-expiry` (2026-09-15): mismo texto en los tres avisos, y lo impreciso a un ticket aparte"
---

# Sin conexión, el aviso de cierre dice «espera unos segundos»

## El problema, en lenguaje de usuario

Tengo cambios de grupos sin subir, estoy sin conexión y toco «Cerrar sesión». Unos 45 segundos después Yala me dice
«Un momento más · Todavía estamos terminando de guardar unos cambios. Espera unos segundos y vuelve a intentarlo.»
Espero, lo intento otra vez y pasa lo mismo: no se está guardando nada, lo que falta es la red.

## Lo medido

- El texto sale para `BlockReason.transient` en Ajustes y en la hoja del cambio de Apple ID (`SignOutBlockedCopy`) y,
  desde el 2026-09-15, también en la puerta de Grupos del Welcome (`WelcomeGroupsGateView`).
- `.transient` junta dos causas que `CadenceOutcome` no separa: el guardado que aún se asienta, que es para lo que se
  escribió «un momento más» (H-2026-07-18-6), y la subida que falla por red, un 5xx o un cortafuegos.
- La nube ya tiene el texto cierto para la segunda causa: «Los últimos cambios de tus grupos no llegaron al servidor…»
  (`.uploadRetryLater`, 2026-09-14).
- **La espera también dice lo que no pasa.** Durante los ~45 s de reintentos (`GroupsSignOutRetryDecision.budgetSeconds`)
  se lee «Guardando tus cambios pendientes…» en Ajustes, en la hoja del cambio de Apple ID y en el desasociar
  (`settings.signOutWorking`, `storage.groups.detachWaiting`), y «Estamos subiendo tus últimos cambios a iCloud…» en
  la puerta del Welcome (`welcome.groups.neutralWorking`). Sin red no se guarda ni se sube nada, y volver a intentarlo
  cuesta otros 45 s.
- El desasociar termina en «Quedan cambios de tus grupos sin subir. Inténtalo de nuevo en un momento.»
  (`storage.groups.detachBlockedTransient`): la misma imprecisión.
- Sin red y con la sesión vigente, esto ya pasaba antes del 2026-09-15. Ese día se sumó quien tiene el token caducado,
  que hasta entonces veía «Tu sesión caducó».
- **Y quien tiene la red y la sesión bien pero no consigue App Attest**, también desde el 2026-09-15
  (`groups-sync-reads-a-missing-attest-401-as-a-session-expiry`). A esa persona un texto que culpe a la conexión
  tampoco le diría la verdad: su red funciona. Y si el attest no vuelve, sus 45 s de reintentos son unas 23 subidas
  con un 401 seguro; antes el aviso salía al momento. Para quien no lo recupera nunca, tampoco son ciertos el texto
  de la nube ni la opción 2 de abajo: `groups-phone-that-never-attests-is-told-to-retry-forever`.

## Lo que hay que decidir (Jürgen)

1. Separar las dos causas en el canal, con un motivo propio para la subida fallida y un texto para cada una.
2. Usar «no llegaron al servidor… inténtalo de nuevo en un rato» para todo `.transient`, sabiendo que también lo verá
   quien solo esperaba a que terminara un guardado.
3. Dejarlo como está.

## Decisión Jürgen (2026-09-15)

**Separar las dos causas** (opción 1): un motivo/texto para «aún se asienta» y otro para «falló la subida» (sin red / 5xx / cortafuegos). No unificar todo con el texto de nube, y no dejarlo como está.

## Paso 0 · el árbol de decisiones, resuelto (2026-09-16, sin Jürgen delante)

**Lo primero es que la premisa de «Lo medido» se queda corta, y eso abarata el arreglo.** El ticket dice que
`CadenceOutcome` no separa las dos causas. Medido en el árbol de hoy, sí las separa — lo que pasa es que
`classify` tira la distinción:

| De dónde sale el `BlockReason.transient` de hoy | Qué es de verdad |
|---|---|
| `classify(.transient, …)` (`CloudSignOutFlowLogic.swift:411`) | el ciclo FALLÓ: red, 5xx, decode, el 403 de un cortafuegos |
| `classify(.completed/.coalesced, …)` (`:412`) | el ciclo fue BIEN y quedan filas: el tope de iteraciones, aún drenando |
| el timeout de quiescencia (`CloudSessionSignOut.swift:1216`) | el import de CloudKit aún no se asienta — el caso original H-2026-07-18-6 |
| la cancelación del caller (`:1189`, `:1366`) | ni una cosa ni la otra: reintentable |

Las tres últimas filas son asentamiento y **ninguna pasa por la primera**. O sea que la señal ya está en la
mano y se estaba tirando en una sola línea.

**D1 · motivo nuevo o reuso.** Reuso de `.uploadRetryLater`. Su texto ya dice exactamente lo que hay que
decir —«no llegaron al servidor, siguen guardados en este teléfono y no se pierden, inténtalo en un rato»—,
está en los 16 locales y ya tiene rama en Ajustes y en la hoja del cambio de Apple ID. Un case nuevo con el
mismo texto son dos copias que divergen en cuanto una aprenda algo.

**D2 · dónde nace la separación.** En `classify`: `.transient` del ciclo pasa a `.uploadRetryLater` y
`.completed`/`.coalesced` se quedan en `.transient`. Una palabra.

**D3 · testigo nuevo en el canal, del molde de `stoppedByChannelKill`. SÍ — y esta decisión se tomó dos
veces.** La primera respuesta fue «no»: dentro de `CadenceOutcome.transient` parecían quedar solo fallos
LOCALES patológicos (el fetch del outbox, el `buildDelta`, el cursor), el texto no mentía peligrosamente en
ellos, y el precio era tocar el canal de sync, que es donde un bug sale caro.

**La review adversarial la refutó con dos mediciones, y las dos eran ciertas:**

1. **El veredicto del ciclo es el del PULL siempre que el push vaya bien.** `GroupsSyncClient.syncCycleOnce`
   corta con `stopOutcome(push:)` solo si el push PARA; si no, devuelve `GroupsSyncCadence.outcome(pull:)`.
   Así que con la subida perfecta y el pull caído, el aviso decía «tus cambios de grupos no llegaron al
   servidor» — falso.
2. **Uno de esos «locales patológicos» es el caso original del ticket H-2026-07-18-6.**
   `pullUntilExhausted`, `guard saved else { return .transient }`: el `save()` local de una página que no
   entra. Es literalmente el «write interno que aún se asienta» para el que se escribieron los 45 s de
   reintentos, y mi mapeo se los quitaba **y** le cambiaba el texto por uno falso.

⇒ `GroupsSyncClient.lastCycleFailedUpload` + `stoppedByFailedUpload(for:)`, molde exacto de sus dos hermanos:
se baja al entrar en `syncCycleOnce` y **lo enciende el push y solo el push** (9 puntos: la petición que
lanzó, la respuesta no-HTTP, el 5xx y el resto de códigos, el 403 del cortafuegos, el 409 que no es la
reversa, el decode de la respuesta, el 401 del attest, y las dos veces que el token no se pudo renovar con la
sesión todavía guardada). La marca es POSITIVA: **marcar de menos deja el aviso conservador de siempre**, que
es el comportamiento anterior al ticket; marcar de más acusa al servidor de algo que pasó aquí dentro.

**D4 · los 45 s de reintentos ante un fallo de subida: se van, y es la mitad del arreglo.**
`GroupsSignOutRetryDecision.decide` ya manda `.uploadRetryLater` a `.surfacePermanent`, así que el aviso sale
al momento. Es la misma decisión que Jürgen tomó el 2026-09-13 para `.channelPaused` y el 2026-09-14 para
`.uploadRetryLater` en la nube, con el mismo razonamiento escrito («gasta ~22 peticiones y retrasa 45 s un
aviso que ya se puede dar»), y es lo único que quita el «Guardando tus cambios pendientes…» de los 45 s sin
red — que es el criterio de aceptación del encargo. Lo que se asienta sigue reintentando: ahí los 45 s son
justo lo que hace que el gesto termine solo.

**D5 · qué enseña el cierre en la NUBE para el asentamiento.** `.transient`, invirtiendo el mapeo de
`cloudSignOutGroupsBlockReason`. Hoy manda `.transient` a `.uploadRetryLater` porque `.transient` era el
cajón de todo; separadas las causas, «espera unos segundos y vuelve a intentarlo» es cierto también sin
retry interno: lo que cura un outbox que drena es esperar y volver a pulsar.

**D6 · el texto de `.transient` no se toca.** «Todavía estamos terminando de guardar unos cambios. Espera
unos segundos y vuelve a intentarlo» es exacto para lo único que le queda.

**D7 · keys de l10n nuevas: cero.**

**D8 · el caption de progreso no se toca.** Con D4 ya no se ve 45 s sin red. Lo que queda debajo es la
quiescencia y el primer push, que es asentamiento de verdad.

**D9 · el camino PERSONAL queda fuera.** El paso 1 del cierre en la nube colapsa todo a `.permanent` salvo
el attest y tiene ticket propio (`cloud-signout-collapses-the-personal-push-all-reason-into-permanent`). Se
comprueba que este cambio no lo altera: `.uploadRetryLater` cae en el mismo `guard reason == .attestUnavailable`
por el que ya pasaba `.transient`.

### El inventario del canal, y por qué su conclusión NO bastaba (2026-09-16)

Se barrieron los dos ficheros enteros y se clasificó cada productor de lo pasajero. El reparto es correcto y
está aquí porque el testigo se apoya en él:

| Familia | Dónde | Enciende el testigo |
|---|---|---|
| La petición del push que no volvió, la respuesta no-HTTP, el 5xx, el 403 del cortafuegos, el 409 que no es la reversa, el decode, el 401 del attest, el token no renovable con la sesión guardada | `GroupsSyncClient` push (9 puntos) | **sí** |
| El `fetch` del outbox, `buildDelta` de una fila poison, el teardown que invalida un 200 que sí llegó | push | no: son de este teléfono |
| El `save()` local de una página, el tope de 20 páginas, el cursor que no carga, la URL que sale `nil`, el 5xx del pull | todo el pull | no: no se estaba subiendo |

**La conclusión que saqué del inventario fue la equivocada, y es la lección del día.** Lo leí como «los
locales son patológicos, así que da igual» y me quedé ahí. Lo que no miré es **quién produce el outcome del
ciclo**: con el push bien, es el pull. O sea que la pregunta no era «¿cuánto pesan los locales?» sino «¿qué
está midiendo el outcome que estoy clasificando?» — y la respuesta era «otra cosa». Un conteo de familias no
sustituye a recorrer el camino por el que viaja el dato.

## Las superficies, contadas una por una

| Dónde | Hoy, con `.transient` | Con `.uploadRetryLater` | Hay que tocar |
|---|---|---|---|
| Ajustes, alert de bloqueo (`ProfileView`) | «Un momento más» | «No pudimos cerrar tu sesión» + el texto de la subida | no: ya está enrutado (`:198`) |
| Hoja del cambio de Apple ID (`AppleIDCloseNoticeView`) | lee `SignOutBlockedCopy` | idem | no |
| Puerta de Grupos del Welcome (`WelcomeGroupsGateView:394`) | rama propia | **cae al catch-all**, que dice «vuelve a entrar con esa cuenta» | **sí: rama nueva** |
| Desasociar (`GroupsAssociationSection:193`) | `detachBlockedTransient` | agrupado con `.transient` en el mismo texto | **sí: separar** |
| Cierre en la nube, paso 2 (`cloudSignOutGroupsBlockReason`) | `.transient` → `.uploadRetryLater` | el asentamiento tiene que volver a `.transient` | **sí: invertir** |
| El canal (`GroupsSyncClient`) | no distinguía quién falló | el push enciende el testigo; el pull y lo local, no | **sí: el testigo (D3)** |

El catch-all del Welcome no es teoría: lo anticipa el propio docblock de `.uploadRetryLater` («Si algún día
nace un segundo productor, ahí hay un catch-all que diría "vuelve a entrar con esa cuenta"»). Este ticket es
ese segundo productor. Y el `switch` de esa vista **no es exhaustivo**, así que el compilador no avisa.

## Lo que se hizo (2026-09-16)

**Quien intenta cerrar sesión sin conexión ya no oye que se está guardando algo.** Antes esperaba 45 s
mirando «Guardando tus cambios pendientes…» y al final leía «Un momento más · Todavía estamos terminando de
guardar unos cambios. Espera unos segundos y vuelve a intentarlo» — nada de eso pasaba. Ahora el aviso sale
al primer intento y dice lo cierto: **«Los últimos cambios de tus grupos no llegaron al servidor. Siguen
guardados en este teléfono y no se pierden; inténtalo de nuevo en un rato.»** El texto de «un momento más» se
queda donde siempre fue verdad: el guardado que todavía se está asentando, que sigue reintentando sus 45 s
porque ahí esperar es justo lo que hace que el gesto termine solo.

**Cuatro superficies, un solo texto por causa.** Ajustes y la hoja del cambio de Apple ID ya estaban
enrutadas y no se tocaron. El desasociar y la puerta de Grupos del Welcome lo estrenan: al segundo le hacía
falta rama propia, porque su `switch` no es exhaustivo y `.uploadRetryLater` habría caído en el catch-all que
dice «vuelve y entra con esa cuenta» — el consejo contrario para quien no tiene red.

**Cero keys de l10n nuevas**: el texto existía desde el 2026-09-14 en los 16 idiomas.

**Gate**: build ×2 sin warnings nuevos · **unit 7029 en 725 suites** · XCUITest de las tres clases del área ·
review adversarial de tres lentes + las rules de área · CI. **Sin device-QA**: reproducirlo exige cortar la
red con cambios de grupos sin subir y una sesión viva, y no hay seam de simulador que lo ponga.

## Lo que cazó la review adversarial, y cambió el arreglo

**Mi primera versión mentía en la otra dirección, y la lente lo midió.** Mapeé `CadenceOutcome.transient`
entero a la subida fallida, y ese outcome no es eso: es el cajón de todo lo pasajero, y **el veredicto del
ciclo es el del PULL siempre que el push vaya bien**. Con la subida perfecta y el pull caído, mi cambio le
decía a la persona que sus cambios no habían llegado al servidor; y al `save()` local de una página que no
entra —que es H-2026-07-18-6, el caso que motivó los 45 s de reintentos— le quitaba además el reintento que
sí lo cura. De ahí sale el testigo de D3, que es la mitad no obvia de este ticket.

Los otros dos hallazgos que cambiaron algo: la puerta del Welcome necesitaba su identificador propio en el
source-scan (sin él, un mutante intercambia las dos ramas y nadie se entera), y el scan del desasociar
recortaba por líneas físicas, así que partir el `case` en dos lo dejaba pasando en falso.

## Lo que deja abierto

- **`signout-alert-fires-on-detach-blocks-it-did-not-cause` empeora con este cambio, y está anotado allí.**
  El desasociar sin red ve ahora, encima de su aviso correcto, un colateral que dice «No pudimos cerrar tu
  sesión» — antes decía «Un momento más», que era impreciso pero no nombraba un gesto ajeno. El agujero es
  preexistente y su arreglo es el discriminador por GESTO, que el coordinador todavía no publica.
- **El camino PERSONAL sigue colapsando a `.permanent`** (`cloud-signout-collapses-the-personal-push-all-reason-into-permanent`).
  Este ticket le cambió la entrada y su salida es byte-equivalente; hay un test que lo fija para que nadie
  crea que ya está arreglado.
- **En los tres caminos que no son la nube no hay breadcrumb del motivo**, así que en campo no se puede
  saber cuál de los dos avisos vio la persona. Lo tenía ya la nube (`signOutGroupsBlocked`).

## Relación con otros tickets

- `groups-push-reads-an-offline-token-refresh-as-a-session-expiry` — de donde sale.
- `cloud-signout-collapses-every-groups-transient-into-permanent` — el texto de la nube para la subida fallida.
