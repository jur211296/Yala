---
id: adopt-over-a-device-already-in-cloud-mode-has-no-exit
status: done
area: cloud-sync
priority: high
created: 2026-10-28
updated: 2026-11-13
card: tablero-fallos-altos-hoja-de-exito-en-blanco-al-hq7p
source: S12h (card pet5) — telemetría del iPhone de Jürgen, 27-oct
---

# Un adopt sobre un teléfono que ya está en `.cloud` se queda pendiente para siempre, invisible y sin salida

## Qué pasa (medido)

Telemetría `yala_metrics`, instalación `bf3f7909`, 27-oct (hora Lima):

- 20:56:21 `register cloud bornCloud`: el alta creó una cuenta nueva y arrancó el motor en sesión (`.bornCloudReady`).
- 20:56:38 `cloudSyncIdentityGapObserved ExchangeRate` ×9: el motor ya corría en `.cloud` y subía borrados.
- 20:56:47–49 `cloudMigrationStep consent>auth>claim>notStarted`: un segundo alta del mismo teléfono recibió
  `existing_stable` de esa misma cuenta y el Welcome arrancó `startAdoptWithExistingSession`.
- 20:57:29 `cloudAdoptLineageBlocked noSharedRows|quiet`, y silencio.

Con el modo persistido ya en `.cloud`:

- `CloudMigrationUIStateDeriver.derive` da `.cloudActive` (notStarted + `.cloud`) y el Welcome lo pinta como
  `.signUpEnteredExistingAccount`: «Ya tenías una cuenta». Se entra sin onboarding (`onAdoptStarted` lo marcó hecho),
  sin cuentas ni categorías.
- `AdoptEffectScope.isPending` es falso con `.cloud` → sin «Cancelar».
- `observeAdoptEffectFailure` sale antes del canario y del reloj con `.cloud` → sin techo; el efecto se reintenta en
  cada `resume` (arranque, primer plano, cada 30 s en Almacenamiento).

## Lo que ya cierra S12h

El disparador medido —el alta que vuelve a pedir la cuenta que este teléfono creó y en la que sigue— ya no adopta:
`AccountClaimDecision.bornCloudReclaimState` lo devuelve al alta. Queda sin cubrir cuando el sello del claim se
olvidó (un «Empezar de cero» del Welcome que purga grupos arma `CloudSessionRetirement`, que hace `forgetAllClaims`)
pero el modo sigue en `.cloud`.

## Qué falta decidir

1. ¿Puede `startAdoptWithExistingSession` arrancar con el modo persistido en `.cloud`? Lo natural es que no (adoptar
   es pasar de iCloud a la nube), pero rechazarlo deja el motor corriendo con el sello nuevo sobre lo que quede en
   local, que es justo lo que la guarda de linaje del adopt protege.
2. ¿Debe un «Empezar de cero» del Welcome que retira la sesión de nube devolver también el modo a `.icloud`? Hoy deja
   `.cloud` + `mirrorOffArmed` + `bornCloud` sin sesión.
3. Medirlo antes: no hay reproducción en simulador (Google + backend). Un canario cuando un adopt se journalea con
   `.cloud` persistido diría cuántas veces pasa en la flota.

## Espera decisión de Jürgen (2026-11-12, lote de fallos altos)

Medido en el código de `2.3` (84dea882c): el disparador que queda sigue vivo. «Empezar de cero» del Welcome
(`ContentView`, las dos ramas que purgan Grupos) retira la sesión de la nube y olvida los sellos del claim
(`CloudSessionRetirement.arm` → `forgetAllClaims`), pero **no devuelve el modo a `.icloud`**: solo lo hace el borrado de
«Cerrar sesión» (`SwiftDataConfiguration`, que escribe `.icloud` y quita `mirrorOffArmed`). Volver a entrar con la misma
cuenta da `existing_stable`, arranca el adopt y queda pendiente sin «Cancelar» ni techo, porque las dos exclusiones de
`.cloud` (`AdoptEffectScope.isPending`, `observeAdoptEffectFailure`) no distinguen «el adopt escribió `.cloud`» de
«`.cloud` ya estaba».

**La pregunta:** ¿qué salida tiene quien entra con su cuenta en un teléfono que sigue en modo nube tras «Empezar de cero»?

- **A (recomendada):** cerrar el origen y no adoptar sobre la nube. «Empezar de cero» en un teléfono en la nube lo deja
  como recién instalado por el mismo camino que «Cerrar sesión» (modo iCloud, en el arranque o en el cambio de almacén);
  y de cinturón el adopt no arranca con `.cloud` ya puesto: con la misma cuenta entra directo, con otra para y lo dice.
  Con un canario para ver si alguien seguía cayendo. No pierde datos: el borrado ya lo pidió la persona y lo de la nube
  sigue en su cuenta.
- **B:** darle al adopt sobre la nube «Cancelar» y el techo de 72 h, marcando al empezar si `.cloud` ya estaba. Más
  pequeño, pero al salir el teléfono queda en la nube sin sesión ni datos, y volver a entrar vuelve a adoptar.
- **C:** solo el canario y decidir con cifras de la flota. No arregla nada hoy.

Lo que no se tocó a propósito: ningún cambio de código en el adopt hasta la respuesta (el encargo pide no elegir la
salida de producto).

## Resuelto (2026-11-13, opción A de Jürgen)

Jürgen eligió la A en el comentario de la card (13-nov, 06:11).

- **El origen.** Las tres salidas del Welcome que, tras «Empezar de cero», abrían el onboarding privado
  (`startFreshPrivateOnboarding` sin datos, el relanzamiento del espejo con destino `.privateOnboarding` y el alert de datos
  existentes de `ShellDataAlertsModifier`) miran el modo persistido. Con `.cloud`, en vez de abrir el onboarding llaman a
  `CloudSessionSignOut.armReturnToFreshInstallAfterWelcomeFreshStart`: el cierre local de «Borrar mi cuenta» en la nube sin
  borrar la cuenta. Arma el borrado del arranque (archivos fuera, par a `.icloud`, neutro armado, preferencias de
  instalación nueva, sesión retirada) y lo consuma en caliente con el cambio de contenedor; si el montaje no lo admite,
  «reabre Yala». La persona aterriza en el Welcome de un teléfono recién instalado. No se escribe `.icloud` en caliente:
  sobre el archivo de la época nube, el espejo reproduciría su History hacia iCloud.
- **El cinturón.** La entrada a una cuenta del Welcome, antes del guard cross-cuenta, no adopta con el modo en `.cloud` sin
  el sello de esa cuenta: va a la pantalla de bloqueo de siempre, que vuelve al elector, y desde ahí «Empezar de cero» ya
  devuelve el teléfono a recién instalado. Con el sello de esa cuenta sigue como antes. Canario `adoptOverCloudRefused`.
- **El borrado se arma síncrono** (`armReturnToFreshInstallAfterWelcomeFreshStart`) antes de cerrar el Welcome, y el resto
  (parar el motor, soltar la sesión, el cambio en caliente) va después (`finish…`). Lo pidió la review adversarial: armado
  tras las esperas de red, un cierre de la app en ese hueco reabría el onboarding sobre la nube. Con el coordinador
  ocupado no se toca el Welcome.
- **Lo que no se tocó:** `AdoptEffectScope.isPending` y `observeAdoptEffectFailure` siguen excluyendo `.cloud` (la opción B,
  descartada). El store de Grupos no se marca en este borrado: el relevo ya purgó sus filas.
- **Pruebas:** `YalaTests/AdoptOverCloudGuardTests` (regla y cableado de las tres salidas y del cinturón; caen sin el
  arreglo). La reproducción entera pide Google y el backend, que el simulador no firma.

### Residuales que la review dejó a la vista (no se tocan aquí)

- **Borrar filas con el motor de la nube vivo.** En un teléfono en `.cloud` con sesión y el motor corriendo, el borrado de
  filas de «Empezar de cero» (el alert y la puerta privada) va antes de este cierre; si un drain recoge esos borrados,
  suben a la cuenta. Ya pasaba antes de este cambio, y en el caso medido (un alta nube recién hecha) la cuenta es la misma
  que se está descartando. Inferido, sin medir.
- **El texto del bloqueo del cinturón** es el de «datos de otra cuenta»: un teléfono en la nube sin filas lo lee igual. La
  salida existe (Volver → «Empezar de cero»), pero el copy no la cuenta. Un texto propio pide 16 idiomas.
- **Grupos que conservó el aviso tardío con el modo en `.cloud`:** el borrado del arranque retira la sesión y el
  consentimiento de Grupos. No verificado que sea alcanzable.
