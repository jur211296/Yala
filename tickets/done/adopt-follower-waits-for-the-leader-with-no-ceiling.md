---
id: adopt-follower-waits-for-the-leader-with-no-ceiling
status: backlog
priority: medium
area: "modo-nube, migración, adopt"
created: 2026-09-23
updated: 2026-09-23
source: "Paso 0 de `adopt-claim-stays-parked-with-no-ceiling` (2026-09-23): la otra fase que reclama para un adopt"
---

# Si entras en tu cuenta mientras otro teléfono la está activando, la espera no tiene fin si tu cuenta deja de estar disponible

## El problema, en lenguaje de usuario

Entro en mi cuenta de la nube en un segundo teléfono justo cuando el primero la está activando. Yala me dice que espera
a que el otro termine («esperando a otro dispositivo»). Si en ese rato mi sesión se borra o la cuenta contesta que no me
deja entrar, la espera sigue igual para siempre: no hay aviso, ni techo, ni botón para salir.

## Por qué pasa (leído el 2026-09-23 en este árbol; no ejecutado)

`MigrationRunner.pollLeaderInternal` reclama en `waitingForLeader`. Con `.sessionExpired` y `.accountUnavailable` solo
apunta `lastClaimBlocker` y devuelve sin evento; con `.transient`, igual. La fase `waitingForLeader` no está en
`ForwardStepPhase`, así que el techo que `adopt-claim-stays-parked-with-no-ceiling` le puso al claim del adopt no la
cubre, y `ForwardCancelScope` no ofrece «Cancelar» ahí. En Almacenamiento la tarjeta es `waitingCard()`, sin botones.
Mientras el Welcome está delante, su poll sí lo ve (`CloudWelcomeSignInFlow.phase` → `.accountBlocked` / `.error`); al
salir, no.

**Y un «Cancelar» que se pierde** (lente de consumidores de la review, medido): desde el 2026-09-23 el claim del adopt
ofrece «Cancelar la activación». Si la persona lo confirma con el claim en vuelo y el claim contesta `claiming_in_progress`,
la fase pasa a `waitingForLeader`, `journalMigrationCancel` no la ofrece y retira el «sí»: la persona confirmó cancelar y
aterriza en la tarjeta de espera, sin botón.

## Qué habría que decidir

1. ¿Techo para `waitingForLeader`? El seguidor espera a un líder que puede tardar horas con un corpus grande, así que el
   plazo largo no puede ser el de los pasos (72 h sin avanzar podría ser corto o largo según el líder).
2. ¿«Cancelar» ahí, con la salida de la marca `adoptClaimExitRaw` (vuelve a «Activar la nube en este dispositivo»)? Si
   sí, cierra también el «sí» que hoy se pierde.

## Criterios de aceptación

- [ ] Un seguidor con la sesión borrada o un 403 persistente no se queda en `waitingForLeader` para siempre.
- [ ] Test con el fallo persistente, midiendo que la fase cambia.

## Relacionado

- `adopt-claim-stays-parked-with-no-ceiling` — el mismo hueco en el claim del adopt (22 %), cerrado.
- `adopt-uploads-a-foreign-corpus-without-a-lineage-check` — el otro problema del seguidor.
