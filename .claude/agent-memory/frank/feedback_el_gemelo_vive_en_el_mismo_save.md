---
name: feedback_el_gemelo_vive_en_el_mismo_save
description: Al cerrar un «default optimista», el criterio de alcance es qué corre DENTRO del mismo save/transacción, no la lista de sitios del ticket.
metadata:
  type: feedback
---

El ticket nombraba tres sitios; dentro del MISMO `applyPage` había dos gemelos más (búsqueda de fila y
`SyncUnitClockStore.row`) que la lista no traía. Entraron porque comparten la atomicidad que ya arregla el caso
(un `throw` cae en el rollback existente). Lo que vive FUERA de ese save —el pase de danglers, el drain— fue a
ticket: su camino de error es otro (el `catch` de `drainOnce` no hace rollback) y un `throw` nuevo ahí rompe más
de lo que arregla.

**Why:** 2026-09-22, `apply-overwrites-…`. La lente de gemelas cazó el reloj por unidad; sin ese criterio lo
habría mandado a ticket junto con el drain, o habría arrastrado el drain al PR.

**How to apply:** antes de ampliar o recortar, pregunta «¿este sitio corre dentro de la transacción cuyo fallo
ya sé manejar?». Sí → entra. No → mira su `catch` antes de añadirle un `throw`. Relacionado:
[[feedback_la_tabla_del_ticket_nombra_un_sitio_por_pantalla]], [[feedback_la_premisa_del_encargo_tambien_se_mide]].
