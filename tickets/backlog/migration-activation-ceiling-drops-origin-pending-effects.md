---
id: migration-activation-ceiling-drops-origin-pending-effects
status: backlog
priority: low
area: "modo-nube, migración"
created: 2026-09-27
source: "decisión del Paso 0 de `migration-activation-drops-pending-effects-it-never-restores` (2026-09-27)"
---

# El techo del claim de «Activar la nube» tira los pendientes del origen

## El problema, en lenguaje de usuario

Vuelvo a iCloud sin conexión y la llamada que cierra la vuelta en el servidor se queda pendiente. Toco «Activar la nube»,
paso la comprobación de mi cuenta y el paso del 22 % se queda sin respuesta hasta su techo. La activación falla con
«Reintentar», y esa llamada pendiente ya no se reintenta nunca: la cuenta se queda en la nube a medio cerrar.

## Lo medido (2026-09-27)

- Desde `migration-activation-drops-pending-effects-it-never-restores`, «Activar la nube» guarda los pendientes del origen y
  los repone en toda vuelta a `notStarted` sin un claim contestado (`ForwardOriginPendingEffects`).
- La salida del techo del claim (`forwardStepStalled` vencido) y un `fatalError` van a `failedRollback`, y ahí se
  DESCARTAN, igual que la vuelta con su `fatalError` en `reverseClaimLeader`. Reponer ahí podía ejecutar un
  `.adoptBackendAccount` guardado dentro de un terminal de fallo, que deja `.cloud` persistido donde nadie lo espera.
- Es raro: para llegar al claim hace falta pasar la comprobación de la cuenta, que necesita red, y con red el
  `reverse_complete` pendiente ya drena en el `resume` del arranque o del primer plano.

## Qué se espera

Conservar lo guardado a través de `failedRollback` y reponerlo en la salida de esa fase («Reintentar»,
`resetAfterRollback` → `notStarted`), que es donde el teléfono vuelve a estar como antes del toque. Hay que excluir de
la limpieza S2 el campo compartido solo para la ida, y decidir qué hace `startAdoptWithExistingSession`, que llama a
`resetAfterRollback` antes de volver a tocar.

## Criterios de aceptación

- [ ] Con `.completeReverseServer` pendiente en `icloudActive`, activar, vencer el techo del claim y tocar «Reintentar»
      deja el pendiente en `notStarted`, y el siguiente `resume` lo ejecuta.
- [ ] Un `.adoptBackendAccount` guardado nunca se ejecuta en `failedRollback`.
