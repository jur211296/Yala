---
id: wipe-division-complement-can-be-bridged-twice
status: backlog
priority: low
area: "groups, sync"
created: 2026-09-28
updated: 2026-10-08
source: "review adversarial de `a-wipe-on-a-device-without-the-groups-loses-their-rows-everywhere` (lente de grupos, 2026-09-28); inferido leyendo código, NO reproducido"
---

# Lo que el dispositivo que vació recibe después por su canal lo repone también el receptor

## El síntoma, en lenguaje de usuario

Vacío mis datos en el iPad nada más abrirlo, con los grupos aún poniéndose al día. Luego abro el iPhone. Algún gasto de
grupo sale dos veces, con dos borradores de «¿de qué cuenta salió?»; si apruebo los dos, el banco lo cuenta doble.

## Lo medido (2026-09-28, leyendo código)

- El reparto del origen lleva los gastos que tenía AL VACIAR. El receptor repone el resto
  (`GroupsRemoteWipeDivision`).
- Lo que al origen le llega después por su canal lo puentea su sync de grupos. Si el receptor converge antes de que le
  lleguen esas filas por el espejo, los dos crean las suyas.
- `DraftService.approveGroupExpenseAccountDraft` no comprueba si el gasto ya tiene transacción real, y aprobar no borra
  el borrador hermano (`withSkippedDraftCleanup`).
- Antes del reparto, en el orden normal, solo lo puenteaba el origen. En la práctica el canal se pone al día en segundos
  al abrir la app, antes de llegar a Ajustes.

## Qué hay que decidir

Si aprobar un borrador de gasto de grupo comprueba que no exista ya una transacción real del mismo `splitExpenseID` (cierra
el dinero doble para este caso y para el residual general de «cada dispositivo con grupos puentea lo que le llega»).

## Relacionados

- [[a-wipe-on-a-device-without-the-groups-loses-their-rows-everywhere]]

## Medido en 2.1 (triage 2026-10-08)

- `DraftService.approveGroupExpenseAccountDraft` (~905-975) sigue insertando la transacción real sin buscar una existente con el mismo `splitExpenseID`.
- `GroupsRemoteWipeDivision.swift` solo cambió desde el 2026-09-28 por `50ab2e890` (retirada de la devolución tardía), que no toca el reparto.

Triage 2026-10-08: abierto · low → low · aprobar sigue sin comprobar la transacción existente; hace falta vaciar con los grupos aún poniéndose al día.
