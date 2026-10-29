---
id: inbox-deleting-two-drafts-in-a-row-crashes
status: qa
priority: high
area: inbox
created: 2026-10-29
updated: 2026-10-29
source: "tablero f8rj (Jürgen, TestFlight 2.2 (2), iOS 27.2), encargo 2026-10-29-bandeja-crash-borrar-dos-seguidos"
qa-status: needs-testing
---

# Borrar dos registros seguidos en la Bandeja cerraba Yala

## Qué pasaba

Jürgen, 29-oct, 07:48, TestFlight 2.2 (2) en iOS 27.2: «Crasheó mi Yala cuando eliminé dos registros de bandeja
seguidos». El informe (`EXC_BREAKPOINT`, `_assertionFailure` de SwiftData) va de `body` → `Button.init(action:label:)` →
la etiqueta de la fila → un getter de SwiftData: una fila de la Bandeja (`InboxDraftRowView`) leía un `InboxDraft` ya
borrado. En iOS 27.x leer un modelo borrado aborta la app; el simulador 27.0 no aborta, y por eso no se reproduce aquí.

No se pudo simbolizar: no hay dSYM ni archive del build 2 en la Mini, y recompilar ese commit (`350818387`) en Release
da otro binario (UUID distinto, direcciones sin relación).

## Causa

Tres caminos dejaban una fila montada con su borrador ya borrado:

1. **«Eliminar para siempre» desde el editor** (lote 4, 14-oct): `DraftService.deleteDraft` borraba sin podar la fila,
   que seguía montada bajo la hoja. `DraftService` ya tenía `deleteInboxDraftPruningRow` («obligatorio… la fila
   re-renderiza aunque esté cubierta por un sheet», el crash de 2.0.5), pero `deleteDraft` y `bulkDelete` no lo usaban.
2. **Dos borrados seguidos deslizando:** la fila se quita en el acto y el borrado va 400 ms después. La recarga que
   cierra el primero volvía a meter en la lista el segundo, aún sin borrar (medido en el simulador con la espera
   alargada: el segundo reaparecía), y su fila estaba montada cuando se borraba.
3. **Cualquier borrado por otro camino** (sincronización, un servicio): el borrador se quedaba en el array de la Bandeja
   hasta la siguiente recarga.

## Qué se hizo

- `deleteDraft` y `bulkDelete` podan la fila antes de borrar.
- La Bandeja apunta lo que espera su borrado o descarte diferido, y ninguna recarga lo devuelve hasta que termina
  (`InboxViewModel.beginRemoval`/`endRemoval`), como ya hacen Registros y Pagos planificados.
- La lista no ofrece a la vista un borrador que ya no se puede leer, y la fila no lee nada de un borrador borrado
  (`InboxDraft.isReadableInInbox`).
- El mismo caso en **Registros**: borrar desde el editor deja la fila montada hasta que la lista recarga por
  `dataVersion`. `RecordRowView` no lee un registro borrado.
- Pagos planificados ya escondía lo que espera borrarse; Grupos recarga la lista en el mismo turno del borrado. Lo que
  queda en Grupos y en los formularios va en `forms-read-their-deleted-model-while-closing`.
- Seam de QA `-uitest-inbox-removal-delay-seconds` (solo alarga la espera de 400 ms) para que el XCUITest caiga dentro
  de la carrera.

## Verificación

- Unit: `InboxPendingRemovalTests` (3), `InboxRowPruneCoordinatorTests` (+2) y `DeletedModelRowGuardWiringTests`. Con
  el comportamiento viejo (mutantes) caen los cinco casos de mecanismo.
- XCUITest (`InboxCrudUITests`): dos borrados seguidos deslizando (con la espera alargada a 10 s; con el comportamiento
  viejo sale rojo: «el segundo —aún sin borrar— volvió a la lista»), descartar + borrar + Deshacer, y dos borrados
  seguidos desde el editor. La suite entera, 9/9.

## QA en el iPhone (Jürgen)

El cierre solo pasaba en el iPhone. Con un build que traiga este cambio (Yala Dev o el TestFlight 2.2 (4)), y al menos
cuatro borradores en la Bandeja (crea gastos por voz o foto y no los guardes):

1. Abre la Bandeja. Desliza un borrador a la izquierda, toca «Eliminar», y en seguida haz lo mismo con el de debajo.
2. Repite con los dos siguientes, lo más rápido que puedas.
3. Abre un borrador, toca «⋯» → «Eliminar para siempre» → «Eliminar». Al volver a la lista, abre otro y haz lo mismo.
4. Desliza un borrador del todo (va a Archivados), borra otro deslizando y toca «Deshacer» en el aviso.

Sale bien si la app no se cierra en ningún paso, los borrados no vuelven a la lista y el descartado vuelve con
«Deshacer».
