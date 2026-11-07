---
id: budget-exceeded-encouragement-reads-as-a-sermon
status: backlog
priority: low
area: "presupuestos, copy"
created: 2026-11-07
updated: 2026-11-07
source: "exploración 2.3 de la mascota Yalitto (docs/ux/mascota-yalitto-2.3/), hallazgo al revisar el tono de los estados"
---

# «Pasaste tu presupuesto, ¡el próximo período será mejor!» consuela en vez de ofrecer algo

## Qué pasa

Un presupuesto pasado del 100 % enseña `budgets.exceeded.encouragement` («Pasaste tu presupuesto, ¡el próximo período
será mejor!») en la lista y en el detalle (`BudgetRowView.swift:96`, `BudgetDetailView.swift:396`). Se ve en la captura
`docs/ux/mascota-yalitto-2.3/capturas/05-presupuestos-mes-pasado.jpg`.

La frase no da ningún dato ni ninguna salida, y presupone que el período fue «malo». La voz de marca la permite, pero la
exploración de Yalitto fija «describir y ofrecer, sin moralizar el gasto», y con un personaje al lado se lee como sermón.

## Propuesta

Describir y ofrecer: «Te pasaste por S/ 993. ¿Ajustamos el límite?», con la acción a mano. Decide Jürgen, idealmente junto
con la decisión de si Yalitto se hace. Son 16 idiomas.
