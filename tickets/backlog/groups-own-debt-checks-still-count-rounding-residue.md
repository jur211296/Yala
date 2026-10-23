---
id: groups-own-debt-checks-still-count-rounding-residue
status: backlog
priority: low
area: "groups"
created: 2026-10-21
updated: 2026-10-21
owner: frank
source: "review adversarial del lote decidido UX 2.2 · grupos administrar (L19-10), encargo 2026-10-21-lote-decidido-2-2-12-grupos-administrar"
---

# «Salir de todos mis grupos» y el borrado de cuenta siguen contando el residuo de redondeo como deuda

## Qué ve el usuario

Desde L19-10, Ajustes del grupo ya no cuenta como deuda el residuo de redondeo (los céntimos que quedan cuando los
repartos de un gasto no suman exactamente su importe): manda lo que dicen las deudas de persona a persona, como
«Están a mano» y Saldos (`GroupRoundingResidueLogic`). Dos superficies que no eran del lote siguen con el saldo neto
`abs > 0.01`:

- **Salir de todos mis grupos** (`GroupService` ~:1107, hecho `hasOutstandingDebt` de `GroupBatchLeaveLogic`): un grupo
  donde el residuo cae en mí sale como «Tienes saldos pendientes».
- **Borrar la cuenta** (`GroupService` ~:1756 con `AccountDeletionDebtLogic`): avisa de una deuda que nadie cobra.

Avisan de más, no pierden dinero. Pero el mismo grupo dice «a mano» en Ajustes y «tienes saldos» aquí.

## Hecha cuando

Las dos superficies deciden con `GroupRoundingResidueLogic.hasOutstanding(debts:memberID:)` sobre las deudas
simplificadas del grupo, con un test de cada una que use el caso de la semilla `grupos-saldado` (residuo sin deuda) y el
de una liquidación corta (deuda real de céntimos).
