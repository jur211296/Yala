---
id: groups-archived-still-accepts-changes
status: backlog
priority: low
area: groups
created: 2026-09-06
updated: 2026-10-08
source: hallazgo al revisar el copy en groups-archived-group-rejects-join (2026-09-06)
---

# «Archivado» promete que el grupo no acepta cambios, y sí los acepta

## Qué le pasa al usuario

La app dice, en 16 idiomas: **«Su admin lo archivó y ya no acepta cambios.»**
(`groups.reconnect.archived.body`).

No es verdad para nadie que ya esté dentro. En un grupo archivado se puede **crear un gasto,
editarlo, borrarlo, liquidar una deuda, confirmarla, cambiar los ajustes del grupo, invitar gente y
aprobar o rechazar solicitudes** — todo, exactamente igual que en un grupo activo. Archivar es hoy
**cosmético**: manda la tarjeta a la sección plegable «Ver archivados» y le baja la opacidad.

Y el detalle es alcanzable a propósito: esa sección abre la vista con el mismo `groupCardRow` que las
activas, y entrar a un archivado es un destino legítimo y documentado
(`GroupDetailDismissDecision`).

## Cómo salió esto

Al implementar [[groups-archived-group-rejects-join]], cuyo AC pedía literalmente «revisar que el
cuerpo del copy siga siendo verdad palabra por palabra». Se revisó, y no lo era.

**Para quien recibe ese aviso la frase sí es verdad**: intentó un cambio —entrar al grupo— y el
grupo no lo aceptó. Ese ticket queda cerrado y coherente. Lo que este ticket recoge es la **lectura
universal** de la frase, que sigue sin cumplirse.

## Lo medido (2026-09-06)

**Cliente.** El único predicado que gobierna las acciones del detalle es
`GroupDetailViewModel.swift:93-98`:

```swift
var canCurrentUserParticipate: Bool {
    if group.isMigratedFrozen { return false }
    return currentUserMember?.isActive == true
}
```

`isArchived` no aparece. De él cuelgan el FAB de nuevo gasto (`GroupDetailView.swift:147`), editar y
borrar gastos (`:443-444`), y liquidar / confirmar / rechazar / borrar liquidaciones (`:472-475`).
Invitar y aprobar van por `canActAsAdmin` (`GroupMembersView.swift:176`), que tampoco lo mira.

**Servicios.** `GroupExpenseService.validateGroupIsWritable` (`:580-582`) y
`GroupService.validateGroupIsWritable` (`:140-142`) comprueban **solo** `isMigratedFrozen`. Ese guard
cubre `createExpense`, `updateExpense`, `deleteExpense`, `createSettlement`, `confirmSettlement`,
`deleteSettlement`, `updateGroup`, `transitionPendingMember`, `removeMemberLocal` y `changeRole`.

**Servidor** (medido contra producción el 2026-09-06): en todo el esquema, `is_archived` solo aparece
en `create_group`, `migrate_group` y `groups_pull_rows_split_groups` — siempre como dato que se
**transporta**. Ninguna función lo consulta como gate. Con g13_05 hay ahora exactamente **una**
excepción: `join_group`.

**El único sitio del cliente que sí excluye archivados** es `GroupExpenseEligibilityLogic.swift:36`,
y sus consumidores son el FAB del **tab** de Grupos y la conversión de un borrador del Inbox — es
decir, «¿a qué grupo puedo añadir un gasto desde fuera?». Nada del detalle.

**Evidencia en device, ya en el repo:** `tickets/qa/groups-tab-missing-panel-perf.md:379-384` recoge
un QA real en el que, tras entrar a un grupo archivado, «detrás sigue el detalle
(`group_detail_fab_new_expense`)».

## La decisión que hace falta (Jürgen)

No se toca nada hasta que se decida, porque **cambiar la semántica de «archivado» no es un fix**:

1. **Archivar congela el grupo** (hace verdad el copy entero). Es lo que la palabra sugiere y lo que
   ya hace `isMigratedFrozen`, así que el molde existe. Coste: hay que decidir qué pasa con las
   deudas abiertas de un grupo archivado —hoy se pueden liquidar, y congelar quitaría esa salida— y
   revisar si el freeze es solo local o también server-side.
2. **Ajustar el copy** para que diga solo lo que es verdad (p. ej. que no admite gente nueva y queda
   fuera de listas y resúmenes). Barato, y no rompe a nadie que use el archivado como «guardar sin
   perder el acceso».
3. **Dejarlo como está.** Defendible: el copy solo se enseña hoy en el camino del join, donde es
   verdad. El riesgo es que el siguiente que lo reuse —el copy está traducido y a mano— lo ponga en
   un sitio donde vuelva a mentir, que es exactamente cómo nació este ticket.

La 1 y la 2 son opuestas y las dos son razonables; la elección depende de qué es «archivar» en Yala,
y eso no lo decide quien implementa.

## Relacionados

- [[groups-archived-group-rejects-join]] — el ticket que destapó esto al revisar el copy.
- [[rejected-member-cold-tap-does-nothing]] — donde se anotó por primera vez que el copy mentía.

## Medido en 2.1 (triage 2026-10-08)
- `canCurrentUserParticipate` vive hoy en `GroupDetailViewModel.swift:101-106`; sigue sin mirar `isArchived`.
- `validateGroupIsWritable`: `GroupExpenseService.swift:580` y `GroupService.swift:140`, solo `isMigratedFrozen`.
- El copy `groups.reconnect.archived.body` (`L10n.Groups.Reconnect.archivedBody`) se usa en un único sitio: `ContentView.swift:1216`, el aviso del join, donde es verdad.

## Pregunta para Jürgen (triage 2026-10-08)
- **A.** Archivar congela el grupo (molde `isMigratedFrozen`), decidiendo antes qué pasa con las deudas abiertas.
- **B.** Ajustar el copy para que diga solo lo verdadero (no admite gente nueva, sale de listas y resúmenes). Barato, sin cambiar semántica.
- **C.** Dejarlo: hoy el copy solo sale donde es verdad.
- **Recomendación: B** — cierra el riesgo de reuso del copy sin quitarle a nadie la salida de liquidar. Con B, prioridad `low`.

Triage 2026-10-08: abierto · medium → low · Sigue igual: ningún predicado del detalle ni de los servicios mira isArchived; necesita decisión de producto (pregunta añadida, recomendada B: ajustar el copy).
