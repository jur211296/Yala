---
id: capability-upgrade-reemits-a-v1-link-edit-with-a-fresh-hlc
status: backlog
priority: very-low
area: "cloud-sync, accounts"
created: 2026-10-18
updated: 2026-10-18
source: review adversarial de multi-currency-accounts-1-model-and-sync (lente de sync, 2026-10-18)
---

# Un enlace de tarjeta cambiado hablando `v1` sube con la hora de la subida de versión, no con la suya

## Qué le pasa al usuario

Si dos teléfonos cambian el MISMO enlace de una línea de tarjeta mientras uno de ellos habla `v1` (la app salió antes
que el Worker), al subir de versión gana el de ese teléfono aunque el otro cambio sea más nuevo.

## Por qué

`applyCapabilityUpgradeIfPending` encola lo apuntado con `enqueueSnapshotRows`, que estampa con `clock.send(now)`: el
HLC es el de la subida, no el del cambio. El apunte (`SyncCapability.noteSuppressedAccountLink`) no guarda cuándo se
hizo. Solo existe si se publica la app antes que el Worker; con el orden del runbook (DDL → Worker → app) no hay nada
que reemitir.

## Qué podría hacerse

Guardar la hora del cambio con el apunte y estampar con `sendLocal(eventTime:)`, como el drain.
