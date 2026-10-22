---
id: groups-settlement-reminder-stale-clock
status: backlog
priority: low
area: groups
created: 2026-09-07
updated: 2026-10-08
---

# El reloj del recordatorio de deuda no ve las ediciones ni los pagos retro-fechados

## Problema

El recordatorio de liquidación (`groups-settlement-reminder`, ya en `qa/`) mide «cuánto lleva
quieta esta deuda» con la última actividad entre las dos personas:
`SplitExpense.createdAt` para los gastos y `SplitSettlement.date` para las liquidaciones. Esa
elección es la mejor posible **con los campos que hoy existen**, y deja dos huecos medidos en la
review adversarial del 2026-09-07. Los dos producen el mismo síntoma: el importe del aviso es
correcto, pero la frase «lleva semanas sin moverse» es falsa.

**1 · Una liquidación retro-fechada no resetea el contador.** `SplitSettlement` no tiene
`createdAt` — `date` es su único campo temporal, y lo teclea el usuario. Si le pagué a Ana en
efectivo el 1 de agosto y lo registro el 15 de septiembre con esa fecha (pago parcial, queda
saldo), la actividad del par queda en «hace 45 días» y el nudge puede salir **minutos después de
registrar el pago**. Es justo el lado que el AC nombra primero: «Liquidar la deuda, aunque sea
parcialmente, resetea el contador».

**2 · Editar un gasto viejo cambia la deuda sin mover el reloj.** `SplitExpense` no tiene
`updatedAt`, y la actividad se mide con `createdAt`. Si Ana corrige hoy un gasto de hace dos
meses de 100 a 500, el reloj sigue en −60 días: esta noche sale «lleva semanas sin moverse: le
debes 500 a Ana», sobre una deuda que cambió hoy. Cubre también
`GroupExpenseService.updateOpeningBalance`, que tampoco toca `createdAt`.

## Por qué no se arregló en el PR original

Los dos necesitan **un campo de fecha nuevo en el store de Grupos**, y eso es exactamente el
tipo de cambio que el ticket padre documenta como el más delicado del repo: entry en el
traductor de records, migración del store `YalaGroups` y deploy de schema. Fuera del alcance de
un feature medium, y sin ninguna urgencia — el daño es un aviso prematuro, nunca un importe
falso ni una notificación a quien no debe recibirla.

## Solución propuesta (a evaluar, no decidida)

- `SplitSettlement.recordedAt: Date` y `SplitExpense.updatedAt: Date`, ambos con default
  explícito (CloudKit no admite propiedades sin default) y lectura default-safe para tolerar
  records viejos.
- La actividad pasa a ser `max(campo del usuario, campo del sistema)` en los dos casos.
- Checklist de schema completo en el ticket padre, sección «Si en algún momento se opta por la
  opción 1 o 2».

Alternativa sin tocar schema, más débil pero de coste cero: registrar la fecha de primera
observación local de cada fila en el propio `UserDefaults` del tracker. Se descarta de entrada
si el device es nuevo (restore), porque entonces «primera observación» es la fecha del restore.

## Acceptance Criteria

- [ ] Registrar hoy una liquidación con fecha de hace 45 días resetea el contador de esa deuda.
- [ ] Editar hoy el importe de un gasto viejo resetea el contador de ese par.
- [ ] Los records anteriores a la migración no producen ningún aviso prematuro ni pierden el suyo.
- [ ] Tests pure-logic sobre `GroupSettlementReminderService.activities` para los dos casos.

## Medido en 2.1 (triage 2026-10-08)
- `GroupSettlementReminderService.swift:335` usa `expense.createdAt` y `:342` `settlement.date`.
- `SplitSettlement` sigue sin fecha de sistema (`SplitSettlement.swift:16-32`), y `SplitExpense` sin `updatedAt`.
- **Obsoleto:** ya no es un cambio de schema CloudKit. Con Grupos en backend, los campos nuevos van al manifest de Grupos (`split_settlements` y `split_expenses` en `group_capability_manifest.json`), y eso choca con `groups-canal-sin-capability-set` (cada columna nueva exige bump de canon).
- Baja a `low`: el daño es un aviso prematuro, nunca un importe falso.

Triage 2026-10-08: abierto · medium → low · El reloj del recordatorio sigue usando SplitExpense.createdAt y SplitSettlement.date; ningún modelo ni el manifest de Grupos tiene updatedAt/recordedAt.
