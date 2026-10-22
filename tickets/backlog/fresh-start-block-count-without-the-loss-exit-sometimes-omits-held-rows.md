---
id: fresh-start-block-count-without-the-loss-exit-sometimes-omits-held-rows
status: backlog
priority: low
area: "grupos, copy"
created: 2026-10-05
updated: 2026-10-08
source: "medido al implementar `fresh-start-copy-for-another-accounts-group-changes-borrows-the-own-reason` (2026-10-05)"
---

# Sin la salida de perderlos, la cifra de «Empezar de cero» a veces cuenta las filas de otra cuenta y a veces no

## El problema, en lenguaje de usuario

Cuando «Empezar de cero» se para por un motivo pasajero (inténtalo en un rato, espera unos segundos, los grupos en pausa) y
hay cambios de grupos de otra cuenta guardados como filas del outbox, la cifra del aviso puede no incluirlos aunque el
borrado se los llevaría. No se pierde nada (ese aviso no deja borrar) y el intento siguiente, cuando los tuyos han subido,
sí los cuenta y ofrece perderlos. Lo que falla es la cifra de ese primer aviso.

## Lo medido (leyendo el árbol de `088f4e43f`)

- La cifra de la subida sin salida es la del push-all (`freshStartBlock(for:)`) más las entradas del espejo de otra cuenta
  (`freshStartBlockCountingAnotherAccount`). Las filas retenidas de otra cuenta (`liveRowsHeldForAnotherAccount`) no se
  suman ahí.
- Y la cifra del push-all no es siempre la misma cosa: con un ciclo que falla es lo que la sesión puede subir
  (`uploadableAfterHeld`, sin las retenidas); con la quiescencia que no llega, el bucle agotado o la re-captura que no
  terminó es el outbox entero (`liveGroupsPendingCount`, con las retenidas).
- Desde el 2026-10-05 el aviso separa «tuyos» de «apuntados con otra cuenta», y la parte de otra cuenta en este camino es
  la del espejo. En los caminos donde la cifra del push-all trae las retenidas, esas cuentan como «tuyas».

## Por dónde va

Que la cifra de este bloqueo sea siempre «lo tuyo que no subió + todo lo de otra cuenta (filas retenidas y espejo)», y la
parte de otra cuenta, esa misma suma. Cambia la cifra total, por eso no entró en el ticket padre («no cambies qué se
cuenta»). Requiere decidir si la cifra del cierre de sesión debe cambiar igual (comparte el push-all).

## Medido en 2.1 (triage 2026-10-08)

- `CloudSessionSignOut.freshStartBlockCountingAnotherAccount` suma solo `mirrorPendingOfAnotherAccount` a la cifra total; las filas retenidas (`heldForAnotherAccount`) siguen fuera, y su docblock cita este ticket como el pendiente.
- Lo que sí cambió en `e403c93c2`: con alguna fila retenida, la parte «de otra cuenta» sale `Int.max` y el aviso no parte la cifra en «tuyos» y «de otra cuenta». La cifra total sigue siendo la que este ticket describe.
- No hay pérdida: este camino no ofrece borrar.

Triage 2026-10-08: abierto · low → low · la cifra total del bloqueo pasajero sigue sin sumar las filas retenidas de otra cuenta; ya no las llama tuyas, pero el número sigue variando según el camino.
