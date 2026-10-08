---
id: settlement-direction-edited-after-approval-leaves-the-bank-stale
status: backlog
priority: very-low
area: "groups, sync"
created: 2026-10-05
source: "review adversarial de `settlement-amount-edited-after-approval-leaves-the-bank-stale` (2026-10-05, lente de dinero); leído en código, NO reproducido"
updated: 2026-10-08
---

# Si otra persona cambia el sentido o la divisa de una liquidación que ya aprobé, mi banco no se entera

## El síntoma, en lenguaje de usuario

Le pagué 25 a Ana y lo aprobé a mi banco. Después alguien corrige la liquidación: en realidad Ana me pagó a mí, o el pago
fue en dólares y no en soles. En mi cuenta de grupos la liquidación cambia, pero mi banco sigue con el movimiento viejo y
el Inbox no me avisa.

## Lo medido (leyendo código)

- `GroupsSyncClient.applySettlement` aplica `from_member_key`, `to_member_key` y `currency_code` remotos y re-puentea.
- El aviso de importe cambiado (`GroupSettlementAmountChangeLogic.plan`) se calla a propósito en los dos casos: con el
  sentido invertido (`expectsOutflow` no casa con el signo de la marca) y con la transacción en otra divisa. Ajustar solo
  con el importe conservaría el signo viejo, o escribiría la cifra en la divisa equivocada.
- La app iOS no edita liquidaciones; el caso pide otro cliente (inferido).

## Qué hay que decidir

- Avisar también de estos cambios, con otro texto y otro «Ajustar» que cambie el signo o convierta la divisa, o
- aceptarlo: la transacción real es de la persona (D7) y estos cambios son raros.

## Relacionados

- [[settlement-amount-edited-after-approval-leaves-the-bank-stale]]

## Medido en 2.1 (triage 2026-10-08)

- `GroupSettlementAmountChangeLogic.plan` sigue callándose con `expectsOutflow` invertido y con otra divisa; el fichero no tiene commits tras `e1b3999bc`.
- Confirmado que la app iOS no edita liquidaciones: `SettlementFormView` solo crea, y no hay otro cliente de grupos en 2.1. Hoy nadie puede provocar el cambio de sentido o de divisa.

Triage 2026-10-08: abierto · low → very-low · sigue sin avisar, pero ningún cliente de 2.1 puede editar el sentido o la divisa de una liquidación, así que hoy no es alcanzable.
