---
id: private-exit-loses-unmaterialized-inbound-captures
status: done
updated: 2026-09-26
priority: medium
area: "settings, inbox, modo-nube"
created: 2026-09-11
source: "review adversarial del paso 9 (`session-exits-one-verb-per-session`), lente de pérdida de datos; la sesión de la mitad 2 del paso 5 midió lo mismo desde su puerta"
---

# Un pago de Apple Pay o un gasto dictado a Siri se pierde si cierras sesión antes de que Yala lo convierta en borrador

## El síntoma, en lenguaje de usuario

Pago con Apple Pay, la automatización lo manda a Yala, y antes de abrir la bandeja cierro sesión en mi
sesión privada. La hoja me dice que mis datos siguen en iCloud y que antes se sube lo pendiente. Al
restaurar, ese pago no está: nunca llegó a ser un movimiento, así que nunca subió.

## Lo medido (2026-09-11, en este árbol)

- Las capturas de Apple Pay, Siri y las imágenes compartidas esperan en colas del App Group hasta que la app
  las materializa (`ApplePayPendingStore`, `SiriPendingStore`, `SharedContainerService`). No pasan por
  SwiftData, así que no están en iCloud.
- El boot-wipe del cierre las purga (`AppGroupInboundPurge.purgeInboundSurfaces()`, dentro de
  `SwiftDataConfiguration.performSignOutWipeIfArmed`). Es la frontera correcta de PRIVACIDAD —lo que capturó la
  cuenta saliente no puede aparecer en la entrante—, pero en la sesión privada la persona que vuelve suele ser
  la misma.
- La espera del export (`PersonalExportPendingCounter`) solo mira el historial del store: estas capturas no
  cuentan, así que el aviso de la salida de emergencia tampoco las nombra.
- Con el wipe ya armado en `.icloud`, el handler de cambios remotos de `AppBootstrapper` sigue drenando esas
  colas hacia el store que el arranque va a borrar: solo `handleBecameActive` mira `isSignOutWipeArmed()`.
  Antes del paso 9 eso solo era alcanzable desde `.cloud`.

## Lo que se espera

- En el cierre privado, materializar las colas del App Group ANTES de la espera del export, para que viajen
  como cualquier otro cambio y el contador las vea.
- El mismo guard `isSignOutWipeArmed()` en el drenaje del handler de cambios remotos.

## Criterios de aceptación

- [x] Una captura pendiente en la cola se convierte en borrador antes de que el cierre privado cuente lo pendiente.
- [x] Con el wipe armado, ningún camino drena las colas al store condenado (test de las dos direcciones).
- [x] El cierre de la nube y la frontera M1 siguen purgando sin materializar.

## Hecho (2026-09-26)

- **Cada recuento del cierre privado que espera al export** (la espera, el re-aviso de «Cerrar sesión igualmente» y
  el recuento pegado al arm) convierte antes en borrador lo que espera en las colas de Apple Pay y Siri
  (`InboundCaptureDrain.forSignOut` + `PrivateSignOutExportGateLogic.pendingCountMaterializingInbound`). El borrador
  viaja a iCloud como cualquier cambio.
- **Lo que no se puede convertir** (import de iCloud activo, `save()` que falla) cuenta como pendiente: la espera no
  confirma cero y, si se agota, el aviso lo incluye en la cifra.
- **Un solo escritor drena las colas**: `InboundCaptureDrain.drain`, con el guard `isSignOutWipeArmed()` dentro. Pasan
  por él el arranque, la vuelta a primer plano y el final de una ráfaga de cambios remotos. Un source-scan fija que
  nadie más llama a `processPending`.
- **La caché sin ancla de la espera** se tira también cuando la cola encoge (un drenado de primer plano durante la
  espera).
- **Fuera, a propósito**: las imágenes compartidas (no se convierten solas: piden a la persona, el análisis y su
  consentimiento; el original sigue en su app y caducan a las 24 h); los cierres que no esperan al export («sin
  copia», F sin espejo, pérdida aceptada sin cifra), donde no hay a dónde subir; la nube y M1.
- **Residual**: lo capturado DESPUÉS del arm (sesión ya cerrada, esperando relanzar) lo purga el arranque. Es la
  frontera de privacidad.
- Tests: `YalaTests/CloudSync/PrivateExitInboundCaptureTests.swift` (lógica pura, integración con historial en disco
  y el servicio de Apple Pay real, cableado). Mutantes y review adversarial en el PR.
- Hallazgos de la review con ticket propio: `private-exit-export-wait-cached-zero-misses-outside-writes`,
  `private-exit-warning-recounts-materialized-captures`, `private-exit-materialized-drafts-do-not-refresh-the-inbox`.

## Por qué no hay device-QA

Un guion en iPhone no distinguiría este build del anterior. Al abrir Yala para cerrar sesión, la vuelta a primer
plano ya convierte la cola en borrador si el import de iCloud está quieto, y eso pasaba igual antes. El caso que se
perdía es la captura que el import obliga a diferir, y no hay forma de forzar un import activo a mano. Ese caso lo
fijan los tests de integración (import activo → la captura cuenta como pendiente; import quieto → borrador y
recuento). La espera del export contra iCloud real ya está en el device-QA de `session-exits-one-verb-per-session`.
