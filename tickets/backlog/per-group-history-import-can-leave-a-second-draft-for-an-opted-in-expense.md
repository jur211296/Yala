---
id: per-group-history-import-can-leave-a-second-draft-for-an-opted-in-expense
status: backlog
priority: low
area: groups, bridge, inbox
created: 2026-11-10
updated: 2026-11-10
source: lote 01 de las mejoras necesarias 2.3 (Grupos), review adversarial
---

# Importar el historial de un grupo puede dejar un segundo borrador para un gasto ya pasado a la Bandeja

Lo encontró la review adversarial del lote 01 de las mejoras necesarias 2.3 (2026-11-10), **no medido**. Con el puente
apagado en un grupo, «Sí, registrar» en un gasto que pagaste deja un borrador en la Bandeja. Si después se vuelve a
encender el puente en ese grupo y se elige «Importar todo el historial», `GroupTransactionBridge.bridgeExpense` no retira
ese borrador de opt-in y, como el gasto aún no tiene movimiento real, crea otro: dos borradores del mismo gasto.

El camino de Ajustes de Grupos ya lo tenía; desde ese lote también se llega desde los ajustes de cada grupo (la hoja de
activación sale ahora al volver a encenderlo). Cómo verificarlo: test del puente con un borrador de opt-in y un
`bridgeExpense(isBulkImport: true)` del mismo gasto. Criterio: queda un borrador.
