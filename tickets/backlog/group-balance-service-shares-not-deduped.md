---
id: group-balance-service-shares-not-deduped
status: backlog
priority: low
area: groups
created: 2026-09-07
updated: 2026-10-08
source: review adversarial de groups-shareable-summary (2026-09-07)
---

# `GroupBalanceService` deduplica los gastos pero no los repartos

## Qué pasa

`GroupBalanceService.calculateBalances` y `rawDebts` se defienden de los duplicados de CloudKit
deduplicando los `SplitExpense` por `id`:

```swift
let uniqueExpenses = Dictionary(grouping: expenses, by: \.id).values.compactMap(\.first)
```

Los `SplitShare`, en cambio, entran tal cual (`Dictionary(grouping: shares, by: \.expenseID)`). El
resultado es asimétrico: el total pagado queda blindado y **lo que le corresponde a cada miembro se
dobla**.

Con Ana pagando 300 y un reparto 150/150 duplicado, la columna «debe» de cada uno sale a 300 y el
balance neto es el doble del real.

## Cómo llegan repetidos

Dos vías, y ninguna necesita un estado corrupto:

1. El mismo merge de CloudKit que ya motivó el dedup de gastos.
2. `GroupExpenseService.updateExpense` **borra los repartos viejos y crea otros con `id` nuevo**. Si
   en otro dispositivo se aplican los INSERT antes que los tombstones, o un tombstone acaba
   descartado, conviven los dos juegos.

## Estado

El resumen compartible (`GroupShareableSummaryLogic`, 2026-09-07) ya deduplica los repartos por su
propio `id` y tiene test con mutante verificado. `GroupBalanceService` es de donde salen Balances, la
banda del header y el recordatorio de deudas, y sigue expuesto — **no se tocó en ese cambio a
propósito**: es un servicio compartido por media docena de pantallas y merece su propia verificación.

## Acceptance Criteria

- [ ] `calculateBalances` y `rawDebts` deduplican los repartos por `id`, igual que ya hacen con los
      gastos.
- [ ] Test en `GroupBalanceServiceTests` con repartos duplicados, verificado por mutación.
- [ ] Comprobado que ninguna pantalla que hoy dependa del doble conteo cambia de comportamiento
      (no debería haber ninguna: el doble conteo nunca fue intencionado).

## Medido en 2.1 (triage 2026-10-08)

- `GroupBalanceService.calculateBalances` y `rawDebts` siguen deduplicando los gastos (`uniqueExpenses`) y agrupando los repartos tal cual (`Dictionary(grouping: shares, by: \.expenseID)`). Sin commits en el fichero desde el 2026-09-07.
- `GroupExpenseService.updateExpense` sigue borrando los repartos viejos e insertando otros con `id` nuevo, que es la segunda vía de llegada.
- El arreglo es de una línea por función, con el test que ya tiene de molde `GroupShareableSummaryLogic`.

Triage 2026-10-08: abierto · low → low · los repartos siguen sin dedup y un duplicado dobla lo que cada uno debe, pero solo con una anomalía de sync.
