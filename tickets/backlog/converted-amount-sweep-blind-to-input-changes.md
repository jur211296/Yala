---
id: converted-amount-sweep-blind-to-input-changes
status: backlog
priority: low
area: "fx, testing"
created: 2026-09-08
updated: 2026-10-08
source: barrido del patrón de bulk-update-account-leaves-converted-amount-stale (2026-09-08)
---

# El barrido de montos convertidos vigila la mitad del patrón: mira quién escribe, no quién cambia el input

## Qué pasa

`YalaTests/ManualWriteRateQualityTests` barre los tres árboles de producción (`productionTrees`:
`Yala`, `YalaWidgets`, `YalaShare` — y el «`Yala/` entero» que parece obvio es justamente la promesa
falsa que su propio comentario documenta) buscando escrituras de
`amountInPreferredCurrency` y exige que cada una decida `isExchangeRateProvisional`. Es un buen
detector y ya se ganó su sitio. Pero solo cubre **una** de las dos formas de dejar incoherente el
grupo `money`:

| Forma | Qué hace | ¿Lo caza el barrido? |
|---|---|---|
| Escribir la **derivada** sin decidir el flag | sella como definitiva una tasa aproximada | **Sí** |
| Escribir un **input** (`amount`, `currencyCode`, `date`) y no recomputar | deja las cuatro derivadas con el valor anterior | **No** |

`bulk-update-account-leaves-converted-amount-stale` era exactamente la segunda forma, y por eso pasó
por delante del barrido sin activarlo: el método **no escribía** `amountInPreferredCurrency`. No
escribir nada era justamente el bug.

El canario de sync tampoco cierra el hueco, y esto está medido: ni `currency_code` ni `account_ref`
están en el grupo de coherencia `money` de `EntityEmissionMap` (que lo forman `amount`,
`amount_in_preferred_currency`, `preferred_currency_code`, `exchange_rate` e
`is_exchange_rate_provisional`). Como `DeltaEmitter` arma `touchedGroups` solo con columnas que tienen
grupo, cambiar la divisa **no emite el grupo `money` en absoluto** y su guard ni se evalúa. ⇒ **hoy no hay ningún detector automático para esa mitad.**

## Lo que el barrido a mano encontró el 2026-09-08

Barrido completo de los tres árboles de producción buscando escrituras de los tres inputs sobre un
`TransactionItem` ya persistido:

- **Sin recomputar, y son bug**: `TransactionService.bulkUpdateAccount` (borrado ese día) e
  `InitialBalanceService.swift:254` (ticket `initial-balance-date-move-leaves-converted-amount-stale`).
- **Sin recomputar, y es correcto a propósito** — la lista que cualquier detector tendría que eximir:
  `EntityApplyMap.swift:155,157,158` (los tres inputs; lo que hace correcta la exención no son ellos
  sino los appliers de `:180-183`, que traen las cuatro derivadas del wire ya resueltas),
  `CloudSyncReconciler.swift:100` (copia el grupo coherente del ganador),
  `ChatUnsignedExpenseRepairService.swift:145` (solo voltea el signo; recomputar propagaría el signo
  malo).
- **Recomputan, pero inline y sin llamar al método**: `NewTransactionViewModel` en tres sitios —los
  inputs en `:639-641`, `:731-733` y `:747-749`, y las cuatro derivadas escritas a mano justo después,
  en `:647-651`, `:739-743` y `:755-758`, tras un `convertChecked` propio. Un detector textual vería
  esas segundas como escrituras sueltas.

## El problema de diseño, dicho antes de empezar

Un barrido textual del segundo patrón es **más difícil que el primero**, y conviene decidirlo con los
ojos abiertos:

1. Hay que distinguir el receptor. `var amount:` lo declaran otros **siete** modelos —medido:
   `CashFlowOverride`, `FavoritePayment`, `InboxDraft`, `ScheduledPayment`, `SplitExpense`,
   `SplitSettlement`, `SplitShare`— más varios structs de presentación. (Ojo con la lista fácil de
   citar de memoria: `Account`, `Budget`, `CashFlowLine` y `SplitGroup` **no** tienen `amount`; usan
   `limitAmount`, `manualAmount`, `budgetLimitAmount`.) El barrido a mano necesitó resolver el tipo de
   cada receptor.
2. Hay que distinguir **creación** de **edición**: los inits legítimos son mayoría abrumadora.
3. Las exenciones deliberadas ya son seis y no una.

Con más exenciones que hallazgos, el detector se apaga solo. ⇒ **puede que la respuesta no sea un
source-scan gemelo sino otra cosa**: por ejemplo meter `currency_code` en el grupo `money` del mapa de
emisión (que haría al canario `cloudSyncCoherenceGroupPartial` competente para esto, pero toca el
canon y hay que medir qué más arrastra), o encapsular la escritura de los inputs tras un método del
modelo que recompute por construcción y prohibir la asignación directa.

## Criterio de hecho (AC)

- [ ] Decidir el mecanismo entre los tres candidatos (source-scan gemelo · `currency_code` al grupo
      `money` · encapsular la escritura del input), con el coste de cada uno medido, no estimado.
- [ ] Sea cual sea, tiene que cazar los dos hallazgos reales del 2026-09-08 usados como control
      positivo (el `bulkUpdateAccount` borrado y el `InitialBalanceService`), y dejar pasar los tres
      casos deliberados.
- [ ] Si el elegido es tocar el grupo `money`: comprobar antes qué le pasa al Merkle y al parity del
      manifest.

## Medido en 2.1 (triage 2026-10-08)

- Sin barrido gemelo para los inputs: en `YalaTests` solo están `ManualWriteRateQualityTests` y `ManualWriteRateQualityBehaviorTests`. `currency_code` sigue sin grupo (`EntityEmissionMap.swift:180`); el grupo `money` está en `:179` y `:186-189`.
- El control positivo vivo, `InitialBalanceService.swift:254`, sigue sin recomputar.
- **No es duplicado de `initial-balance-date-move-leaves-converted-amount-stale` (comprobado en este triage).** Arreglar el barrido detecta ese caso, no lo arregla: el recálculo y su test siguen haciendo falta. Solo la tercera vía (encapsular la escritura del input en un método que recompute) lo arreglaría de paso, y no está elegida. Se quedan los dos: aquel como hijo y control positivo de éste.

Triage 2026-10-08: abierto · medium → low · el barrido sigue mirando solo la escritura de la derivada (`ManualWriteRateQualityTests`) y `currency_code` sigue fuera del grupo `money` (`EntityEmissionMap.swift:180`); es un hueco de detector, y su positivo vivo tiene ticket propio.
