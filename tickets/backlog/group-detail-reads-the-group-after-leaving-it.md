---
id: group-detail-reads-the-group-after-leaving-it
status: backlog
priority: medium
area: "groups"
created: 2026-10-31
updated: 2026-10-31
source: "encargo S34b formularios-modelo-borrado-b (card gxa9, barrido del patrón en quien presenta los formularios)"
---

# El detalle del grupo puede leer el grupo después de salir de él

## Qué pasa

Mismo riesgo que `more-forms-read-their-deleted-model-while-closing` (hecho el 2026-10-31): en iOS 27.x leer una
propiedad de un modelo SwiftData borrado aborta la app. «Salir del grupo» y «Transferir y salir» (Ajustes del grupo)
borran el grupo del todo (`GroupService.leaveGroup` → `performLocalCleanupAndDelete`) y suben `dataVersion`. Ajustes ya
no lee el grupo borrado (card gxa9), pero el detalle que hay debajo, `GroupDetailView`, sí lo lee en su `body`:
`.navigationTitle(group.name)`, `group.migrationState` en los avisos, la barra y los chips.

Su `onChange(of: sessionState.dataVersion)` cierra la pantalla en cuanto ve el grupo borrado
(`GroupDetailDismissDecision`), pero el `body` se vuelve a evaluar antes de que corra ese `onChange`. Lo mismo vale para
un grupo que se borra por sync con el detalle abierto.

No está medido que el `body` se repinte en esa ventana (el simulador 27.0 no aborta al leer un modelo borrado): es un
riesgo, no un crash visto.

## Por qué no entró en gxa9

No es una copia de una línea: el `body` lee el grupo en la barra, el título, los chips y los avisos, y guardarlo cambia
la forma de la pantalla mientras se cierra. Pide decidir qué se ve en esos fotogramas.

## Qué haría falta

Que el `body` de `GroupDetailView` mire `group.isDeleted || group.modelContext == nil` antes de leer el grupo, sin
perder los modificadores que la cierran (`onChange(of: dataVersion)`), con su scan en `DeletedModelMoreFormsGuardWiringTests`.
