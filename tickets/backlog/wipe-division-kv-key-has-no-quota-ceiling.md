---
id: wipe-division-kv-key-has-no-quota-ceiling
status: backlog
priority: low
area: "groups, sync"
created: 2026-09-28
updated: 2026-10-08
source: "review adversarial de `a-wipe-on-a-device-without-the-groups-loses-their-rows-everywhere` (lentes de sync y de grupos, 2026-09-28); inferido, sin medir qué hace iOS al pasar la cuota"
---

# El reparto de «Vaciar datos» ocupa el iCloud-KV sin techo y no se retira nunca

## Qué pasa

- `GroupsRemoteWipeDivisionStore.kvKey` (`groupsWipeDivision`) lleva un id por gasto y por liquidación de grupo, unos 39
  bytes cada uno. El iCloud-KV tiene 1 MB para todo el Apple ID, con las preferencias y las declaraciones dentro: el techo
  teórico ronda las 25.000 ids. (2026-10-06: las declaraciones del vaciado tardío se retiraron y ningún build las escribió nunca
  —ticket `late-remote-wipe-return-has-no-producer-left`—; en el KV quedan las preferencias y el reparto.)
- Sube en el mismo `synchronize` que la señal de vaciado. Si una violación de cuota frena el lote, la señal podría no
  llegar mientras el borrado del espejo sí: la pérdida del ticket padre.
- Cada vaciado sobrescribe la clave, pero nadie la borra.

## Qué hay que decidir

Retirar la clave pasado el plazo de espera (30 días), y/o un tope con salida a «reparto vacío» (el receptor repone todo).
Antes, medir en device qué hace `NSUbiquitousKeyValueStore` al pasar la cuota.

## Relacionados

- [[a-wipe-on-a-device-without-the-groups-loses-their-rows-everywhere]]

## Medido en 2.1 (triage 2026-10-08)

- `GroupsRemoteWipeDivision.swift:42` sigue declarando que la clave del KV no se retira nunca; no hay `removeObject` de `kvKey`.
- Sigue sin medir qué hace `NSUbiquitousKeyValueStore` al pasar la cuota.

Triage 2026-10-08: abierto · low → low · la clave sigue sin techo ni retirada; el techo teórico ronda las 25.000 ids.
