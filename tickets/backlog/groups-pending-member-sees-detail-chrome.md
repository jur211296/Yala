---
id: groups-pending-member-sees-detail-chrome
status: backlog
priority: very-low
area: groups
created: 2026-09-06
updated: 2026-10-08
---

# Dentro del grupo, Miembros y Ajustes no miran el estado del miembro

## De dónde sale

Hallazgo lateral, **medido y no corregido**, de `groups-pending-member-can-open-group` (la puerta del
grupo para un pendiente, decisión del owner del 2026-09-06). Al auditar qué vería un
`pendingApproval` dentro del detalle apareció esto. No se arregló allí porque **hoy es inalcanzable**:
ese mismo trabajo cerró las tres puertas que llevaban al detalle.

Se abre igualmente porque la ausencia de gate es real, está medida, y la única razón de que no muerda
es un invariante de otra capa. Si mañana alguien añade una cuarta vía al detalle —y ya hubo tres, dos
de ellas sin gate hasta ayer— esto es lo que se encuentra.

## Lo medido (árbol `encargo/2026-09-06-groups-pending-member-can-open-group`)

`GroupDetailView` gatea correctamente **todas las escrituras de gasto** por
`viewModel.canCurrentUserParticipate` (`GroupDetailViewModel:93-98` → `currentUserMember?.isActive ==
true`): el FAB de nuevo gasto, tocar/editar/borrar un gasto, liquidar, confirmar y rechazar una
liquidación, e invitar. Eso está bien y no es lo que dice este ticket.

Lo que **no** mira el status:

| Elemento | Dónde | Gate hoy |
|---|---|---|
| Toolbar **Miembros** (abre el roster) | `GroupDetailView:172-197` | ninguno |
| Toolbar **Ajustes** | `:199-209` | ninguno |
| Chips Gastos / Balances / Estadísticas | `:381-422` | ninguno |
| Banda de balance del header (+ tap → Balances) | `:454-460` | ninguno |
| **«Salir del grupo»** dentro de Ajustes | `GroupSettingsView:133-135, 593-617` | `currentOffer.showsLeave`, cuyo fallback es `!group.isOwner` — **no** el status |

`GroupDetailViewModel` **no expone** hoy ninguna propiedad del tipo `isCurrentUserPending`: la vista lo
lee inline (`viewModel.currentUserMember?.isPendingApproval == true`, `:136`). Sí existe ya el booleano
de escritura (`canCurrentUserParticipate`), que es el que gatea todo lo de arriba que sí está gateado.

**El contenido financiero no se filtra por status en el fetch** (`fetchData()`, `:204-234`): trae la
zona entera del store local. Para un pendiente real eso está vacío porque el servidor no se lo entrega
(`is_group_writer` reserva `split_expenses`/`split_shares`/`split_settlements` a `active`, medido
contra producción el 2026-09-04) — o sea que **no es una fuga**: es que el cliente no tiene su propia
red, y depende enteramente de la del servidor.

## Por qué es `low` y no `high`

Las tres vías conocidas al detalle pasan desde el 2026-09-06 por
`GroupCardDisplayLogic.allowsDetailEntry`. Sin camino, esto no se puede ejercitar. Es
defensa-en-profundidad, no un bug con síntoma.

## Lo que habría que decidir antes de tocar nada

No está claro que la respuesta sea «gatear todo por `.active`», y por eso esto es un ticket y no un
fix pendiente:

1. **Miembros**: un pendiente sí puede ver el roster por diseño (`group_members` va por
   `is_group_member`, y la sala de espera lo necesitaba). Cerrarlo aquí contradiría esa decisión.
2. **Salir del grupo**: para un pendiente sería *retirar mi solicitud*, que hoy no existe como acción
   de producto y que el AC del ticket padre prohibió inventar. Puede ser una feature deseable — o no.
3. Si se decide gatear, el sitio es una propiedad nueva del ViewModel (junto a
   `canCurrentUserParticipate`), no condiciones sueltas repartidas por la vista.

## Relacionado

- `tickets/qa/groups-pending-member-can-open-group.md` — la puerta. De ahí sale esto.
- `tickets/qa/guest-decline-has-no-screen.md` — la sala de espera y su copy.

## Medido en 2.1 (triage 2026-10-08)

- `GroupDetailView` sigue gateando solo las escrituras por `canCurrentUserParticipate` (`GroupDetailViewModel.swift:101`); Miembros, Ajustes, los chips y la banda de balance siguen sin mirar el estado, y el ViewModel sigue sin `isCurrentUserPending`.
- Las tres vías al detalle siguen pasando por `GroupCardDisplayLogic.allowsDetailEntry` (vía `GroupsViewModel`), así que sigue siendo inalcanzable: defensa en profundidad sin síntoma.

Triage 2026-10-08: abierto · low → very-low · sigue sin gate por estado dentro del detalle, pero ninguna vía lleva ahí a un pendiente; es defensa en profundidad.
