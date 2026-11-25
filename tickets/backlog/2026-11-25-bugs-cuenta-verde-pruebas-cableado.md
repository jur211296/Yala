---
id: 2026-11-25-bugs-cuenta-verde-pruebas-cableado
status: backlog
priority: high
area: "cloud-sync, account-deletion, bienvenida-2-3"
created: 2026-11-25
updated: 2026-11-25
source: "CI del PR «Bugs de cuenta: Vaciar datos, Eliminar cuenta y primeros pasos en solo gastos» (run 45633857419), card het0 del tablero"
---

# Bugs de cuenta: dejar en verde las pruebas de cableado de la sesión de la nube y la espera del Panel

## Qué pasó

El PR de los bugs de cuenta (https://github.com/jur211296/Yala/pull/1176) quedó con el check `tests` en rojo en la
tanda 2 de unit, en dos pruebas que comparan el texto del código:

1. `CloudSessionRevisionWiringTests.readerTracksTheSession`, caso `ProfileView.swift` /
   `deleteAccountRowHasSession`: esperaba `track()` y, en la línea siguiente,
   `return UITestHooks.fakeBackendSession || CloudAuthService.shared.hasSession`.
2. `PanelWaitsAfterEmpezarTests.wiring`: esperaba la condición de desarme sin `|| waitsForSignIn`.

## Paso 0 — decisiones

- **Prueba 1: la prueba quedó vieja, el código está bien.** El getter sigue abriendo con
  `CloudSessionRevision.shared.track()` y lee la sesión justo después, ahora como primer argumento de
  `AccountDeletionRowLogic.shouldShow(hasSession:storageIsCloud:)`. Lo que la prueba protege (card n533: la fila se
  repinta cuando la sesión entra con Ajustes abierto) sigue en pie: la dependencia se ata antes de leer la sesión.
  Arreglo: `readerTracksTheSession` acepta una lectura de varias líneas y compara TODAS, en orden, detrás de `track()`.
  Para este caso fija la expresión entera (las tres líneas), así que es más estricta que antes: también caería si
  alguien quita la rama «datos en la nube».
- **Prueba 2: la prueba quedó vieja, el código está bien.** `waitsForSignIn` hace que `PanelAccountDataWait.next`
  devuelva `.idle` (el motor parado hasta iniciar sesión no va a bajar nada), así que en ese ciclo el Panel no espera
  con o sin el desarme. Desarmar ahí es la regla que ya existía —«la entrada se consume cuando el motor ya no trae
  nada»—, igual que con el primer tirón hecho o el attest terminal. Justo después de «Empezar» hay sesión, así que
  `.idleSignedOut` no cuenta y el motor no está en `.stoppedUntilSignIn` (solo se llega ahí desde `.running` con la
  sesión caducada). Con el motor trayendo datos, el esqueleto sigue saliendo (lo fija
  `afterEmpezar_withSomeAccounts_waitsForTheFirstPull`, ahora con el motor fijado en «no espera iniciar sesión»).
  Arreglo: el literal pasa a la condición nueva; además exige que `waitsForSignIn` salga de
  `accountDataWaitEngineWaitsForSignIn()`, que llegue a `next(...)` y que el desarme exista en un solo sitio. Y un caso
  de comportamiento nuevo, `afterEmpezar_engineWaitsForSignIn_consumesTheEntry`: con la entrada armada y el motor
  esperando la sesión, el Panel sale en el acto y la entrada queda consumida.
- Asumido: el test del Panel fija `accountDataWaitEngineWaitsForSignIn` con un stub, en vez de leer
  `CloudSyncRuntime.shared`, para que no dependa de lo que otra suite dejó en el singleton.
- No se toca código de la app: no se revierte nada de Vaciar datos, Eliminar cuenta, primeros pasos ni del esqueleto.

## Verificación

Ver el cuerpo del PR y el cierre de la sesión.
