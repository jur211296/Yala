---
id: consecutive-wipes-whole-convergence-ignores-the-second-division
status: backlog
priority: low
area: "groups, sync"
created: 2026-09-28
source: "review adversarial de `a-wipe-on-a-device-without-the-groups-loses-their-rows-everywhere` (lente de sync, 2026-09-28); inferido leyendo código, NO reproducido"
---

# Dos «Vaciar datos» seguidos en dos dispositivos con grupos reponen dos veces

## El síntoma, en lenguaje de usuario

Vacío mis datos en el iPhone y, antes de cerrarlo y volver a abrirlo, vacío también el iPad. Algún gasto de grupo puede salir
dos veces en mis cuentas.

## Lo medido (2026-09-28, leyendo código)

- El iPhone queda con su convergencia ENTERA pendiente (`wipePersonalDataKeepingGroups`).
- Procesa la señal del iPad en el orden normal y espera su reparto. Al resolverlo, una petición entera gana
  (`GroupsBridgeRestoreConvergenceStore.markPending(excluding:)` sale sin cambiar nada) y la espera se suelta.
- Los dos reponen todo; duplica si convergen antes de cruzarse por el espejo. Antes del reparto pasaba igual.

## Qué hay que decidir

Convertir la entera en «excluir el reparto nuevo» cuando la entera la pidió un vaciado ANTERIOR a la señal. No vale para la
entera de restaurar dentro de «Activar Yala completo», que no pide liquidaciones a propósito: hay que distinguir quién pidió.

## Relacionados

- [[a-wipe-on-a-device-without-the-groups-loses-their-rows-everywhere]]
