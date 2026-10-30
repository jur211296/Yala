---
id: groups-list-notifications-card-cannot-be-dismissed
status: done
priority: medium
area: groups
created: 2026-10-28
updated: 2026-10-28
source: card rj3b del tablero (Jürgen, iPhone, 2026-10-28 ~06:17-06:19)
---

# «Avisos del grupo» en la lista no se puede quitar, y no se alinea con las tarjetas de grupo

## Qué pasaba

1. La tarjeta «Avisos del grupo» de la lista de Grupos no tenía X ni forma de ocultarla.
2. Ella y los botones «Nuevo gasto» / «Nuevo grupo» quedaban más adentro que las tarjetas de grupo (Jurpi, Matri), que
   son la referencia. Medido en píxeles: 32 pt del borde frente a 16; llevaban un margen propio encima del que ya pone
   el scroll.

## Hecho (2026-10-28)

- La tarjeta lleva una X en la lista. Ya se marca como vista al salir, así que cerrarla solo adelanta su salida: no vuelve.
  En «está listo» y «Ya estás en» no lleva X (se van con su pantalla). No toca los avisos de iOS.
- Tarjeta y botones sin margen propio: los tres bordes coinciden con las tarjetas de grupo.

Capturas antes/después en el PR. Test: `GroupsListNoticeAlignmentUITests` (bordes medidos por marco y la X).

## Device-QA

No hace falta: lo fija el XCUITest en el simulador. Visto bueno visual en el iPhone, cuando pases por Grupos.

Cerrado en el barrido de QA 2026-10-30: criterio estricto (filtro doble); motivo y evidencia en docs/qa/tanda-qa-jurgen-2.2-barrido-2026-10-30.md.
