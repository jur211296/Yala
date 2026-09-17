---
id: personal-sync-reads-an-offline-token-refresh-as-a-session-expiry
status: qa
qa-status: needs-testing
implementation_date: 2026-09-16
priority: medium
area: "modo-nube, sesión"
created: 2026-09-15
updated: 2026-09-16
source: "barrido del mismo patrón en `groups-push-reads-an-offline-token-refresh-as-a-session-expiry` (2026-09-15); prioridad corregida por la review adversarial del mismo día"
---

# El canal personal de Modo Nube también lee una renovación sin red como sesión caducada

## El problema, en lenguaje de usuario

Tengo una cuenta en la nube y me quedo sin conexión con el token caducado. Mis datos dejan de sincronizar hasta que
vuelvo a abrir la app, y los cambios de mis grupos tampoco suben, aunque lo único que falla es la red. Si activo el
modo completo sin red, Yala me enseña el aviso de sesión caducada.

**A quién le llega, corregido en la review del 2026-09-15.** La primera versión de este ticket decía que a nadie,
porque Modo Nube estaría apagado. No lo está: la tarjeta de alta en la nube se ofrece en producción desde el
2026-09-09 (`CloudSyncFlags.bornCloudChoiceEnabled`, medido allí con `curl`), así que puede haber cuentas `.cloud`
en los builds que la traen. Sin medir cuántas hay.

## Lo medido al abrir (leído en el código, sin ejecutar)

> Las coordenadas de este bloque son de la medición del 2026-09-15, anteriores al cambio.

`CloudAuthService.accessToken()` devuelve `nil` por cualquier fallo, y en estos sitios ese `nil` se lee como sesión
caducada:

- `SyncPushClient.push` y `SyncPullClient.pull`: devuelven `.sessionExpired` sin hacer la petición y cuentan el
  canario `cloudSyncBlockedByExpiredSession`. `CloudSyncRuntime` los convierte en `stopUntilSignIn`.
- `PrefsSyncClient`, `MigrationWorkExecutor` (8 `guard` sobre el token), `BornCloudSignUpService`,
  `AccountDeletionService` y `SIWATokenRevocation`.
- Los proveedores de token de `AccountEntitlementService`, `AccountKindService`, `CloudIdentityDiscovery` y
  `CloudMigrationController`.
- **Y frena también a Grupos.** En `.cloud` Grupos no tiene loop propio: cicla en el paso 5.6 del runtime personal
  (`CloudSyncRuntime.performCycle`). Con el push o el pull personal parados por el token nulo, el ciclo sale antes de
  ese paso y los cambios de grupos no suben hasta volver a primer plano.
- La activación del modo completo por la nube pasa por `BornCloudSignUpService`: sin token termina en
  `FullModeActivationFlowLogic` → `.blocked(.sessionExpired)`.
- **El 401 `yala_attest_required` también se lee caducado aquí** (`SyncPushClient`, `SyncPullClient` y
  `PrefsSyncClient` mapean todo 401 a `.sessionExpired`).

**Precisión medida al arreglarlo (2026-09-16): el token nulo solo llegaba al push en una ventana.** `performCycle` pide
el token de App Attest ANTES de subir, y ese token vive 15 min en una caché en memoria. Sin red y con él caducado, renovarlo
falla por red y el ciclo ya salía pasajero en la puerta, antes y después de este cambio. El bug salía cuando el JWT
caducaba sin red **mientras el attest seguía en caché** (en los 15 min siguientes a su última renovación), o cuando el
servidor de sesiones fallaba con la red bien. En esa ventana el motor paraba, y ya no volvía a ciclar hasta primer plano.
La activación del modo completo no pasa por esa puerta: ahí el bug salía siempre sin red.

La consecuencia que se anotó el 2026-09-15 —«el aviso fijo del canal personal no llega a quien el gateway le rechaza el
token»— **se midió al arreglarlo**: esa población no es un teléfono sin App Attest, y el aviso culpa al teléfono. Queda
como pregunta para Jürgen en `cloud-attest-notice-does-not-cover-a-gateway-rejected-token` (decisión D15 del Paso 0 del
encargo).

## Inventario por sitio y decisión (medido el 2026-09-16 en `a0e362b57`)

| Sitio | Qué hacía con el token nulo | Decisión |
|---|---|---|
| `SyncPushClient.push` | `.sessionExpired` + canario → el runtime paraba con `stopUntilSignIn` | Con la sesión guardada, `.transient`; sin ella, lo de antes |
| `SyncPullClient.pull` | ídem, sin filas pendientes | ídem |
| `PrefsSyncClient` push y pull | `.sessionExpired`; el runtime ignora el outcome | ídem, para que el outcome no mienta |
| `BornCloudSignUpService.signUp` | `.sessionExpired` → «Tu sesión caducó» en la activación; el Welcome cerraba la sesión | Con la sesión guardada, `.transient`: los dos consumidores ya tenían camino pasajero con copy |
| `MigrationWorkExecutor` (8 guards), snapshot, `verify`, reversa | `.sessionExpired`, que colapsa con `.transient` en la misma parada retomable | Sin cambio: no hay nada que separar |
| Claim del adopt del Welcome | «No pudimos verificar tu cuenta. Revisa tu conexión…» + «Reintentar» | Sin cambio: ya es honesto |
| `AccountDeletionService` | trata caducada y pasajero igual: «Intenta de nuevo en un momento» | Sin cambio; se corrige el docblock de `DeleteOutcome` |
| `SIWATokenRevocation` (canje y revocación) | `.noJwt`, sin consumidor ni pantalla | Sin cambio |
| `AccountEntitlementService`, `AccountKindService`, `CloudIdentityDiscovery` | `false`, la caché o `.unavailable(retryable: true)` | Sin cambio: no leen caducada |
| `CloudMigrationController.startMigration` (`sessionIsUsable`) | «No pudimos iniciar sesión. Inténtalo de nuevo.»; con red, el reintento funciona | Sin cambio; se corrige el docblock de `failNoUsableSession` |
| `SyncMerkleClient` | `.sessionExpired` → `.skipped`, no para nada | Sin cambio |

Y el 401 `yala_attest_required` en `SyncPushClient`, `SyncPullClient` y `PrefsSyncClient`: `.transient`, con rastro y
canario propio, **sin sumar a la racha del teléfono** (D3 revisada y D15 del Paso 0 del encargo).

Las decisiones, con su porqué y la revisión que forzó la review adversarial, están en el Paso 0 de
`encargos/lanzados/2026-09-16-personal-sync-reads-an-offline-token-refresh-as-a-session-expiry.md`.

## Hecho el 2026-09-16

**Lo que cambia para la persona.** Con la cuenta en la nube:

- **Si la sesión caduca sin conexión poco después de usar Yala** (en los 15 min en que la verificación de seguridad del
  teléfono sigue en memoria), **o si el servidor de inicio de sesión falla con la red bien, la sincronización ya no se
  para.** Reintenta sola, cada vez más espaciado (hasta cada 5 min), y sube en cuanto vuelve la red, sin volver a abrir la
  app. Los cambios de grupos suben en la misma vuelta en cuanto pasan los personales.
- **Ajustes deja de pedir «Inicia sesión para subir N cambios»** en ese caso. Ahora esa sección dice «Todo
  sincronizado», igual que ya le pasaba a quien está sin red en cualquier otro momento: es falso y tiene su ticket
  (`cloud-sync-status-says-all-synced-with-changes-still-pending`).
- **«Activar Yala completo» sin red** pasa de «Tu sesión caducó» (solo «Cerrar») a «No pudimos activar tu cuenta ·
  Revisa tu conexión e inténtalo de nuevo. Todavía no cambiamos nada.» con «Reintentar». En el Welcome, el alta en la
  nube sin red ya no cierra la sesión.
- **Un 401 por App Attest con la red bien** (el servidor rechaza un token bueno) tampoco para la sincronización ni pide
  volver a entrar, que no lo arreglaba. No enseña ningún aviso: `cloud-attest-notice-does-not-cover-a-gateway-rejected-token`.
- **Con la sesión borrada de verdad no cambia nada**: se sigue pidiendo volver a entrar.

**Lo que se tocó.**

- `SyncPushClient`, `SyncPullClient`, `PrefsSyncClient`: parámetro `canRenewSession` (default `{ false }`, solo para
  tests) leído después de pedir el token; rama `401 where GatewayErrorEnvelope.isAttestRequired` pasajera, sin tocar la
  racha. Rastros nuevos: `CloudSyncPush/Pull transient token-unavailable session=kept` y `CloudSync attestRequired edge=…`.
- `CloudSyncRuntime.makeDefault` y `CloudMigrationController.makeExecutor` pasan `canRenewSession` del proveedor de sesión.
- `BornCloudSignUpService.signUp`: token nulo con la sesión guardada → `.transient`.
- `MetricsService`: canario nuevo `cloudSyncAttestRequired` (una vez por proceso y ruta). `cloudSyncBlockedByExpiredSession`
  ya no cuenta el token que no llega con la sesión guardada ni el 401 del attest: la serie cambia de definición con este
  build (anotado en `docs/modo-nube/MODO-NUBE-DIFERIDOS.md`).
- Docblocks al día en el protocolo de sesión del runtime, `stoppedByUnavailableAttest`, `resolveAttest`,
  `GroupsAttestStreakStore`, `AttestSyncGate`, `CloudAuthService.canRenewSession`, `CloudAccountClient`,
  `BornCloudSignUpOutcome`, `FullModeActivationFlowLogic.PromotionBlock`, `StorageMigrationSignInLogic` y `GroupsSyncClient`.
- Gateway: test nuevo `gateway/test/sync.attest401.test.ts`, que fija que la guard de `/sync/*` y `/prefs/*` separa los
  dos 401. Solo corre a mano (`npm test -- test/sync.attest401.test.ts`).
- Rules: `.claude/rules/gateway-attest.md` («Los dos 401 de la guard») y una regla nueva al final de
  `.claude/rules/swiftdata-cloudkit.md`.

**Cómo se verificó.**

- **Build ×2** (`Yala` y `Yala Dev`): en verde y sin warnings nuevos en los ficheros tocados.
- **Unit, la suite entera**: `YalaTests` con **7.188 tests en 730 suites, 0 fallos** (12 omitidos), leído del result bundle.
  Se corrió entera y no por suites porque veinte ficheros de tests leen como texto los ficheros tocados, y uno de esos
  scans (`CloudPersonalAttestSignOutTests`) se había puesto rojo con la primera versión sin salir en la corrida acotada.
- **XCUITest**: **29 casos en las 9 clases** de las áreas tocadas, 0 fallos, con cola y el centinela en 0. Corrieron antes
  de los últimos retoques, que en producción solo tocaron comentarios.
- **Mutantes: 18 sobre el diseño final, los 18 muertos**, cada uno por su test exclusivo y con el árbol restaurado byte a
  byte: las ramas del token nulo y del 401 en los tres clientes y en el alta, la sesión leída antes del `await`, el 401
  sumando o borrando la racha, el canario de caducada en la rama pasajera, el deduplicado y la ruta del canario nuevo, el
  predicado del 401 ensanchado a `yala_attest_*`, la puerta sin acierto y el cableado de `canRenew` literal o invertido.
  Y 3 más en la guard de `gateway/src/sync/routes.ts`, que mata `sync.attest401.test.ts` (20/20, con
  `groups.attest401.test.ts` 20/20 al lado).
- **Review adversarial en dos pasadas.** La primera, con cuatro lentes (lógica del canal, tests, lo que ve la persona y
  documentos), tumbó parte del diseño: contar el 401 en la racha del teléfono daba falsos positivos, y se retiró (el Paso 0
  del encargo lo cuenta). La segunda, con dos lentes, cazó que **el guion de device-QA no llegaba al arreglo** —sin red la
  verificación de App Attest también caduca y el motor sale antes— y lo que eso cambia sobre a quién le llegaba el bug.
  Lo demás que encontraron está arreglado o tiene ticket.
- `validate-coverage` OK y `docs/TICKETS.md` igual al disco.

**Lo que queda, con ticket:**

- `cloud-attest-notice-does-not-cover-a-gateway-rejected-token` (nuevo, `medium`, decisión de Jürgen) — si el aviso fijo
  debe salir a quien el gateway rechaza un token bueno.
- `cloud-sync-status-says-all-synced-with-changes-still-pending` (nuevo, `medium`, decisión de Jürgen) — «Todo
  sincronizado» con cambios sin subir.
- `personal-sync-does-not-retry-a-401-with-a-forced-token-refresh` (nuevo, `low`) — el 401 de JWT con el reloj atrasado.
- `storage-sync-sign-in-count-has-no-plural` (nuevo, `low`) — «Inicia sesión para subir 1 cambios».
- `groups-actions-read-an-offline-token-refresh-as-a-session-expiry` — el mismo patrón en las acciones de grupo.

**Aceptado a sabiendas, como en Grupos:** una sesión que el servidor rechaza sin que el SDK la borre (`user_banned`) se
lee pasajera: la activación ofrece un «Reintentar» que no puede funcionar y el Welcome no suelta la sesión. Población ~0.

## Device-QA — parcial

El token nulo se monta en un iPhone, pero **solo en su ventana**: con la verificación de App Attest aún en caché. Si el
iPhone pasa más de 15 min sin red, el motor sale en su puerta antes de llegar al push y el build viejo se comporta igual.
El 401 del attest no se puede montar: staging corre `ENFORCE = "observe"` y lo deja pasar, así que lo cubren los unit, el
test del gateway y los mutantes. En producción se vigila con el canario `cloudSyncAttestRequired`.

**Montaje.** iPhone con **Yala Dev** (staging), lanzado desde Xcode para ver la consola filtrada por `CloudSync`, y una
cuenta en la nube («Es mi primera vez en Yala» → «Tu cuenta en la nube», o «Migrar a la nube» desde Ajustes). Para el
paso 7, además, una cuenta de solo grupos.

1. Con red, abre Ajustes → «Dónde viven tus datos» → «Modo Nube · Auth» y apunta la hora `exp`.
2. **Espera a que falten menos de 10 minutos para `exp`.** Entonces cierra Yala del todo y vuelve a abrirla con red: el
   primer ciclo pide una verificación de App Attest nueva, que vale 15 min. Apunta la hora.
3. Pon el **modo avión**, apunta dos movimientos y deja la app en segundo plano.
4. Vuelve a Yala **después de `exp` y antes de que pasen 14 min desde el paso 2**. Ve a Ajustes → «Dónde viven tus datos».
   - **Esperado:** la sección de sincronización **no** dice «Inicia sesión para subir 2 cambios». Dice «Todo
     sincronizado» (falso y conocido: `cloud-sync-status-says-all-synced-with-changes-still-pending`).
   - En la consola: `CloudSyncPush transient token-unavailable session=kept pending=2`. **En ningún caso**
     `CloudSyncPush blocked=no-session` ni `CloudSyncRuntime stopped reason=session-expired`.
   - **Con el build de antes** (control opcional): sale «Inicia sesión para subir 2 cambios» y la consola dice
     `CloudSyncRuntime stopped reason=session-expired`. Si no sale, la ventana no se montó: repite desde el paso 2.
5. Quita el modo avión **con la app abierta y sin tocar nada**. En menos de 5 minutos los dos movimientos llegan a la
   cuenta: compruébalo en otro dispositivo con la misma cuenta.
6. **Control con la sesión borrada de verdad.** Con red, en el dashboard de Supabase de staging busca la cuenta en
   Authentication → Users por su correo, copia su id y corre `delete from auth.sessions where user_id = '<id>'`. Pon el
   modo avión, apunta un movimiento y espera a que pase `exp`. Quita el modo avión con la app abierta.
   - **Esperado:** en un par de minutos Ajustes **sí** dice «Inicia sesión para subir 1 cambios» (sin plural, es así) y la
     consola dice `CloudSyncPush blocked=no-session`.
7. **La activación del modo completo, que no pasa por la puerta.** Con la cuenta de solo grupos, deja pasar `exp` con el
   modo avión puesto y la app en segundo plano. Abre Más → «Activar Yala completo» y sigue hasta el final.
   - **Esperado:** «No pudimos activar tu cuenta» con «Reintentar» y «Cancelar». **En ningún caso** «Tu sesión caducó».
   - Quita el modo avión y toca «Reintentar»: la activación sigue.

## Relación con otros tickets

- `groups-push-reads-an-offline-token-refresh-as-a-session-expiry` — el arreglo del canal de Grupos.
- `groups-actions-read-an-offline-token-refresh-as-a-session-expiry` — el de las acciones de grupo.
- `groups-sync-reads-a-missing-attest-401-as-a-session-expiry` — el 401 del attest en Grupos, que allí sí suma a la racha.
- `attest-session-token-rejected-by-the-gateway-stays-cached` — el token que el servidor ya rechaza sigue en la caché.
