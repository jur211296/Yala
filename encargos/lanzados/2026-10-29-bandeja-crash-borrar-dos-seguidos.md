---
esfuerzo: high
---
# Arreglar el crash de SwiftData al borrar dos registros seguidos en la Bandeja (y el mismo patrón en otras listas)

Cierre: **cierra-sola** → al terminar, `/cerrar-total`.
Versión **2.2**. Base `origin/2.2`. Slug: `bandeja-crash-borrar-dos-seguidos` · Sesión cola **S27h** · al cerrar → **S27tf** (TestFlight 2.2 (4)).
Card: `tablero ver tablero-borrar-dos-registros-seguidos-en-la-band-f8rj`.

## Contexto
Jürgen (2026-10-29 07:48 Lima, TestFlight 2.2 (2), iOS 27.2): «Crasheó mi Yala cuando eliminé dos registros de bandeja seguidos». Log: `~/Claude/tmp-frank/crash-bandeja-2026-10-29-0748.ips`.
Lectura previa (por confirmar): EXC_BREAKPOINT por `_assertionFailure` dentro de SwiftData, llamado desde código de Yala en un `Button.init` dentro del body de una vista SwiftUI. Casi seguro una fila de la Bandeja lee una propiedad de un modelo ya borrado al volver a pintar tras el segundo borrado.
El PR #681 (pagos planificados: Deshacer de varios borrados y borradores de la Bandeja) tocó esta zona después del build 2: puede agravarlo o ya arreglarlo. Verifícalo sobre `origin/2.2`.

## Qué se pide
1. Simbolizar el .ips con el dSYM del build 2.2 (2) si está en la Mini (Xcode Organizer / archives / `mdfind` por UUID). Si no está, reproducir en simulador: borrar dos registros seguidos de la Bandeja, también con Deshacer de por medio.
2. Escribir primero un test que falle (unit o XCUITest) y que reproduzca el crash.
3. Arreglar la causa de raíz: las filas no leen propiedades de modelos borrados (comprobar `isDeleted` / `modelContext == nil`, o pintar desde un snapshot de valores). Nada de parches que solo escondan el crash.
4. Revisar el mismo patrón en las otras listas con borrado (Registros, pagos planificados, Grupos). Arreglar lo que sea claramente igual y, para lo que no quepa, ticket + card en backlog.
5. Un solo PR a 2.2 en auto-merge. Card a in progress con `--agente frank` al empezar; al cerrar, in qa (device-QA de Jürgen en iPhone) o done.

## Qué NO tocar
- La lógica de Deshacer y borradores de #681 más allá de lo que pida el arreglo.
- marketing/ y Web/ (Lola). No lanzar otras sesiones Yala.

## Reglas de Mini
Pipeline serial: limpiar → build `xcodebuild -jobs 2` sin sim → boot 1 sim → tests → apagar sim. Al lanzar y al cerrar, borra el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen, sin preguntar; no toques las de un worktree vivo. Haz un solo fetch y rebase sobre `origin/2.2` antes de abrir el PR; no esperes el CI de otro PR.

## Cómo se sabe que está bien
El test falla antes y pasa después; borrar dos (o más) seguidos, con y sin Deshacer, no cierra la app; el crash está explicado con su stack simbolizado o con la reproducción.

/cerrar-total

## Paso 0 (Frank, 2026-10-29)

- **Simbolizar:** no hay dSYM ni archive del 2.2 (2) en la Mini (`mdfind` por el UUID `A1E82D89…` y `~/Library/Developer/Xcode/Archives` vacíos). Se explica por reproducción + el stack sin simbolizar: `body` → `Button.init(action:label:)` → etiqueta de la fila → getter de SwiftData → `_assertionFailure`. Es el `Button(action: onTap) { … draft.hasAllRequiredFields … }` de `InboxDraftRowView`.
- **Causa:** `InboxView.removeDraftWithAnimation` quita la fila en el acto y borra 400 ms después; cada recarga en esa ventana (la del borrado anterior, o un `dataVersion`) vuelve a meter en la lista el borrador que aún espera, y su fila lee el `InboxDraft` cuando se borra. Registros y Pagos planificados ya esconden lo que espera borrarse en cada recarga (`RecordPendingDeletion`, `ScheduledPaymentPendingDeletion`); la Bandeja no.
- **Arreglo (asumido):** el `InboxViewModel` apunta lo que espera su borrado/descarte diferido y la recarga no lo devuelve hasta que el diferido termina (con éxito o no). Segunda red, la que pide el encargo: la fila no pinta un borrador borrado (`isDeleted` / sin `modelContext`), el molde de `BudgetDetailView` y `AccountDetailSheet`.
- **Lógica de #681:** no se toca.
- **Otras listas:** Registros y Pagos planificados ya tienen el patrón bueno; Grupos borra desde la hoja de edición con recarga en el mismo turno. Lo que no sea claramente igual va a ticket + card.
- **Device-QA:** el crash salió en iOS 27.2 en el iPhone; el simulador es 27.0. Ticket a `qa` con guion para Jürgen.
