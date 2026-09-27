---
id: private-exit-warning-recounts-materialized-captures
status: backlog
priority: low
area: "settings, modo-nube"
created: 2026-09-26
source: "review adversarial de `private-exit-loses-unmaterialized-inbound-captures` (lentes de pérdida de datos y de efectos colaterales)"
---

# El aviso del cierre privado puede volver a salir con otra cifra al tocar «Cerrar sesión igualmente»

## Qué pasa, en lenguaje de usuario

El aviso dice «1 cambio sin subir». Toco «Cerrar sesión igualmente» y vuelve a salir diciendo «2». El segundo toque
cierra. No se pierde nada callado; es una confirmación de más.

## Lo medido (2026-09-26)

- Una captura que no se pudo convertir en borrador (import activo) cuenta como una ENTRADA de cola
  (`InboundCaptureDrain.queuedCount`).
- Al convertirse, cuenta lo que diga el historial: un dictado de Siri con varias transacciones da varios borradores
  (`SiriDraftService.processPending`), y el historial cuenta objetos.
- `exitDiscardingUnconfirmed` y `armAfterCredentials(.acceptLoss(upTo:))` comparan contra la cifra enseñada y
  vuelven a avisar si hay más.

## Lo que se espera

Que la cifra de una captura en cola se parezca a la que dará convertida (p. ej. contar las transacciones de Siri), o
que la comparación no cuente como «nuevo» lo que ya estaba en la cola del aviso.
