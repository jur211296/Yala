---
id: fx-repair-sweep-seals-on-a-partially-restored-store
status: backlog
priority: low
area: "currency, sync"
created: 2026-09-08
source: residual declarado en chat-rows-sealed-before-the-fix-have-no-repair-path (2026-09-08)
updated: 2026-10-08
---

# El barrido de tasas puede sellarse con el restore a medio bajar

## Qué le pasa al usuario

`TransactionUpdateService.repairLegacyOneToOneRatesIfNeeded` es one-shot: cuando se sella, no vuelve.
Desde `chat-rows-sealed-before-the-fix-have-no-repair-path` ya no se sella sobre un store **vacío**,
pero sí sobre uno **parcial**. Un restore de iCloud que ha entregado 3 filas de 5.000 pasa el guard,
el barrido cura esas 3 y sella; las 4.997 que bajan después no las mira nadie, y sus tasas falsas se
quedan para siempre.

## Por qué el guard actual no lo cubre (medido el 2026-09-08)

Las dos comprobaciones que tiene hoy responden preguntas más estrechas:

1. **El gate de quiescencia.** `iCloudSyncService.isImportQuiescent` sale de
   `SubcategoryDedupGate.decide`, que devuelve `.run` cuando `lastImportDate == nil` — o sea vale
   `true` **antes de que empiece ningún import**. Lo dice literalmente `BootSaveGateLogic`: «`isQuiescent`
   alone is `true` BEFORE any import starts». En el arranque en frío de un restore, el paso 2 del
   bootstrap llega antes del primer evento de CloudKit y el gate está abierto.
2. **El guard de presencia.** `fetchCount == 0` distingue *vacío* de *no vacío*, nunca *completo* de
   *parcial*.

## Lo que lo cerraría

El gate de seis entradas que usan sus vecinos: `awaitPersonalStoreReady` →
`BootSaveGateLogic.decide`, que mira además `hasCompletedFirstImport` y `status.isSyncing` (que cubre
`.setup`, invisible para `isImportQuiescent`). Este barrido no lo usa porque cuelga de
`AppBootstrapper.loadExchangeRates`, en el **paso 2**, y ahí no hay ningún gate de store-ready: el
primero del bootstrap está mucho más abajo.

## Por qué no se hizo en el ticket que lo encontró

Mover `loadExchangeRates` detrás del gate de store-ready cambia el orden del arranque para todo lo
que hay dentro —`updateTodayIfNeeded`, `preloadHistoricalIfNeeded` y el reparador—, no solo para el
barrido. Eso es una decisión de arranque, no un residual de aquel arreglo.

## Criterio de hecho (AC)

- [ ] El barrido no se sella mientras el store personal pueda seguir recibiendo filas del primer
      import.
- [ ] La decisión sobre `loadExchangeRates` queda escrita: o se mueve entero detrás del gate, o el
      barrido se saca de ahí y se difiere como su vecino `repairUnsignedChatExpensesIfNeeded`.
- [ ] Un test del caso: store parcial → no sella; corpus completo en el arranque siguiente → cura.

## Medido en 2.1 (triage 2026-10-08)

- Sin cambios desde el 08-sep. El barrido (`TransactionUpdateService.swift:127`) solo pasa el gate de `isImportQuiescent` (`:137`), y su docblock (`:105-111`) ya declara el residual del store parcial.
- Sigue colgando del paso 2: `AppBootstrapper.loadExchangeRates` (`:2624-2638`) lo llama en `:2634`, antes de cualquier gate de store-ready.
- Ventana estrecha: hacen falta filas con 1:1 envenenado por un build viejo y un primer arranque del build nuevo con el restore a medias.

Triage 2026-10-08: abierto · medium → low · `repairLegacyOneToOneRatesIfNeeded` sigue gateado solo por `isImportQuiescent` y se llama en el paso 2 (`AppBootstrapper.swift:2634`); residual declarado en su propio docblock, con una ventana estrecha.
