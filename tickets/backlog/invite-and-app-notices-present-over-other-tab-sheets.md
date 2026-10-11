---
id: invite-and-app-notices-present-over-other-tab-sheets
status: backlog
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
