---
id: debug-panel-shows-a-counter-the-reverse-no-longer-moves
status: backlog
priority: low
area: "modo-nube, migración"
created: 2026-09-21
updated: 2026-09-21
source: "review adversarial de `reverse-pre-mount-ceiling-has-no-alert-and-leaves-network-verify-out` (2026-09-21), lente de la máquina"
---

# El panel DEBUG enseña el contador de red que la vuelta ya no mueve, y no enseña el reloj que lo sustituye

## El problema

`CloudSyncDebugView` pinta:

```
mismatch <n> · red <n> · leader <id> · seqCut <n>
```

Desde el 2026-09-21 la vuelta a iCloud no escribe `verifyNetworkRetries` en ninguna de sus fases: su red, su sesión
caducada y el `blocked` del servidor pasan por el techo de la etapa. Así que durante una vuelta atascada por red ese
campo se queda en **0** para siempre, y quien diagnostique desde el panel concluye que no ha habido ningún problema de
red.

Y lo que sí lo describe —`reversePreMountProgressAt` y `reversePreMountPhaseRaw`, el reloj del techo y la fase en la que
se selló— **no se pinta en ninguna parte** (grep de `reversePreMount` en `CloudSyncDebugView.swift`: cero).

O sea: en el único sitio on-device donde se puede mirar qué le pasa a una vuelta parada, se perdió la señal que había y
no se ganó la nueva.

## Qué hace falta

- Pintar el reloj del techo y su fase, y cuánto lleva parada (el mismo cálculo que hace `observeReversePreMountStall`).
- Decidir si `red` sigue teniendo sentido en la etiqueta cuando el journal está en una fase de vuelta, o si ahí debe
  decir otra cosa.

No es producción —el panel vive tras `DEV_BUILD`— pero es la herramienta con la que se diagnostica en device, y el
device-QA de los tickets de la vuelta se apoya en ella.

## Criterios de aceptación

- [ ] Con una vuelta parada en una de las cuatro fases previas al montaje, el panel dice en cuál y desde cuándo.
- [ ] La etiqueta no afirma «red 0» de una vuelta que lleva parada por red.

## Relacionado

- `reverse-pre-mount-ceiling-has-no-alert-and-leaves-network-verify-out` — el que dejó el contador quieto.
- `reverse-before-mount-has-no-way-to-abandon-the-return` — el que introdujo el reloj que falta por pintar.
