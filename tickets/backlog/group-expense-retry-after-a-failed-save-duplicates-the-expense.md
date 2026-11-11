---
id: group-expense-retry-after-a-failed-save-duplicates-the-expense
status: backlog
priority: high
area: groups, expense-form
created: 2026-11-10
updated: 2026-11-10
source: lote 01 de las mejoras necesarias 2.3 (Grupos)
---

# Reintentar un gasto de grupo cuyo guardado falló lo apunta dos veces

Leído en el código el 2026-11-10 (lote 01 de las mejoras necesarias 2.3), **no reproducido**: `GroupExpenseService.createExpense`
inserta el gasto y sus repartos y, si `context.save()` falla, lanza sin retirarlos del contexto
(`GroupExpenseService.swift`, el `catch` tras el `context.insert`). Siguen pendientes de insertar, así que el siguiente
guardado —el del reintento del formulario— escribe los dos gastos. Es el mismo patrón que se cerró ese día para «Apuntar
pago» (`createSettlement` retira el pago con `context.delete` si el guardado falla).

Cómo verificarlo: un test de servicio con un seam que haga fallar el guardado de `createExpense`, reintentar y contar
gastos y repartos en disco. Criterio: reintentar deja un gasto.
