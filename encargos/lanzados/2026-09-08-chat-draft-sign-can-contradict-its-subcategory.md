# Un borrador del chat puede nacer marcado gasto con subcategoría de ingreso

## Contexto
Cola autónoma de mediums (Jürgen 2026-09-08): tras cerrar goldens-de-staging-solo-pasan-a-trozos (#104/#105 mergeados a 2.1), sigue este ticket. Arrancas en contexto limpio sobre origin/2.1.

Ticket: tickets/backlog/chat-draft-sign-can-contradict-its-subcategory.md
Origen: review adversarial de chat-draft-drops-the-expense-sign. Al firmar el monto, un borrador Gasto + subcategoría de ingreso se guarda como «ingreso negativo»: Registros/Estadísticas restan y el widget de inicio suma.

Causa medida: `suggestSubcategory(merchant:)` (fallback por comercio) no filtra por `isExpense`; la vía con hint sí. La validación de naturaleza solo corre si el usuario cambia la subcategoría a mano.

## Que se pide
- Que `suggestSubcategory` no devuelva una subcategoría cuya naturaleza contradiga `isExpense`, o que `saveDraft` rechace la combinación incoherente.
- Decidir quién manda cuando discrepan: la intención del usuario (`isExpense`) o la categoría — y documentarlo.
- Test con la combinación cruzada.
- Al cerrar: gate, commit, board + actualizar `docs/TICKETS.md`, merge y `/cerrar-total`. Bugs/decisiones nuevas → ticket propio (`--solo-crear`) antes de cerrar.

## Que NO hay que tocar
- marketing/
- clinicas / datos de salud
- No ampliar a otros tickets de la cola medium salvo bugs/decisiones nuevas medidos aquí
- No inventar frecuencia de uso (el ticket dice que no se midió)

## Como se sabe que esta bien
- AC del ticket cumplidos con prueba que falle antes y pase después
- Board e índice `docs/TICKETS.md` al día
- PR mergeado a 2.1 y `/cerrar-total` (worktree)

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board, actualizar `docs/TICKETS.md`, merge y `/cerrar-total` sin preguntar si corre el gate o el commit. Solo parar ante decisión/acceso real de Jürgen.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL y key en fichero local, no en git; no las escribas en el repo) cuando:
  (1) necesitas una decisión de producto o de acceso de Jürgen;
  (2) abriste el PR o dejaste preview/artifact listo;
  (3) terminaste el ticket y vas a /cerrar-total — incluye en el aviso un resumen corto de cierre en lenguaje de usuario (qué se hizo), no solo «cerré»;
  (4) acabaste un tramo y no tienes siguiente paso claro (aunque no haya pregunta formal) — una vez, no en bucle.
NO avises por: un test rojo que vas a reclasificar, un build que vas a reintentar, ni ruido de CI advisory. URL/key solo en la Mini.
