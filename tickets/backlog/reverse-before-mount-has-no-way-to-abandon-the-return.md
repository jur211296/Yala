---
id: reverse-before-mount-has-no-way-to-abandon-the-return
status: backlog
updated: 2026-09-21
priority: medium
area: "modo-nube, migración"
created: 2026-09-17
source: "review adversarial de `reverse-before-mount-stays-stuck-with-an-expired-session` (2026-09-17), lente de la máquina — hallazgos 1 y 2"
---

# Las cuatro fases previas al montaje de «Volver a iCloud» no tienen forma de abandonar

## El problema, en lenguaje de usuario

Empecé a volver a iCloud y algo no deja terminar: el servidor dice que otro de mis dispositivos ya la lleva, mi cuenta
está suspendida, o perdí el acceso a la cuenta con la que la empecé. La barra se queda donde está y no hay ningún botón
para dejarlo: ni «Cancelar y seguir en la nube», ni «Reintentar». Y mientras tanto **mis movimientos no suben a ningún
sitio**, porque con esa fase journaleada el motor de la nube no arranca.

## Por qué pasa (medido el 2026-09-17)

Las cuatro fases previas al montaje del espejo salen **solo por éxito**:

| Fase | Única salida | Qué pasa con lo demás |
|---|---|---|
| `reverseClaimLeader` | `.reverseLeaderClaimed` | tiene salida al origen para el rechazo (ticket hermano, cerrado) |
| `reverseDrainAll` | `.reverseDrainCompleted` | todo lo demás corta sin evento |
| `reverseVerify` | `.reverseVerifyOutcome` | degradaba a `reverseFailedRollback` al agotar el presupuesto de RED |
| `reverseFreezeBackend` | `.reverseBackendFrozen` | `otherLeader` y `rejected` cortan sin evento |

Y la tarjeta de progreso **no ofrece cancelar en ninguna**: `cancelReverseButton` está gateado por
`isWaitingReverseUpload`, que es `journaledPhase == .reverseUpload`.

**Lo que cambió el 2026-09-17, y hay que decirlo entero:** `reverse-before-mount-stays-stuck-with-an-expired-session`
quitó la única degradación automática que quedaba —la de `reverseVerify` por sesión caducada— porque su criterio 3 lo
pedía: ese terminal llegaba con `.reverseRollback` pendiente, un efecto que con la sesión caducada **lanza en cada
resume**, así que ni el terminal ni su «Reintentar» funcionaban. O sea: **no es una regresión de desenlace** (el
terminal ya estaba roto), pero sí cierra la última puerta sin abrir otra.

Los tres motivos que llegan aquí y que esperar NO arregla:

- **`otherLeader` / `rejected` en el freeze.** El lease de la vuelta dura 60 minutos y **ninguna de las cuatro fases
  paradas late** (`sendLeaseHeartbeatIfDue` tiene tres call-sites y ninguno cubre una fase parada). Quien vuelve dos
  horas después puede encontrarse con que otro dispositivo suyo hizo takeover.
- **`.accountUnavailable` (403, cuenta suspendida)** en el drain y en el verify: se lee como red a propósito —no es una
  sesión que renovar— y ahí se queda.
- **Una cuenta a la que ya no se puede entrar** (borrada, acceso perdido): la tarjeta pide volver a entrar y no se puede.

## Qué habría que decidir

1. **Qué ofrece la salida.** Volver al origen en modo nube, como hace la salida de la espera de `reverseUpload`, con
   `[.rearmMirrorOff, .reverseRollback]`. Pero `reverse_abort` necesita sesión: sin ella el efecto queda pendiente y
   lanza en cada resume — el bug-class que este ticket describe, con otro nombre.
2. **Si la salida es automática (un techo, como el de `reverseUpload`) o un botón**, o las dos. Un techo protege a
   quien no está delante; un botón, a quien sí.
3. **Qué se le dice**, con el molde de `ReverseAbortReason` y `L10n.Storage.ReverseAbort.note(for:)`, que ya tiene tres
   motivos y su sitio en la tarjeta.

## Criterios de aceptación

- [ ] Decidido 1, 2 y 3 antes de tocar código.
- [ ] Ninguna de las cuatro fases puede quedarse sin salida indefinidamente con el motor de la nube parado.
- [ ] Un `reverse_abort` que no puede salir (sin sesión) NO deja un efecto pendiente que lance en cada resume.
- [ ] Tests por motivo, con mutante.

## Relacionado

- `reverse-claim-rejection-has-no-way-out-in-the-client` — el molde: la salida al origen sin efectos.
- `reverse-upload-has-no-ceiling-and-no-exit` — el molde del techo y del botón de cancelar, post-montaje.
- `reverse-before-mount-stays-stuck-with-an-expired-session` — el que cerró el caso de la sesión caducada y midió esto.

## Decisión Jürgen (2026-09-21)

**Salida completa:** techo automático **y** botón de cancelar.

- **Qué hace la salida:** rollback al origen en modo nube, molde de la salida de espera de `reverseUpload` / rechazo de claim — sin dejar `reverse_abort` pendiente que dispare en cada resume si no hay sesión.
- **Copy:** molde `ReverseAbortReason` + `L10n.Storage.ReverseAbort.note(for:)`.
- Listo para implementar cuando la cola A lo tome (serie; no adelantar a `force-fetch` en curso).

