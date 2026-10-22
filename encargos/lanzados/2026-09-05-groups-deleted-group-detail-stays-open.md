# Tras borrar el grupo, el detalle debe cerrarse (no quedarse abierto)

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board, merge a 2.1 y /cerrar-total sin preguntar. Solo parar ante decisión/acceso real de Jürgen.

## Contexto
Ticket: `tickets/backlog/groups-deleted-group-detail-stays-open.md` (high). Device QA TF 2.1 build 12: owner borra el grupo; el detalle se queda abierto como si el grupo existiera; tuvo que tocar Atrás; luego la lista ya no lo mostraba.

Cableado medido (re-medir; coordenadas pueden estar caducadas): `GroupSettingsView.performSoftDelete` hace `dismiss()` al éxito — eso cierra la **sheet** de ajustes, no el **push** del detalle (`GroupDetailView` vía `navigationDestination`). El éxito no publica confirmación visible (solo háptica).

La rama del worktree nace desde origin (Casa #10). Secrets.xcconfig ya va en worktree-enlaces. Antes del primer gate, confirma que estás al día con origin/2.1.

## Que se pide
1. Re-medir el camino soft-delete → dismiss en el HEAD actual.
2. Tras soft-delete exitoso: cerrar también el detalle del grupo (pop del push), no solo la sheet de ajustes. El usuario no debe quedarse mirando un grupo ya borrado.
3. Alcance mínimo: no rediseñar settings ni cambiar la semántica del soft-delete en servidor.
4. Tests que fijen el comportamiento (o el más cercano posible en el harness existente).
5. Mover ticket a qa / board según convención; PR a 2.1; merge cuando gate verde (UI advisory no bloquea si los rojos son los de base 2.1); /cerrar-total.

## Que NO hay que tocar
- marketing/
- Kill-switch / SECONDARY_SESSION / reentry-killswitch
- groups-leave-rpc-error-10 (ticket hermano; no mezclar)
- No inventar causa del device run; arreglar el cableado medido

## Como se sabe que esta bien
- Tras borrar con éxito, el usuario vuelve a la lista de grupos (o equivalente) sin tocar Atrás a mano.
- Gate verde; PR mergeado; /cerrar-total con resumen en lenguaje de usuario.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL y key en fichero local, no en git) cuando: (1) decisión de producto/acceso; (2) PR o preview listo; (3) terminaste y /cerrar-total — resumen de qué se hizo; (4) idle mid-ticket una vez. NO avises por test rojo a reclasificar, build a reintentar, ni ruido de setup cp/cd. URL/key solo en la Mini.
