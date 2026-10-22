---
id: fx-previous-period-amounts-unmarked
status: backlog
priority: low
area: currency
created: 2026-09-09
updated: 2026-10-08
source: hallazgo de camino en fx-approximate-mark-missing-on-secondary-surfaces (2026-09-09)
---

# El importe «vs período anterior» nunca puede llevar la marca

## Qué le pasa al usuario

Junto al total del mes, la app enseña el del mes anterior para comparar. El actual puede llevar
«≈»; el anterior nunca, porque el número llega solo, sin su señal. El usuario compara un importe
declarado aproximado contra uno declarado exacto y las variaciones que salen de esa resta tampoco
dicen nada.

## Dónde, medido el 2026-09-09

`CashFlowWidget` (el de la app) recibe `previousAmount: Double?` como parámetro suelto: la señal que
viaja en `summary` describe el período ACTUAL y usarla ahí marcaría un número que no describe. Está
escrito en el código, en el `AmountText` correspondiente.

Los tres callsites que pasan `previousAmount` lo calculan por su cuenta
(`PanelViewModel.calculateCashFlowWidget` y los dos de Estadísticas), así que la señal tendría que
salir de la misma pasada que el número.

`VariationChip` es el mismo caso elevado: su porcentaje sale de dos números y su incertidumbre es la
de los dos.

## Criterio de hecho (AC)

- [ ] `previousAmount` viaja con su señal desde quien lo calcula, o se sustituye por un tipo que
      lleve las dos cosas juntas y no puedan separarse.
- [ ] Decidido qué hace `VariationChip` con dos señales: marcar el porcentaje, o no marcar y
      dejarlo escrito.

## Medido en 2.1 (triage 2026-10-08)

- `CashFlowWidget` sigue recibiendo `previousAmount: Double?` suelto; su marca (`kpiValueIsApproximate`) describe solo el período actual.
- Los productores de `previousAmount` en `InsightsCalculator` (gasto, ingreso, neto y promedio diario del período anterior) pasan el número sin la señal, aunque `prevCashFlow` ya la calcula. `VariationChip` no tiene marca.

Triage 2026-10-08: abierto · low → low · previousAmount sigue viajando sin su señal y VariationChip sin decisión; información que falta, no falsa.
