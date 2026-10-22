---
id: groups-sync-reads-a-missing-attest-401-as-a-session-expiry
status: done
priority: medium
area: "groups, sesión, attest"
created: 2026-09-15
updated: 2026-09-23
source: "medición de `groups-push-reads-an-offline-token-refresh-as-a-session-expiry` (2026-09-15)"
qa-status: not-replicable
qa-date: 2026-09-23
qa-notes: barrido 2026-09-23 sin device-QA - solo contra produccion con un telefono sin App Attest; GroupsMembershipClientTests
---

# Un 401 por App Attest ausente también se lee como «Tu sesión caducó»

## El problema, en lenguaje de usuario

Mi sesión está bien, pero este teléfono no consiguió su token de App Attest. Los cambios de mis grupos dejan de subir
hasta que la app vuelve a primer plano, y si toco «Cerrar sesión» Yala me dice «Tu sesión caducó. Vuelve a iniciar
sesión…». Volver a entrar no lo arregla: lo que falta no es la sesión.

## Lo medido (leído en el código, sin ejecutar)

> Las coordenadas son de la medición, anteriores al cambio del 2026-09-15.

- En producción (`ENFORCE = "enforce"`, `gateway/wrangler.toml`), `requireUserAndAttest` responde **401** por tres
  salidas (`gateway/src/groups/routes.ts`): sin JWT (`yala_attest_required`), con el JWT inválido o caducado
  (`yala_attest_invalid`), y sin un token de attest que verifique, falte la cabecera o no valide
  (`yala_attest_required`). El mismo código cubre dos causas; la primera no la produce este cliente, que no manda
  nada sin token.
- `AttestSessionProvider.live` devuelve `nil` cuando no consigue el token (red caída, key que el gateway no reconoce,
  simulador sin el bypass de desarrollo), y el cliente manda la petición sin la cabecera.
- `GroupsSyncClient` lee todo 401 como sesión caducada. Su reintento fuerza el refresh del JWT, que sí llega; la
  re-emisión vuelve a dar 401 porque sigue sin attest, y el resultado es `.sessionExpired`: el loop para
  (`stopUntilSignIn`) y el cierre de sesión enseña `groups.errors.sessionExpired`.
- Sin medir: cuánta gente llega aquí. **`GroupsMembershipClient` sí sufría lo mismo** (medido al implementar): su 401
  era `.sessionExpired`, y salir de un grupo decía «Tu sesión caducó».

## Lo que hay que decidir (Jürgen)

1. Leer el `code` del envelope del 401 y tratar `yala_attest_required` como pasajero, con su rastro en los logs.
2. Dejarlo, sabiendo que exige que el attest falle mientras la red funciona.

**Decidido por Jürgen el 2026-09-15: la 1.**

## Criterios de aceptación

- [x] Un 401 `yala_attest_required` ya no es `.sessionExpired` en el push ni en el pull (tests), y un 401
      `yala_attest_invalid` sigue siéndolo (test en la dirección contraria).
- [x] El loop entra en backoff en vez de parar (test).
- [x] Queda rastro en los logs: `GroupsSync attestRequired edge=…`.
- [x] Revisado `GroupsMembershipClient`: tenía el mismo 401 → `.sessionExpired` y se arregla con el mismo criterio
      (tests).

## Hecho el 2026-09-15 — opción 1

**Lo que cambia para la persona.** Con la sesión buena, la red funcionando y sin App Attest:

- **La sincronización de grupos ya no se para:** reintenta sola, cada vez más espaciado (hasta cada 5 min).
- **Cerrar sesión con cambios de grupos sin subir** enseña lo mismo que sin conexión desde el #171: al momento en la
  nube («Los últimos cambios de tus grupos no llegaron al servidor…», si no hay cambios personales pendientes; con
  ellos sale el aviso genérico de siempre), y tras unos 45 s de reintentos en el «equipo», en solo grupos, en la hoja
  del cambio de Apple ID y en la puerta de Grupos del Welcome. Ninguna dice ya «Tu sesión caducó».
- **Salir de un grupo** dice «No pudimos completar tu salida del grupo. Vuelve a intentarlo en un momento.», unos
  4 s después.
- **Aceptar una invitación** ya no vuelve a abrir el inicio de sesión de Grupos: conserva la invitación, la pantalla
  de unión pasa a «Está tardando un poco más de lo normal», y la unión se reintenta sola en cada arranque.

Con el JWT caducado de verdad (`yala_attest_invalid`) no cambia nada: se sigue pidiendo volver a entrar.

**Lo que se tocó.** Las decisiones están en el Paso 0 de
`encargos/lanzados/2026-09-15-groups-sync-reads-a-missing-attest-401-as-a-session-expiry.md`.

- `GatewayErrorEnvelope.isAttestRequired` lee el `type` del envelope; el gateway escribe el mismo valor en `code`.
- `GroupsSyncClient`: el `send` del push y del pull devuelve `.transient` con ese código, antes del reintento del
  401, así que no fuerza el refresh del JWT. La re-emisión que sigue a un JWT caducado lo clasifica igual.
- `GroupsMembershipClient.call` lanza `.transient(status: 401)`, con su reintento corto.
- Rastro nuevo: `GroupsSyncBreadcrumb.groupsAttestRequired(edge:)`, con `push`, `pull` o `rpc:<fn>`.
- Test nuevo del gateway, `gateway/test/groups.attest401.test.ts`: las dos guards de Grupos separan los dos códigos.
- Al día los docblocks de `BlockReason.sessionExpired`, `AttestSessionProvider.live`, `GroupsRPCError` y
  `PushOutcome`, con una sección nueva en `.claude/rules/gateway-attest.md` y notas en cuatro tickets hermanos.
- `GroupsMerkleClient` y `PushTokenRegistrationClient` no se tocan: su 401 no llega a nada visible.

**Cómo se verificó.**

- Gate: build ×2 (`Yala` y `Yala Dev`) sin warnings nuevos en los ficheros tocados · unit **858 tests en 86 suites**
  (85 pedidas), 0 fallos, 7 omitidos · XCUITest **5 casos en 2 clases** (`AppleIDCloseNoticeUITests`, `SessionExitsPerCellUITests`) con el centinela, tras una primera corrida que cortó la memoria del sistema · audit limpio en las 269 líneas añadidas · índice de
  cobertura OK.
- Mutantes, 11 de 11 muertos. Seis en iOS: sin la rama en el push, en el pull y en membresía; el predicado ensanchado
  a `yala_attest_*`; un typo en el literal; la re-emisión del pull leída caducada. Cinco en el gateway: JWT inválido
  emitiendo `_required` en `routes.ts` y en `rpc.ts`, attest ausente emitiendo `_invalid`, `rpc.ts` sin exigir
  attest, y un attest con forma de JWT tratado como `_invalid`.
- Gateway: `groups.attest401.test.ts` 20/20, con sus vecinos en verde.
- Review adversarial con tres lentes (lógica del canal, tests, pantallas y documentación): ningún hallazgo alto; lo
  que cazaron está arreglado o tiene ticket.

**Lo que queda fuera.**

- El canal personal (`SyncPushClient`, `SyncPullClient`, `PrefsSyncClient`) seguía leyendo todo 401 como caducada. Desde
  el 2026-09-16 lee pasajero el `yala_attest_required` (el resto de 401 sigue siendo caducada), **sin sumar a la racha**:
  allí la puerta del motor ya consiguió el token, así que el 401 no habla del teléfono
  (`personal-sync-reads-an-offline-token-refresh-as-a-session-expiry`).
- El texto «espera unos segundos» del cierre pasajero tampoco es cierto para esta población, y sus 45 s de
  reintentos mandan unas 23 subidas que no pueden acertar: `signout-pending-copy-says-wait-seconds-when-offline`.
- Un token de attest que el servidor ya rechaza sigue guardado hasta que caduca en el reloj del teléfono:
  `attest-session-token-rejected-by-the-gateway-stays-cached` (nuevo, `low`).
- Un teléfono que no recupera nunca el attest oye «en un rato» para siempre y no puede cerrar sesión con cambios de
  grupos: `groups-phone-that-never-attests-is-told-to-retry-forever` (nuevo, `medium`, decisión de Jürgen).
- Una invitación que falla por algo pasajero caduca a los 7 días sin avisar:
  `groups-join-intent-expires-silently-after-transient-failures` (nuevo, `medium`).
- Crear un enlace de invitación culpa a la conexión ante cualquier fallo del servidor:
  `invite-link-creation-blames-the-connection-for-any-rpc-failure` (nuevo, `low`).
- Aceptado a sabiendas tras la review adversarial: cada vuelta del loop en backoff intenta el attest y comparte su
  escalera con la IA, así que al volver Apple la IA puede tardar hasta 60 s en recuperarse; los reintentos cortos de
  membresía casi nunca aciertan y retrasan el aviso unos 4 s; y una sesión revocada con el JWT vigente se descubre al
  caducar el JWT. Detalle en `.claude/rules/gateway-attest.md`.

## Device-QA — parcial

El caso solo existe con `ENFORCE = "enforce"`, o sea contra producción. **El scheme `Yala` de Xcode lo produce
siempre**: en el simulador no hay App Attest, así que cada petición de Grupos sale sin token y el gateway responde 401
`yala_attest_required`. Lo que ese montaje no permite es tener cambios de grupos pendientes —en una instalación nueva
no baja ningún grupo—, así que el cierre de sesión con cambios sin subir queda cubierto solo por los unit tests.

**Montaje.** Xcode con el scheme **Yala** (no `Yala Dev`) en el simulador iPhone 17 Pro, y una cuenta real de Grupos.
Hace falta además un enlace de invitación a un grupo de prueba, creado desde un TestFlight.

1. Lanza la app desde Xcode e inicia sesión en Grupos con la cuenta. Si pide el consentimiento, acéptalo.
2. En la consola de Xcode, filtra por `GroupsSync`.
   - **Esperado:** `GroupsSync attestRequired edge=pull` repetido, cada vez más espaciado (5 s, 10 s, 20 s…).
   - **En ningún caso** `GroupsSync loopStopped reason=session-expired`.
3. Abre el enlace de invitación en el simulador (Safari o Notas).
   - **Esperado:** `attestRequired edge=rpc:join_group` tres veces, y a los 20 s la pantalla de unión dice «Está
     tardando un poco más de lo normal».
   - **En ningún caso** vuelve a salir el inicio de sesión de Grupos.
4. **Control, opcional:** el mismo recorrido con un build de `2.1` anterior a este cambio da un
   `loopStopped reason=session-expired` en el paso 2, y en el paso 3 vuelve a abrir el inicio de sesión.

## Relación con otros tickets

- `groups-push-reads-an-offline-token-refresh-as-a-session-expiry` — el otro caso en el que el canal llamaba caducada
  a una sesión que no lo estaba.
- `signout-pending-copy-says-wait-seconds-when-offline` — el texto del aviso pasajero, que esta población también ve.
- `personal-sync-reads-an-offline-token-refresh-as-a-session-expiry` — el mismo 401 en el canal personal.
- `.claude/rules/gateway-attest.md` — la asimetría observe/enforce, la recuperación de la key y los dos 401.

## Barrido de `qa` · 2026-09-23 · cerrado sin device-QA

Sale de la cola de device-QA por el barrido que pidió Jürgen el 2026-09-23 (encargo `2026-09-23-barrido-qa-in-qa-pre-device`). Solo pasa contra producción con un teléfono sin App Attest. Lo cubren `GroupsMembershipClientTests` y `SessionExitsPerCellUITests`.
