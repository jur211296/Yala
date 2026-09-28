---
id: settlement-approval-leaves-no-trace-so-a-rebridge-asks-again
status: backlog
priority: medium
area: "groups, sync"
created: 2026-09-27
source: "review adversarial de `late-remote-wipe-on-a-device-without-groups-cannot-return-the-rows` (2026-09-27, lentes de dinero y de sync); leído en código, NO reproducido"
---

# Una liquidación ya aprobada vuelve a pedir su cuenta si otro dispositivo se lleva su pata

## El síntoma, en lenguaje de usuario

Vacío mis datos en el iPhone. Vuelven los gastos y las liquidaciones de grupo, y en el Inbox apruebo «Ana me pagó 25» en
mi cuenta del banco. Días después abro el iPad, que procesa el vaciado tarde. Al volver a abrir el iPhone, el Inbox me
pide otra vez a qué cuenta llegó ese pago. Si lo apruebo, el banco suma 25 dos veces. El borrador de una liquidación no
se puede rechazar ni borrar.

## Lo medido (leyendo código)

- Aprobar el borrador de una liquidación crea la transacción real SIN `splitSettlementID` (`DraftService.swift`, D7) y
  borra el borrador. No queda nada que diga «esta liquidación ya se aprobó».
- La convergencia y la devolución por declaración (`GroupsRemoteWipeReturn`) re-puentean solo las liquidaciones que se
  quedaron sin ninguna pata. Esa guarda no ve la real aprobada, así que no la protege.
- Hay dos caminos que llegan aquí:
  1. El receptor tardío importó la pata virtual pero todavía no la real aprobada. Se lleva la virtual, y la liquidación
     queda sin patas donde se re-puentea.
  2. La aprobación ocurre entre el borrado del receptor y la llegada de ese borrado al origen. Es la ventana que ya anota
     `wipe-data-group-rows-return-only-on-the-next-cold-launch`.
- `DraftService` no deja rechazar ni borrar un borrador `groupSettlement`, así que la persona no puede quitarlo del Inbox.

## Qué hay que decidir

La causa es que la aprobación no deja rastro. Hay tres salidas posibles, y las tres cambian D7:

- Que la transacción real conserve un enlace (otro campo, porque `splitSettlementID` la haría «pata» para el bridge).
- Que la aprobación deje una marca durable que viaje por el espejo.
- Que el re-puente de una liquidación no cree borrador cuando la virtual ya se aprobó alguna vez.

## Relacionados

- [[late-remote-wipe-on-a-device-without-groups-cannot-return-the-rows]]
- [[late-remote-wipe-signal-undoes-the-rows-the-origin-reconverged]]
- [[wipe-data-group-rows-return-only-on-the-next-cold-launch]]
