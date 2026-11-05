---
id: debug-panel-shows-a-counter-the-reverse-no-longer-moves
status: done
priority: low
area: "modo-nube, migración"
created: 2026-09-21
updated: 2026-11-05
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

- [x] Con una vuelta parada en una de las cuatro fases previas al montaje, el panel dice en cuál y desde cuándo.
- [x] La etiqueta no afirma «red 0» de una vuelta que lleva parada por red.

## Relacionado

- `reverse-pre-mount-ceiling-has-no-alert-and-leaves-network-verify-out` — el que dejó el contador quieto.
- `reverse-before-mount-has-no-way-to-abandon-the-return` — el que introdujo el reloj que falta por pintar.

## Medido en 2.1 (triage 2026-10-08)

- `CloudSyncDebugView.swift` sigue pintando `mismatch … · red \(state.verifyNetworkRetries) · leader … · seqCut …` y no menciona `reversePreMount` en ninguna línea.
- El único commit posterior al fichero (`ee95d7902`) no toca la etiqueta.

Triage 2026-10-08: abierto · low → low · el panel DEV sigue sin el reloj del techo y afirma «red 0»; no es producción, pero el device-QA de la vuelta se apoya en él.

## Cierre (2026-11-05, lote N9)

- «Contadores» dice `red n/a (vuelta: ver «Techo vuelta»)` en `reverseClaimLeader`, `reverseDrainAll`, `reverseVerify` y
  `reverseFreezeBackend`; fuera de ellas sigue `red N` (la ida aún gasta el contador en `verifying`).
- Fila nueva «Techo vuelta»: fase sellada, desde cuándo y cuánto lleva parada (mismo cálculo que
  `observeReversePreMountStall`: sello de otra fase o en el futuro no cuentan parada), más el reloj de la causa y el de
  cualquier motivo definitivo, con «(en pausa)» cuando el tramo está cerrado. Una causa vacía se pinta como «red o sin
  motivo: pausa», no como «sin problema».
- Lógica pura en `Yala/App/Logic/CloudSyncDebugReverseClockLogic.swift` (fuera del `#if DEV_BUILD` de la vista, para que
  la vean los unit tests del scheme `Yala`). Tests: `CloudSyncDebugReverseClockLogicTests` (7 casos, con control fuera de
  la vuelta).
- Sin captura en device: el panel solo existe en `Yala Dev` y montar una vuelta parada pide una cuenta en la nube de
  staging. Lo verá el próximo device-QA de la vuelta que lo use.
