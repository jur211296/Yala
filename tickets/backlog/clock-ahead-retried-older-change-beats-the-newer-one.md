---
id: clock-ahead-retried-older-change-beats-the-newer-one
status: backlog
priority: low
area: "modo-nube, sync, groups"
created: 2026-10-07
updated: 2026-10-08
source: "review adversarial de `personal-clock-ahead-wins-…` / `groups-clock-ahead-wins-…` (2026-10-07), lente de extremo a extremo"
---

# Con la hora adelantada, un cambio que falla solo en su lote y se reintenta pisa al cambio nuevo de la misma fila

## El problema, en lenguaje de usuario

Ana tiene la hora una semana adelantada. Cambia el importe de un gasto dos veces seguidas. Al subir, el primer cambio
falla por un error pasajero del servidor y el segundo entra. En el reintento entra el primero, y el gasto se queda con
el importe viejo, en el teléfono de Ana y en los de todos.

## Por qué pasa (inferido del código, 2026-10-07)

Desde `qa/cloud/hlc01_cap_future_hlc.sql` el servidor decide con el HLC entrante sin acotar y guarda el acotado a
`now() + 60 s`. Con el reloj más de un minuto adelantado, cualquier cambio de ese teléfono supera a lo guardado, también
a su propio cambio posterior ya guardado acotado: el orden propio solo se conserva si los cambios LLEGAN en orden.
Los clientes suben ordenado por HLC (`HLC.uploadOrder`, en `SyncPushClient.push` y `GroupsSyncClient.pushPending`), así
que dentro de un lote el orden es el bueno. Lo que queda es el fallo PARCIAL: el gateway aplica cada delta en su propia
transacción (`gateway/src/sync/routes.ts:154`), un `rejected` con motivo `upstream_*` deja esa fila pendiente
(`SyncPushClient.swift`, rama de `applyResults`; `GroupsSyncClient` igual) mientras las siguientes del mismo lote entran,
y el reintento llega después.

Dos efectos de la misma raíz, menores:
- Un reintento idempotente (respuesta perdida) ya no sale `noop` con el reloj adelantado: se vuelve a aplicar, mueve
  `server_seq` y en Grupos dispara otra vez el push silencioso y «gasto modificado».
- El reconciliador de transferencias puede decidir distinto en cada teléfono durante un ciclo (el adelantado guarda en
  `SyncUnitClock` sus HLC sin acotar); converge en la ronda siguiente.

## Qué habría que decidir

- ¿El gateway deja de aplicar los deltas de un `sync_id` que siguen a uno que falló en el mismo lote (y los devuelve
  pasajeros)? Arregla el orden sin tocar el cliente, pero pide un deploy del Worker.
- ¿O el cliente descarta, antes de subir, las unidades de una fila que ya tapa un cambio suyo posterior
  (`SyncUnitClock` en el canal personal; Grupos no tiene reloj por unidad)?

## Criterios de aceptación

- [ ] Decisión escrita.
- [ ] Test: con el reloj más de un minuto adelantado, un cambio que falla en su lote y se reintenta después del cambio
  nuevo de la misma unidad no lo pisa.

## Medido en 2.1 (triage 2026-10-08)

- `gateway/src/sync/routes.ts` sigue aplicando cada delta con `applyOneDelta` en su propia llamada dentro del `for (const delta of body.deltas)`, y un `upstream_*` sigue saliendo como `rejected` por delta sin parar los siguientes de la misma `sync_id`.
- Ningún commit desde el 2026-10-07 toca ese bucle, `SyncPushClient` ni `GroupsSyncClient`; la decisión sigue sin escribir.

Triage 2026-10-08: abierto · low → low · el fallo parcial por delta sigue igual; exige reloj adelantado más de un minuto, dos cambios de la misma fila en un lote y un `upstream_*` en el primero.
