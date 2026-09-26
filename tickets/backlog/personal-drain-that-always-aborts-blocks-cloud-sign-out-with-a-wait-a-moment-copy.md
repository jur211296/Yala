---
id: personal-drain-that-always-aborts-blocks-cloud-sign-out-with-a-wait-a-moment-copy
status: backlog
priority: low
area: "modo-nube, sync, copy"
created: 2026-09-26
updated: 2026-09-26
source: "review adversarial de `personal-sign-out-reads-an-unfinished-drain-as-nothing-pending` (2026-09-26, lente del cierre)"
---

# Si el teléfono no consigue guardar nunca, cerrar sesión en la nube dice «espera unos segundos» para siempre

## El problema, en lenguaje de usuario

Muy raro. Si este teléfono no consigue guardar un cambio tuyo para subirlo —siempre, no una vez—, cerrar sesión en la nube
te dice «Un momento más… espera unos segundos y vuelve a intentarlo» cada vez, y esperar no lo arregla. Si además el
teléfono no tiene App Attest, desaparece la opción de cerrar sesión perdiendo esos cambios.

## Por qué pasa (leído el 2026-09-26; inferido, no ejecutado)

- Desde `personal-sign-out-reads-an-unfinished-drain-as-nothing-pending`, el push-all del cierre en la nube relee el History
  tras cada ciclo: lo que el drain no capturó bloquea, en vez de dejar que el borrado se lo lleve. Da vueltas hasta el tope
  y bloquea con `.transient`.
- Si el drain aborta en TODAS las vueltas —un `save` del outbox que falla siempre, un reloj por unidad o un testigo que no
  se deja leer (`RelayTombstoneReadFailure`)—, el cambio no llega nunca al outbox y cada intento acaba igual. El texto de
  `.transient` promete segundos.
- El teléfono sin App Attest: la sonda convierte su `.attestUnavailable` en `.transient`, a propósito (no se puede aceptar
  perder lo que el aviso no enseña). Con un drain que nunca termina, eso quita la salida de pérdida para siempre.
- `CloudSyncRuntime.performCycle` descarta el `Bool` de `drainOnce` (paso 1). Guardarlo como testigo del ciclo, como
  `lastCycleFailedUpload`, permitiría separar este caso con su propio motivo.

## Por dónde va

Un testigo del ciclo «el drain no terminó» (bajado al entrar en cada ciclo, leído CON el outcome, como los otros dos) y,
con él, un motivo y un texto propios que no prometan segundos. Decidir con Jürgen si el teléfono sin App Attest debe tener
alguna salida en ese estado (hoy: ninguna, y tampoco la tenía el gemelo de Grupos).

## Criterios de aceptación

- [ ] Con un drain que aborta en todas las vueltas, el aviso no dice «espera unos segundos».
- [ ] El caso pasajero (algo escrito tras el drain) sigue curándose solo con otra vuelta.
