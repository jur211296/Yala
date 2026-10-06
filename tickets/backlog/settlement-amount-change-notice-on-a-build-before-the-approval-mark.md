---
id: settlement-amount-change-notice-on-a-build-before-the-approval-mark
status: backlog
priority: low
area: "groups, sync, inbox"
created: 2026-10-05
source: "review adversarial de `settlement-amount-edited-after-approval-leaves-the-bank-stale` (2026-10-05, lentes de dinero y de consumidores); leído en código, NO reproducido"
---

# Un dispositivo con una versión de antes del 28-sep puede registrar dos veces el pago de un aviso de importe cambiado

## El síntoma, en lenguaje de usuario

Tengo Yala en el iPhone (versión nueva) y en el iPad (versión vieja, sin actualizar). Una liquidación que ya aprobé cambia
de 25 a 30 y el iPhone me avisa en el Inbox. El iPad recibe ese aviso como un borrador de liquidación más. Si en el iPad lo
finalizo, o si en el iPad salgo del grupo y el aviso pasa a borrador manual y lo apruebo, el banco suma 30 a los 25.

## Lo medido (leyendo código)

- El aviso es un `InboxDraft` `.groupSettlement` pendiente con cuenta, importe y subcategoría
  (`GroupTransactionBridge.reconcileAmountChangeNotices`).
- Desde el 2026-09-28 (`101072555`) aprobar un borrador de una liquidación con marca lanza
  `groupSettlementAlreadyRegistered`, así que esos builds no duplican. Uno anterior no tiene ese freno.
- Un build anterior también convierte el aviso a `.manual` en `computeFreezePlan` (salir del grupo, borrado suave,
  barrido de huérfanas, retirada de grupos legacy); este build lo borra.

## Qué hay que decidir

- Aceptarlo (la ventana es la de los dispositivos sin actualizar), o
- crear el aviso sin cuenta ni subcategoría para que un build viejo no lo pueda aprobar sin elegir cuenta a mano (la fila y
  la hoja ya leen la cuenta por la marca).

## Relacionados

- [[settlement-amount-edited-after-approval-leaves-the-bank-stale]]
