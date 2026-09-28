---
id: settlement-amount-edited-after-approval-leaves-the-bank-stale
status: backlog
priority: low
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
