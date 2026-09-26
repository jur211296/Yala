---
id: cloud-sign-out-final-recount-misses-edits-left-only-in-history
status: backlog
priority: low
area: "modo-nube, sync"
created: 2026-09-26
updated: 2026-09-26
source: "`personal-sign-out-reads-an-unfinished-drain-as-nothing-pending` (2026-09-26), al buscar todas las instancias del patrón"
---

# Cerrar sesión en la nube: el último recuento no ve un cambio que llegó después de la subida

## El problema, en lenguaje de usuario

Casi nunca pasa. Si guardas un cambio en el instante exacto entre que Yala termina de subir tus datos y cierra la sesión,
ese cambio no sube y el cierre borra el teléfono con él dentro.

## Por qué pasa (leído el 2026-09-26; inferido, no ejecutado)

- El paso 4 del cierre en la nube (`CloudSessionSignOut.performCloudSecureSignOut`, re-verificación «S2» tras el
  teardown) vuelve a contar las dos colas antes de soltar la sesión, pero solo cuenta **filas del outbox**
  (`controller.livePendingUploadCount()`). Tras el teardown no corre ningún drain, así que un cambio guardado entre el
  push-all y ese recuento vive solo en el History y el recuento da 0.
- Su propio comentario ya lo dice: «Residual documentado: writes que queden solo en History (sin drain post-teardown)
  mueren con el wipe». Es la misma forma que cerró `personal-sign-out-reads-an-unfinished-drain-as-nothing-pending` en el
  paso 1: el outbox a 0 no prueba que no quede nada.
- La ventana es corta (del final del push-all al recuento, con el teardown y el desregistro del push token en medio, que
  tiene un `await`), y la pantalla del cierre está delante. Por eso es `low`.

## Por dónde va

En la re-verificación del paso 4, leer también la sonda del History (`CloudSyncEngine.hasUncapturedPersonalChanges`,
solo lectura; desde el 2026-09-26 lee la misma ventana que el drain). `true` o `nil` ⇒ bloquear con la sesión aún viva,
como ya hace con filas vivas. Ojo: tras `teardownGuestSession` hay que comprobar que `CloudSyncRuntime.shared` sigue
existiendo para poder preguntar, o exponer la sonda sin el runtime.

## Criterios de aceptación

- [ ] Con una edición guardada tras el push-all y antes del recuento, el cierre bloquea sin borrar.
- [ ] Sin nada pendiente, el cierre no cambia.
