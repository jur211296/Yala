---
id: wipe-division-takeover-can-cross-a-late-origin-before-the-mirror
status: backlog
priority: low
area: "groups, sync"
created: 2026-09-28
updated: 2026-10-08
source: "review adversarial de `wipe-division-exclusion-trusts-the-origin-to-converge` (lente de sync y dinero, 2026-09-28); inferido leyendo código, NO reproducido"
---

# Si el dispositivo que vació repone justo cuando el otro deja de esperarle, un gasto o un pago de grupo sale dos veces

## El síntoma, en lenguaje de usuario

Vacío mis datos en el iPad y no lo abro en tres días. Lo abro justo cuando el iPhone ya había repuesto por su cuenta los
gastos de grupo, antes de que le llegaran los del iPad. Algún gasto o pago de grupo sale dos veces, con dos borradores; si
apruebo los dos, el banco lo cuenta doble.

## Lo medido (2026-09-28, leyendo código)

- Pasadas 72 horas desde que resuelve el reparto, el receptor repone lo prometido que no tiene ninguna fila posterior a la
  señal (`GroupsRemoteWipeDivision.takeOverIfOverdue`).
- Si el origen converge antes de ver esas filas por el espejo, los dos crean las suyas. En los gastos, el siguiente
  re-puente del gasto concilia. En las liquidaciones no: casi nunca se editan, y la poda del arranque
  (`pruneSettlementDraftsAlreadyResolved`) solo retira pendientes cuando hay una marca de aprobación o de rechazo.
- Lo mismo con dos receptores con grupos que dejan de esperar a la vez (tres dispositivos o más).
- Antes del cambio esos ids no volvían nunca. Ahora vuelven, con este riesgo en una ventana de segundos a minutos.

## Qué hay que decidir

Si el arranque concilia los pendientes duplicados de una misma liquidación, o si aprobar el segundo borrador comprueba que
el pago ya esté registrado. Lo segundo cubre también `wipe-division-complement-can-be-bridged-twice`.

## Relacionados

- [[wipe-division-exclusion-trusts-the-origin-to-converge]]
- [[wipe-division-complement-can-be-bridged-twice]]

## Medido en 2.1 (triage 2026-10-08)

- `GroupsRemoteWipeDivision.takeOverIfOverdue` y `pruneSettlementDraftsAlreadyResolved` (`AppBootstrapper`, ~1798-1803) siguen sin conciliar dos pendientes de la misma liquidación.
- Aprobar sigue sin comprobar si el gasto ya tiene transacción real: el mismo hueco que `wipe-division-complement-can-be-bridged-twice`.

Triage 2026-10-08: abierto · low → low · sigue igual; es una ventana de segundos a minutos tras 72 h de espera.
