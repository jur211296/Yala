---
id: group-split-lines-recipe-lost-when-the-new-leg-is-not-born-in-the-pass
status: backlog
priority: low
area: "grupos, puente"
created: 2026-11-02
updated: 2026-11-02
source: "encargo 2026-11-02-grupos-b-cabos-sueltos (card sbvw), residual escrito en su Paso 0 · D3"
---

# Las líneas de tu parte se pierden cuando la pata nueva no nace en la misma pasada

Desde la card sbvw la receta de tu parte se trasplanta a la pata nueva cuando el gasto cambia de pagador
(`GroupSplitLinesTransplantLogic`). Quedan dos caminos en que la pata nueva no nace en esa pasada y la receta se va con la
vieja:

- **El pagador pasa a ti desde otro aparato.** Aquí no hay cuenta elegida: el puente deja el borrador de la Bandeja que la
  pide y borra la pata de «Grupos» que llevaba la receta. Al aprobarlo, tu parte vuelve en una línea.
- **El gasto que pagaste tú cambia de divisa.** La pata real se borra y queda el borrador «la moneda cambió».

En los dos el borrador ya está en la Bandeja y ofrece «Partir» (card 5), así que la persona puede volver a partir; lo que se
pierde son las líneas de antes. Guardarlas en el borrador pide un campo nuevo en `InboxDraft` (CloudKit y Modo Nube), o
conservar la pata vieja hasta la aprobación, que cambia cifras mientras tanto. Fijado como residual en
`GroupBridgeSplitLinesTransplantTests.caseBToCaseA_fromAnotherDevice_leavesTheAccountDraft_andNoLooseLines`.

## Lo que añadió la review del 2-nov

- **Dos aparatos, orden de llegada.** El aparato que trasplanta conserva las líneas derivadas y la entrada de la recarga
  (misma identidad); el otro aparato, si recibe el cambio de pagador antes que la pata nueva, no trasplanta y las borra, y
  ese borrado viaja. El primero se queda con la receta y el préstamo engordado pero sin las derivadas hasta su siguiente
  pasada de ese gasto. Inferido (depende del orden entre el canal de Grupos y el personal); sin medir en dos teléfonos.
- **El lote y el menú bloquean la categoría de la pata con receta también con el puente apagado o en solo-grupos**, donde
  la receta no se aplica y el editor sí deja cambiarla (`RecordContextActionLogic.Shape(record:)` no puede preguntar por el
  puente sin un fetch). El motivo del lote manda a «Partir», que ahí no se ofrece.
