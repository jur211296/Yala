---
id: cloud-onboarding-offers-the-cloud-to-a-phone-without-app-attest
status: qa
priority: low
area: "modo-nube, attest, onboarding"
created: 2026-09-15
updated: 2026-09-16
source: "hallazgo de `cloud-phone-without-app-attest-cannot-sign-out-with-personal-changes` (2026-09-15)"
---

# La puerta que no ofrece la nube a un teléfono sin App Attest no está conectada a nada

## El problema, en lenguaje de usuario

Mi teléfono no tiene App Attest. Elijo «Tu cuenta en la nube» al empezar, uso la app con normalidad y nada de lo que apunto
llega nunca a mi cuenta: el motor corta en su puerta de attest antes de subir.

## Lo medido (leído en el código, sin ejecutar)

- `AttestSyncGate.shouldOfferCloudOnly(isAttestSupported:)` existe desde I7b (`c56dcd772`, «DARK») con la decisión del owner
  de bloquear por adelantado, y **no tiene ni un solo llamador** en `Yala/`.
- Su docblock, y el de `classify` en el mismo fichero, afirman que ese caso «se caza antes, cuando la persona aún no ha
  elegido». Nada lo caza: el único lector de `DCAppAttestService.isSupported` fuera del cliente es el panel de depuración
  (`CloudSyncDebugView`).
- Desde el 2026-09-15 esa persona puede al menos cerrar sesión exportando y perdiendo lo que no subió
  (`cloud-phone-without-app-attest-cannot-sign-out-with-personal-changes`), pero solo tras un día sin App Attest.
- Sin medir: cuántos teléfonos reales tienen `isSupported == false`. El docblock lo da por «vanishingly rare» en hardware con
  iOS 26, sin cifra.

## Lo que hay que decidir

1. Conectar la puerta al Welcome: sin App Attest, no se ofrece la nube.
2. Retirar la función y corregir los docblocks, y aceptar que esa población entra y depende de la salida del cierre.
3. Medir antes cuántos teléfonos hay así.

## Relación con otros tickets

- `cloud-phone-without-app-attest-cannot-sign-out-with-personal-changes` — la salida que hoy es la única red.

## Decisión (encargo del 2026-09-16, sesión nocturna)

**Opción 1:** conectar la puerta al Welcome — sin App Attest no se ofrece la nube. Las decisiones de detalle, con su porqué,
están en el Paso 0 de `encargos/lanzados/2026-09-16-cloud-onboarding-offers-the-cloud-to-a-phone-without-app-attest.md`.

## Hecho el 2026-09-16 — opción 1

**Lo que cambia para la persona.** Un teléfono que no puede conseguir App Attest ya no ve «Tu cuenta en la nube»:

- En «Es mi primera vez» queda una sola opción, así que la app va directa a «Tu cuenta en tu iCloud privado», el mismo
  recorrido de cuando la nube está apagada. No hay texto nuevo.
- Lo mismo en «Crear otra cuenta» (la pantalla a la que lleva el faro) y en «Activar Yala completo» desde una sesión de solo
  grupos: las tres pantallas leen la misma puerta.
- **Con App Attest no cambia nada**: las dos tarjetas siguen ahí.

**Lo que NO cubre, y dónde quedó:**

- Entrar con una cuenta que ya existe («Ya tengo una cuenta» y el faro): es otra decisión, y lo que ve esa persona está en
  `cloud-hydration-spinner-never-gives-up-without-attest`.
- «Crear mi cuenta» tras «No encontramos una cuenta» y «Crear cuenta con…» del mismatch: también son altas, pero esconderlas
  vuelve pared dos pantallas que Jürgen decidió abrir → `cloud-sign-in-screen-offers-sign-up-to-a-phone-without-app-attest`.
- «Migrar a la nube» de Ajustes → `cloud-migration-offers-the-cloud-to-a-phone-without-app-attest`.
- Quien eligió la nube antes de este cambio sigue dependiendo de la salida de
  `cloud-phone-without-app-attest-cannot-sign-out-with-personal-changes`.
- Cuántos teléfonos caen en la puerta: sin medir, sin canario.

**Un efecto en el simulador, a propósito.** El simulador no tiene App Attest, así que sin `YALA_DEV_SHARED_SECRET` en el
scheme ya no ofrece «Tu cuenta en la nube». No se le exime: QA y producción deciden igual. El montaje del ticket hermano que
creaba la cuenta así está anotado en su ticket.

**Lo que se tocó.**

- `AppAttestClient.canObtainSessionToken`: la primera decisión de `performRefresh` en un booleano (`isSupported`, o en DEBUG
  el bypass con secreto). Un solo sitio define «tener App Attest».
- `AttestSyncGate.shouldOfferCloudOnly`: gana su llamador y pasa a `nonisolated`; sus tres docblocks dejan de mentir.
- `WelcomeAccountChoiceLogic.visibleNewOptions`: el término `isAttestSupported`; `WelcomeNewOptionsGate.live` lo alimenta.
- `UITestHooks.fakeAttestSupport` (`-uitest-fake-attest-support`): finge solo la entrada de la puerta, para los XCUITest que
  necesitan ver la card de la nube.
- `.claude/rules/gateway-attest.md`: la convención, en «La puerta del alta».

**Cómo se verificó.**

- Build ×2 (`Yala` y `Yala Dev`), sin warnings nuevos en lo tocado.
- **Unit: la suite entera, 7045 casos en 725 suites, 0 fallos** (12 omitidos, ninguno de este cambio).
- **XCUITest: 20 casos** de las áreas tocadas y de los dos ficheros del chooser, con el centinela del simulador en 0.
  Tres son la condición con el predicado real del simulador, sin el seam: «Es mi primera vez», «Crear otra cuenta» y
  «Activar Yala completo».
- **Mutantes: 14, todos cazados en su caso.** 11 en la lógica y los source-scans; 3 en XCUITest. La puerta viendo siempre
  App Attest pone rojos los tres negativos, y quitar el seam pone rojos los positivos y deja verdes los negativos: eso mide
  que en XCUITest el simulador de verdad no tiene App Attest.
- **Review adversarial de dos lentes** y la regla del área contra el diff. Cazó un scan que dejaba escapar el fallo caro
  —un término pegado detrás de la capacidad dejaba a todo iPhone sin la nube, con la suite en verde—, dos aserciones que
  no podían fallar, un docblock que afirmaba más de lo que cubre la puerta y «Crear otra cuenta» sin test. Arreglado todo;
  el detalle, en el PR.

## Device-QA — un solo paso, en iPhone real

Lo único que el simulador no puede probar: que un iPhone de verdad diga que tiene App Attest. Si no lo dijera, la nube
desaparecería para todos.

**Montaje.** Tu iPhone con un TestFlight que lleve este cambio (el primero después del merge del PR).

1. Borra Yala: mantén pulsado el icono → «Eliminar app» → «Eliminar app». Instálala otra vez desde TestFlight.
2. Abre Yala con conexión a internet y espera unos 10 segundos en la primera pantalla.
3. Toca «Empezar» → «Es mi primera vez».
   - Si aparece «Entra a tu cuenta» (tu Apple ID ya tiene una cuenta de Yala en la nube), toca «Crear otra cuenta».
   - **Esperado:** «Elige dónde quieres guardar tus datos» con las **dos** tarjetas: «Tu cuenta en la nube» y «Tu cuenta en
     tu iCloud privado».
   - Si sale otra pantalla (por ejemplo, la comprobación de iCloud): repite desde el paso 1 una vez más. Si vuelve a pasar,
     **FAIL**: este iPhone no está ofreciendo la nube.
4. No hace falta elegir nada. Cierra la app.
