---
id: opening-balance-ticks-the-first-expense-step
status: backlog
area: onboarding
priority: medium
created: 2026-10-13
updated: 2026-10-13
source: auditoría UX 2.2, lote 2 (apuntar un movimiento a mano)
---

# «Registra tu primer gasto» sale marcado sin haber registrado nada

**Clase:** bug de primeros pasos. Lo revisa el lote 5 de la auditoría UX 2.2 (primeros días: guías y tips); se
encontró en el lote 2 y no se arregló ahí porque no es de ese lote.

## Qué pasa (medido en el simulador, 2026-10-13)

Una persona nueva hace el onboarding «Llevar el control» con una cuenta de efectivo y saldo S/ 500. Al llegar al
Panel, la tarjeta «Primeros pasos» dice «1 de 7 completados» y el paso marcado es **«Registra tu primer gasto»**,
aunque no ha registrado ninguno. Captura: `2.0-panel-primera-vez.png` en
`~/Claude/entregas/Yala--auditoria-ux-2-2-lote-2-apuntar-a-mano/capturas/`.

## Por qué (leído en el código, rama 2.2)

- `PanelView` llama a `SetupChecklistManager.autoDetect(transactionCount: viewModel.transactions.count, …)` en su
  `onAppear`.
- `autoDetect` marca `.firstExpense` con `transactionCount > 0`.
- El saldo inicial del onboarding es un registro (subcategoría de sistema «Ajustes de saldo»), así que cuenta.

Inferido, sin medir: lo mismo pasa con cualquier registro de sistema (transferencias, puente de grupos). Y por la
misma causa `markFirstCreation` cuenta el saldo inicial y nunca ofrece «¿Era de prueba?» tras el primer gasto de
verdad de alguien que pasó por el onboarding.

## Qué haría falta decidir

Si «primer gasto» cuenta solo los registros que la persona apunta (sin los de sistema), el paso quedaría pendiente
hasta el primer gasto real y el aviso «¿Era de prueba?» aparecería entonces. Eso cambia cuándo sale ese aviso, que
tuvo su propio bug (`first-expense-practice-alert-tears-down-the-success-screen`, cerrado): conviene probarlo junto.
