---
id: wipe-division-exclusion-trusts-the-origin-to-converge
status: backlog
priority: medium
area: "groups, sync"
created: 2026-09-28
source: "review adversarial de `a-wipe-on-a-device-without-the-groups-loses-their-rows-everywhere` (lentes de grupos y de sync, 2026-09-28); inferido leyendo código, NO reproducido"
---

# Si el dispositivo que vació no llega a reponer, lo que prometió reponer no vuelve

## El síntoma, en lenguaje de usuario

Vacío mis datos en el iPad, que tiene los mismos grupos que el iPhone, y no lo vuelvo a abrir (o lo borro). En el iPhone los
gastos y liquidaciones de grupo desaparecen de mis cuentas y no vuelven.

## Lo medido (2026-09-28, leyendo código)

- Desde el ticket `a-wipe-on-a-device-without-the-groups-loses-their-rows-everywhere`, el origen escribe en el iCloud-KV
  qué repone (`GroupsRemoteWipeDivision.declare`) y el receptor repone el resto, excluyendo esos ids para siempre
  (`GroupsBridgeRestoreConvergenceStore.markPending(excluding:)`).
- La convergencia del origen corre en su SIGUIENTE arranque en frío. Si no llega (desinstalación, relevo de persona que
  retira la petición, un gasto que agota los intentos de `GroupsPendingBridgeIntent`), nadie comprueba que lo prometido
  llegó.
- No es regresión: antes del reparto esas filas tampoco volvían.

## Qué hay que decidir

Si el receptor guarda los ids excluidos y, pasado un plazo, re-puentea los que sigan sin ninguna fila («si ya falta», el
criterio de `GroupsRemoteWipeReturn`). Coste: si el origen converge después del plazo, duplica mientras no se crucen por
el espejo.

## Relacionados

- [[a-wipe-on-a-device-without-the-groups-loses-their-rows-everywhere]]
- [[wipe-division-complement-can-be-bridged-twice]]
