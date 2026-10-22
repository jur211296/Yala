---
id: invite-and-app-notices-present-over-other-tab-sheets
status: done
priority: medium
area: routing
created: 2026-10-11
updated: 2026-10-11
source: encargo 2026-10-11-hoja-se-cierra-al-entrar-desde-fuera
---

# Invitaciones y avisos de la app se presentan encima de la hoja de otra pestaña

## Qué pasa (inferido del código, sin medir)

El 2026-10-11 se midió que el Panel tumbaba la hoja abierta en otra pestaña al presentar encima (una foto compartida
cerraba un «Nuevo registro» a medias en Estadísticas) y se arregló en el Panel (`panelCanDrain(windowPresentationVisible:)`).
Los otros dos consumidores del router tienen el mismo patrón y no se tocaron:

- `.contentView` (`ContentViewReadinessLogic`): las pantallas de unirse a un grupo desde un enlace de invitación, la
  oferta de prueba, Novedades, avisos de sistema. Su matriz no mira hojas de las pestañas.
- `.mainTab` (`RouterConsumerGateLogic.mainTabDecision`): prueba expirada, downgrade, hitos. Mira solo sus propias hojas.

Si alguno presenta con un formulario a medias abierto en una pestaña, cabe esperar lo mismo: la hoja de la pestaña se
cierra y lo escrito se pierde.

## Qué falta decidir

`.contentView` mezcla avisos críticos (`remoteWipe`, `iCloudMismatch`, Apple ID cambiado) que no deberían esperar a que
la persona cierre un formulario. Medir primero con un XCUITest (molde: `ExternalEntryForeignSheetUITests`) y decidir qué
espera y qué no.

## Resuelto (2026-10-11)

**Medido el rojo** (simulador iPhone 17 Pro, iOS 27.0, build sin el arreglo): con «Nuevo registro» a medias en
Estadísticas, un enlace de invitación (`yaladev://invite?s=…`, respuesta «Enlace no válido»), la oferta de prueba
(`.contentView`) y la prueba expirada (`.mainTab`) cerraban el formulario y se perdía el 1234 escrito. El aviso crítico
(cuenta de iCloud cambiada) salía al momento.

**Arreglo**: `ContentView` y `MainTabView` preguntan a UIKit por la ventana (`ModalPresentationProbe.isAnythingPresented(in:)`,
el candado del Panel) y los avisos diferibles esperan a que se cierre la hoja; los críticos salen como hoy. Clasificación
en `RouterConsumerGateLogic.waitsForForeignPresentation` (tabla en `docs/entry-points.md`). Un diferible retenido no tapa
a un crítico (`AppRouter.drainNext(for:in:skipping:)`); reintento de 300 ms porque cerrar la hoja no avisa a nadie. La
respuesta a una invitación que no vale, el archivado y el hito se aparcan al ir a segundo plano (15 min).

**Verde**: `ExternalEntryForeignSheetUITests` (invitación, oferta, prueba expirada y el crítico) + `ForeignSheetNoticesTests`.
