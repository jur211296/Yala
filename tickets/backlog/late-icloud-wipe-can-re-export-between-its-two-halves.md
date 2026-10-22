---
id: late-icloud-wipe-can-re-export-between-its-two-halves
status: backlog
priority: medium
area: "modo-nube, onboarding"
created: 2026-09-10
updated: 2026-10-08
source: "review adversarial del paso 4 (`welcome-private-fresh-start-skips-icloud-check`), lente CloudKit"
---

# El borrado tardío del corpus de iCloud tiene dos mitades, y un kill entre ellas puede devolver los datos

## El síntoma, en lenguaje de usuario

Activo iCloud después de haber usado Yala en local. La app me avisa de que hay datos viejos míos en
iCloud y elijo «empezar de cero». Justo mientras borra, la app se cierra —una llamada, el sistema, un
cierre a mano—. La reabro y **mis datos viejos están otra vez ahí**.

## Lo medido (2026-09-10)

`ContentView.performICloudCorpusWipe` hace dos cosas en orden: borra la zona del mirror en CloudKit y
después borra las filas locales (`DataWipeService.wipeAllUserData`). Entre las dos hay una ventana de
segundos.

En el camino de la **puerta del Welcome** esa ventana está cubierta: el arm arma también el neutro
durable (`armNeutralMount`), así que el arranque siguiente monta sin espejo y nada re-exporta.

En el camino **tardío** ese guardarraíl es inerte por construcción: `shouldMountNeutralDurable` exige
`!hasShownWelcomeChooser`, y esta población ya salió del Welcome hace tiempo. Así que un kill entre las
dos mitades deja el corpus local ENTERO con el espejo VIVO, y `NSPersistentCloudKitContainer` —que ve la
zona borrada, resetea su metadata y re-exporta— vuelve a subirlo.

**No es pérdida de datos**: es reaparición, y la persona puede repetir el borrado (el arm sobrevive y el
aviso vuelve). Por eso es `medium` y no bloquea el paso 4.

## Por dónde va el arreglo

Lo natural es no borrar filas en ese camino: **borrar la zona y armar el boot-wipe de sign-out**
(`StorageModePersistence.armSignOutWipe`), que borra ARCHIVOS pre-mount y es kill-safe por construcción
— `performSignOutWipeIfArmed` ya tiene su orden idempotente y su banco de pruebas. Eso además quita el
`save()` durante un import, que hoy se evita esperando la quiescencia y rindiéndose si no llega.

Lo que hay que resolver antes: **cómo se pide el relanzamiento sin entrar en la máquina de
`CloudSessionSignOut`**. Hoy el único disparador del cover es `phase == .awaitingRelaunch`, y esa fase es
suya. Es la misma pieza que toca el paso 9 del rediseño (`session-exits-one-verb-per-session`), así que
lo sano es hacerlo ahí y no antes.

## Criterios de aceptación

- [ ] Matar la app entre las dos mitades del borrado tardío y reabrir → los datos viejos NO vuelven.
- [ ] El camino tardío no llama a `wipeAllUserData` con el espejo adjunto e importando.
- [ ] El de la puerta sigue funcionando igual (su ventana ya estaba cubierta).

## Nota del paso 9 (2026-09-11)

El paso 9 no resolvió «cómo se pide el relanzamiento sin entrar en la máquina de `CloudSessionSignOut`»:
los cierres privados nuevos entran en ella (`finalizeSessionExit` arma el boot-wipe y pone
`.awaitingRelaunch`, y el cover y la salida al pasar a segundo plano cuelgan de esa fase). Lo que sí deja es
el precedente de borrar por archivos un store CON espejo tras confirmar el export, y el abort del boot-wipe
en `.icloud` desarma en vez de reintentar (`SignOutWipeHookTests.baseDeleteFails_inICloudMode_…`).

## Medido en 2.1 (triage 2026-10-08)

- Ha mejorado: tras borrar la zona, `performICloudCorpusWipe` apunta `markICloudCorpusWipeZoneDone()` (`ContentView.swift:2261`). Con el arm puesto, el arranque siguiente reanuda el borrado (`.resume`, `ContentView.swift:2035`), y solo pregunta si ya no quedaba armado.
- Sigue pendiente lo de fondo. El camino tardío sigue llamando a `DataWipeService.wipeAllUserData` con el espejo adjunto (`ContentView.swift:2288`), y no existe un boot-wipe por archivos antes del mount. La reanudación corre con el espejo ya montado, así que la ventana de re-exportación sigue abierta. Criterios 1 y 2 sin cumplir.

Triage 2026-10-08: abierto · medium → medium · la reanudación al arrancar mitiga la reaparición, pero el borrado tardío sigue borrando filas con el espejo adjunto (`ContentView.swift:2288`) y no hay boot-wipe por archivos.
