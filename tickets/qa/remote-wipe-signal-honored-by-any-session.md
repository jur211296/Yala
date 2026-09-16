---
id: remote-wipe-signal-honored-by-any-session
status: qa
priority: high
area: "settings, modo-nube, sync"
created: 2026-09-11
updated: 2026-09-16
source: "review adversarial del plan del paso 9 (`session-exits-one-verb-per-session`), lado RECEPTOR de la señal de vaciado"
---

# La señal «vacía tus datos» la obedece cualquier sesión del Apple ID, también las de la nube

## El síntoma, en lenguaje de usuario

Vacío mis datos en mi iPhone privado. En el iPad del mismo Apple ID tengo abierta una sesión en la nube (o
el móvil lo está usando otra persona con su cuenta): ese dispositivo también se vacía, y como está en la
nube, sus borrados suben a SU cuenta.

## Lo medido (2026-09-11)

- «Vaciar datos» llama a `DataWipeService.wipeAllUserData(broadcastSignal: true)`, que escribe
  `lastWipeTimestamp` en el **iCloud KV del Apple ID** (`PreferenceSyncService.signalWipeInitiated`).
- Todo dispositivo con el onboarding completado lo procesa (`ContentView.handleRemoteWipeSignal` →
  `performLocalWipeForRemoteSync`), **sin mirar qué sesión tiene**: borra filas con `wipeAllUserData`.
  En `.icloud` con espejo eso borra además su iCloud; en `.cloud` el motor sube los borrados a la cuenta.
- El paso 9 cerró el lado EMISOR: la señal ya solo sale de una sesión privada
  (`DestructiveScopeLogic.wipeSignalsAppleIDDevices`). Queda este lado.

## Lo que debería pasar

Solo una sesión PRIVADA obedece la señal: es la única cuyos datos son los del Apple ID. Una sesión en la
nube (completa o solo grupos) la ignora y la marca como procesada.

## Criterios de aceptación

- [x] Un dispositivo en `.cloud` o solo-grupos que recibe `lastWipeTimestamp` no borra nada.
- [x] Una sesión privada del mismo Apple ID sigue vaciándose como hoy.
- [x] Test de la decisión pura (`RemoteWipeSignalDecider`) con el eje de sesión.

---

## Hecho (2026-09-14)

El predicado es **el mismo del emisor por el otro extremo del canal**:
`DestructiveScopeLogic.wipeSignalObeyedByThisSession` **delega** en `wipeSignalsAppleIDDevices` en vez de
copiar su cuerpo — las dos contestan la misma pregunta («¿los datos de este dispositivo son los del Apple
ID?») y dos cuerpos iguales que «siempre van juntos» divergen en el commit siguiente, hacia el lado que
borra. El receptor lee `confirmedPrivateSession` (marca ausente ⇒ `false`), porque aquí el `true`
equivocado BORRA.

**El eje se consulta en TRES puntos** (eran dos hasta el 2026-09-14): donde la señal se detecta
(`PreferenceSyncService.checkForRemoteWipeSignal`, que es quien encola el intent), donde se drena
(`ContentView.handleRemoteWipeSignal`, que es quien borra) y —desde el ticket
`wipe-alert-fires-on-a-session-that-no-longer-obeys-the-signal`— delante del AVISO que la gracia de 5 s
enciende cuando las filas desaparecen del store (`ContentView`, `onChange` de `hasPersonalData`). El
tercero no borra: afirma. Al llevar este ticket al device, comprueba también que ese aviso NO sale en la
celda que no obedece. El parámetro **no tiene valor por defecto a
propósito**: un default devolvería a los call-sites futuros el derecho a no pronunciarse, que es la forma
exacta de este bug.

**El orden de los guards importa y está fijado por un test**: el eje va DESPUÉS del guard de
fresh-install, porque ese guard es el único que MARCA los timestamps y adelantarlo reintroduce el bug #6.

### Lo medido que corrige la premisa del ticket

El ticket presenta las dos celdas como igual de vivas. No lo son:

- **Solo-grupos (F) — vivo hoy.** Grupos está al 100 % en producción, así que el móvil prestado es un
  caso real.
- **Nube completa (E) — preventivo.** Las dos puertas de la nube están cerradas por kill-switch remoto
  (`CLOUD_MODE_ROLLOUT_PERCENT = 0`), no por diseño: se abre en cuanto se suba el percent. El docblock de
  `CloudSyncFlags.storageMode` que dice «SIEMPRE `.icloud` (DARK)» está caducado — `writeCloudArmed` tiene
  tres escritores alcanzables desde el Welcome y desde «Activar Yala completo».

### La red

14 mutantes corridos, 14 muertos. Los cuatro que más importan los cazó la review adversarial sobre MIS
PROPIOS TESTS: un `||` colgado del cálculo del eje pasaba los dos `contains` del source-scan y dejaba el
bug vivo **con la suite en verde**; un default en la firma y un `#if DEBUG` alrededor del guard pasaban
los 16 casos de la matriz; y el conteo de consumidores solo miraba dos ficheros, así que un tercer
call-site con un `true` a mano salía verde. El scan compara ahora la SENTENCIA entera por igualdad —un
`contains` no puede cerrar el extremo derecho de una expresión— y cuenta sobre todo `Yala/`.

Un test se **retiró**: no podía fallar de forma única (su `#expect` se reducía al de la tabla de al lado,
con el argumento que el propio test fijaba) y su docblock afirmaba proteger un call-site que no tocaba.

### Device-QA: NO simulable

Medido, con coordenadas: no hay seam que escriba `lastWipeTimestamp` en el iCloud-KV
(`OwnerKeyValueStore` no contiene ni una referencia a `uitest`, y `-uitest-fake-beacon` documenta
explícitamente que «no persiste: no escribe en el iCloud-KV del simulador»); `AppBootstrapper` ni siquiera
llama a `bootstrap()` bajo `-uitest`; y la celda E no tiene launch arg ninguno —los tres escritores de
`.cloud` exigen backend y sesión real—. **Hacen falta dos dispositivos reales con el mismo Apple ID.**

#### Guion

1. **iPhone A (privado)**: sesión privada con iCloud activo y datos personales.
2. **iPhone B**: entrar por invitación de grupo (sesión solo-grupos), con el mismo Apple ID del sistema.
   Comprobar en Ajustes que B NO ofrece la vida personal.
3. En A: Ajustes → **Vaciar mis datos** → confirmar.
4. **En B, esperar y comprobar que NO se vacía**: su perfil y sus preferencias siguen. En la consola de B
   debe salir `PreferenceSyncService: Remote wipe detected (… shouldProcess=false, sessionObeys=false)`.
5. **Control positivo** — sin él el paso 4 no prueba nada: repetir con B en **sesión privada** del mismo
   Apple ID. Ahí sí tiene que vaciarse, y el log dice `sessionObeys=true`.
6. Anotar si en B aparece el aviso «Datos no disponibles» (ticket
   `wipe-alert-fires-on-a-session-that-no-longer-obeys-the-signal`) — se espera que sí cuando el store de
   B monta espejo.

### Lo que este PR NO cierra, con ticket propio

- ~~`remote-wipe-axis-misses-groups-only-installs-before-the-mount-mark` (**high**)~~ — **CERRADO el
  2026-09-14 midiendo que su población es cero.** Un alta solo-grupos anterior al 2026-09-10 no tiene la
  marca del mount neutro, el backfill le escribe `hasPrivateSession = true` y seguiría obedeciendo; lo que
  no existe es nadie en esa celda: cero altas solo-grupos en la telemetría de producción de los 90 días
  (los únicos registros son 5 altas personales y 1 migración a la nube), cero identidades en el backend de
  Grupos, y el camino solo viajó en tres builds de TestFlight con 3 testers. El desglose, en el docblock de
  `PrivateSessionMark.backfillIfNeeded`.
- `wipe-sheet-still-promises-every-apple-id-device` (**high**) — la hoja sigue diciendo «desaparecen
  también de tu iPad, tu Mac y cualquier dispositivo con este Apple ID». Decisión de copy.
- `wipe-alert-fires-on-a-session-that-no-longer-obeys-the-signal` (**high**) — la compensación que
  cancelaba el alert vivía tras el `guard`, así que ya no corre.
- `icloud-kv-prefs-cross-sessions-on-a-lent-phone` (**high**) — las 37 preferencias cruzan en los dos
  sentidos; el guard que lo impedía se retiró sobre una premisa que la celda F contradice.
- `remote-onboarding-signal-ignores-the-session-axis`, `remote-wipe-signal-is-burned-even-when-the-session-ignores-it`,
  `storage-mode-is-a-proxy-for-the-mirror-in-the-wipe-signal`, `restore-gate-claims-a-wipe-this-device-did-not-do`,
  `remote-wipe-receiver-has-no-behaviour-test` (medium).

## Corrección al guion · 2026-09-16 (barrido de QA)

**Paso 6** — la expectativa cambió. Desde el 2026-09-14
(`wipe-alert-fires-on-a-session-that-no-longer-obeys-the-signal`, done), el aviso «Datos no disponibles»
se calla en una sesión que no obedece la señal de borrado. En B (solo-grupos) **no debe aparecer**. Y un
solo-grupos dado de alta desde el 2026-09-10 monta el store sin espejo (`.neutralNoMirror`).
