Yala
# Grupos: un guardado que falla no duplica gastos, no deja pagos a medias y no rompe el préstamo
---
toca: Yala/Services/Groups/,YalaTests/GruposGuardadoFallido/,tickets/backlog/group-expense-retry-after-a-failed-save-duplicates-the-expense.md,tickets/backlog/confirming-a-settlement-whose-save-fails-leaves-it-confirmed-without-bridge.md,tickets/backlog/deleting-a-scheduled-payment-deletes-group-legs-without-unbridging.md,tickets/backlog/groups-opening-balance-edit-can-duplicate-a-pair.md,tickets/done/group-expense-retry-after-a-failed-save-duplicates-the-expense.md,tickets/done/confirming-a-settlement-whose-save-fails-leaves-it-confirmed-without-bridge.md,tickets/done/deleting-a-scheduled-payment-deletes-group-legs-without-unbridging.md,tickets/done/groups-opening-balance-edit-can-duplicate-a-pair.md,tickets/backlog/2026-11-22-grupos-guardado-fallido-sin-duplicar.md,tickets/done/2026-11-22-grupos-guardado-fallido-sin-duplicar.md
esfuerzo: high
cierre: cierra-sola
---

Jürgen pidió el 22-nov (15:08 Lima) encolar todo lo pendiente del backlog que esté claro o tenga decisión. Este encargo junta tickets afines.

## Tickets
- `tickets/backlog/group-expense-retry-after-a-failed-save-duplicates-the-expense.md`
- `tickets/backlog/confirming-a-settlement-whose-save-fails-leaves-it-confirmed-without-bridge.md`
- `tickets/backlog/deleting-a-scheduled-payment-deletes-group-legs-without-unbridging.md`
- `tickets/backlog/groups-opening-balance-edit-can-duplicate-a-pair.md`

## Qué hacer
Reintentar un gasto de grupo cuyo guardado falló no lo apunta dos veces. Confirmar un pago cuyo guardado falla no queda confirmado sin su movimiento personal. Borrar un pago planificado no se lleva la pata real de un gasto de grupo dejando el préstamo solo. Editar un saldo inicial no deja dos de la misma pareja y moneda. Cada uno con su prueba unitaria que primero falle.

## Reglas
- Antes de tocar nada, verifica contra `origin/2.3` que cada ticket siga pasando (varios son viejos). Si uno ya no pasa o ya está hecho, muévelo a done con la evidencia y sigue con los demás.
- Si un ticket resulta ser una decisión de diseño o de producto que solo Jürgen puede tomar, no la inventes: déjalo en backlog con la pregunta y las opciones con su recomendación, y anótalo en el cierre.
- Textos nuevos en su propia tabla `.strings` (la del toca), no en Localizable.strings ni L10n.swift, en los 16 idiomas y siempre en español neutro latinoamericano (en es-ES también, sin vosotros).
- Si hace falta tocar algo fuera del toca, toca lo mínimo y anótalo en el cierre.
- Producción (iCloud Production, Supabase prod, gateway, web publicada) no se toca: déjalo probado en desarrollo y anotado para Dan, con el OK de Jürgen.
- Nada de pago.

## Dispositivos
Antes de usar un simulador, comprueba si el iPhone 14 conectado por DeviceMCP está libre; no lo des por ocupado sin comprobarlo. En la Max puedes usar un segundo simulador si otra sesión ya usa uno (tope 2); en la Mini, 1.

## Cierre
Commits y PR sin firma de IA y sin saltarse hooks. Espera el merge real del PR en 2.3 antes de `/cerrar-total`. Si a los ~45 min el CI sigue rojo por algo ajeno al PR, cierra y anótalo. El cierre incluye «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada».

## Paso 0 — decisiones (resueltas en semi, sin consulta: ninguna es vital)

Medido contra `origin/2.3` (5a1366b9f) el 2026-11-22: los cuatro tickets siguen vivos en el código.

1. **Gasto que falla al guardar** → se retiran del contexto el gasto y sus repartos (molde de `createSettlement`). Seam `_testFailNextExpenseSave`.
2. **Confirmar un pago que falla al guardar** → la marca `isConfirmed` vuelve a su valor anterior. Seam `_testFailNextConfirmSave`.
3. **Borrar un pago planificado con la pata real de un gasto de grupo** → el registro con `splitExpenseID` o `splitSettlementID` se DESVINCULA del pago (como los de meses pasados) en vez de borrarse. El gasto del grupo no se toca. Descartado: borrarlo y desmontar el puente (dejaría el gasto del grupo sin el dinero que pagaste) y borrar el gasto del grupo (afecta a otros miembros: eso sí sería decisión de Jürgen). Toca `Yala/Services/EntityDeletionService.swift` (fuera del `toca`, una condición).
4. **Editar un saldo inicial hacia una pareja y moneda ocupadas** → mueve datos, así que la app PREGUNTA (regla de cuándo pregunta la app), con la misma pregunta y los mismos textos que ya tiene el alta («Ya hay un saldo inicial entre X e Y… Reemplazar»): sin textos nuevos. Al confirmar, se guarda la edición y se borran los otros de esa pareja y moneda (orden: si el borrado fallara quedan los dos visibles, no se pierde ninguno). El servicio exige la confirmación (`replacing:`) y lanza `openingBalancePairTaken` sin ella. Toca el formulario `GroupOpeningBalanceFormView` (fuera del `toca`, mínimo).
   - Camino 2 del ticket (parejas con dos saldos de antes de la regla): al añadir y confirmar «Reemplazar», se funden también los duplicados viejos de esa pareja. Residual: el texto de la pregunta del alta enseña solo el más antiguo.
5. **Otras instancias del patrón** «un guardado fallido deja cambios en el contexto» (`updateExpense`, `deleteExpense`, `deleteSettlement`…): no entran (el encargo nombra cuatro); van a «Encontrado» del cierre.
6. Textos nuevos: ninguno.
