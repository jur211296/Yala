---
id: group-detail-reads-the-group-after-leaving-it
status: qa
priority: medium
area: "groups"
created: 2026-10-31
updated: 2026-11-01
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

## Hecho (2026-11-01, encargo S35g)

- **El detalle mira antes de leer.** `GroupDetailView.isGroupReadable` (molde de Ajustes del grupo): con el grupo borrado
  no pinta los avisos, las pestañas ni el botón de nuevo gasto, quita Miembros y Ajustes de la barra, y el título sale
  del nombre de la última carga (`viewModel.groupName`). De las hojas, solo Ajustes se sigue construyendo (es desde
  donde se sale y no lee el grupo borrado); las demás no pintan nada si un borrado por sync las pilla abiertas.
- **La decisión de cierre ya no leía solo lo seguro.** `GroupDetailDismissDecision.shouldDismiss` recibía
  `isHiddenForAll` e `isArchived` ya leídos del grupo: con él borrado, el propio `onChange` que lo cierra los leía.
  Ahora van diferidos (`@autoclosure`) y solo se evalúan con el grupo vivo.
- **El ViewModel lo suelta.** `releaseDeletedGroup()` (al decidir cerrar y al cerrarse la hoja de Ajustes) cancela la
  recarga con freno pendiente y vacía miembros, gastos y repartos, borrados con él; recargar, calcular, enseñar el aviso
  de un saldo inicial rechazado o crear el enlace de invitación miran antes si el grupo sigue.
- **Quien lo abre** (`GroupsContainerView`, `navigationDestination(item:)`) solo lee `persistentModelID`: no hacía falta
  tocarlo, y lo fija el scan.
- Pin: `DeletedModelMoreFormsGuardWiringTests.detalleDeGrupo_conElGrupoBorradoNoLeeElGrupo_niLoQueLoAbre`,
  `DeletedModelMoreFormsReleaseTests.grupo_trasSalir_elDetalleLoSuelta_yNoVuelveALeerlo`,
  `GroupDetailDismissDecisionTests.goneGroup_dismissesWithoutReadingTheRest`. Los tres caen con su mutante.

**Qué se ve en esos fotogramas** (lo que el ticket dejaba por decidir): lo mismo que Ajustes del grupo desde gxa9, el
fondo con el título mientras la pantalla se va. Solo dura la animación de salida.

## Guion de device-QA (Yala Dev, tu iPhone con iOS 27.x)

El simulador no aborta al leer un grupo borrado y salir de verdad pide servidor, así que esto solo se prueba en el
iPhone. Necesitas un grupo del que puedas salir (no eres el dueño) y que no te importe dejar.

1. Abre Yala Dev → pestaña **Grupos** → toca ese grupo.
2. Toca el engranaje (arriba a la derecha) → baja hasta **Salir del grupo** → confírmalo.
3. Esperado: la hoja de Ajustes baja, el detalle vuelve a la lista y el grupo ya no está. **La app no se cierra.**
4. Si eres dueño de otro grupo con más miembros: repite con **Transferir y salir**. Mismo resultado esperado.
