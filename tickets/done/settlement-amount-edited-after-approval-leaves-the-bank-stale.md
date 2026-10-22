---
id: settlement-amount-edited-after-approval-leaves-the-bank-stale
status: done
priority: low
updated: 2026-10-05
qa-status: not-replicable
qa-date: 2026-10-05
qa-notes: sin device-QA - el cambio remoto lo pide otro cliente y lo visible se ve en el simulador; cubierto por SettlementAmountChangeNoticeTests y SettlementAmountChangeNoticeUITests
area: "groups, sync"
created: 2026-09-28
source: "review adversarial de `settlement-approval-leaves-no-trace-so-a-rebridge-asks-again` (2026-09-27, lente de sync); leído en código, NO reproducido"
---

# Si otra persona corrige el importe de una liquidación que ya aprobé, mi banco se queda con el importe viejo

## El síntoma, en lenguaje de usuario

Ana me pagó 25 y lo aprobé en el Inbox a mi cuenta del banco. Después Ana corrige la liquidación a 30 desde su
dispositivo. En mi cuenta de grupos la liquidación ya cuenta 30, pero mi banco sigue con 25 y nadie me avisa.

## Lo medido (leyendo código)

- `GroupsSyncClient.applySettlement` aplica el `amount` remoto sobre la liquidación existente y la re-puentea siempre.
- `bridgeSettlement` rehace la pata virtual con el importe nuevo. Desde el ticket padre, con la marca de aprobación no
  vuelve a preguntar (antes preguntaba otra vez, y aprobado contaba doble).
- La transacción real es independiente por diseño (D7 de `DraftService`): no sigue las ediciones de la liquidación.
- La app iOS no edita liquidaciones; el caso pide otro cliente que sí lo haga (inferido).

## Qué hay que decidir

- Avisar en el Inbox de que la liquidación cambió («Ana corrigió el pago a 30: ¿ajusto tu cuenta?»), o
- aceptar la divergencia porque la transacción real es de la persona (D7) y el importe del banco es el que ella registró.

## Relacionados

- [[settlement-approval-leaves-no-trace-so-a-rebridge-asks-again]]

## Resolución (2026-10-05, decisión A de Jürgen)

**Qué cambia para quien usa la app.** Si alguien corrige el importe de una liquidación que ya aprobaste en tu cuenta, el
Inbox te avisa: «Cambió el pago de Ana en «Viaje»: era S/ 25 y ahora es S/ 30. En Banco tienes registrados S/ 25». Puedes
**ajustar** tu movimiento al importe nuevo o **dejarlo** como está. Ajustar cambia ese movimiento (no crea otro); dejarlo
no toca nada y el aviso pasa a Archivados. La misma corrección no vuelve a preguntar; una segunda sí, con la cifra al día.

**Cómo.**
- El aviso es un borrador `.groupSettlement` pendiente con `originReasonKey` propio
  (`DraftOriginReason.settlementAmountChanged`, `InboxDraft.isSettlementAmountChangeNotice`). Sin campos nuevos.
- **No se enlaza a la transacción**: `approvedTransaction` es uno a uno con `TransactionItem.approvedDraft`, y enlazarlo le
  quitaba el enlace a la marca (lo cazaron las tres lentes de la review). La transacción se resuelve siempre por la marca
  viva (`GroupTransactionBridge.amountChangeTarget`).
- La referencia es el importe de la marca: ajustar mueve la transacción y la marca juntas; dejarla rechaza el aviso, y el
  rechazado con el importe de hoy es la decisión que evita volver a preguntar.
- Decide `GroupSettlementAmountChangeLogic.plan` (pura); aplica `reconcileAmountChangeNotices` al final de
  `bridgeSettlement` (todo cambio remoto pasa por ahí) y `reconcileSettlementAmountChangeNotices` en frío, junto a la poda.
- Sin aviso si: no hay una sola marca viva, la transacción está en otra divisa o ya tiene el importe nuevo, o la
  liquidación cambió de sentido.
- Los avisos quedan fuera de todo lo que lee la marca (resolución del re-puente, sustitución, poda en frío) y
  `computeFreezePlan` los borra (convertidos a manual, aprobarlos crearía otra transacción). No se borran desde el Inbox
  ni se aprueban deslizando o en lote (`requiresApprovalForm`): se deciden en su hoja.

**Lo que queda fuera.**
- Cambio de sentido o de divisa de la liquidación: [[settlement-direction-edited-after-approval-leaves-the-bank-stale]].
- Un build anterior al 2026-09-28 puede registrar el aviso dos veces:
  [[settlement-amount-change-notice-on-a-build-before-the-approval-mark]].
- El aviso rechazado en Archivados se lee como un pago rechazado:
  [[settlement-amount-change-notice-archived-row-reads-as-a-rejected-payment]].
- Dos marcas vivas de la misma liquidación (dos dispositivos que aprobaron a la vez, ya conocido): no hay aviso.
- El servidor no dice quién editó: el texto nombra a la otra persona del pago, no al autor del cambio.
