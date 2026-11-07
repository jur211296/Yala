---
id: ipad-narrow-bar-announces-more-as-search
status: backlog
priority: low
area: "navigation, ipad, accessibility"
created: 2026-11-06
updated: 2026-11-06
source: "lote UI 2.3 (card o9ih: «Al estrechar la ventana del iPad con Registros elegido, la barra de abajo sale sin Más»)"
---

# Al estrechar la ventana del iPad con Registros elegido, el botón «Más» se anuncia como «Buscar»

## Qué ve el usuario

En pantalla la barra de abajo está bien: Panel, Estadísticas, Planificación, Registros y Más. Pero el quinto botón,
el que se ve como «Más», el sistema lo anuncia como **«Buscar»**: con VoiceOver se oiría «Buscar» sobre «Más».

## Medido (2026-11-06, iPad Pro 13 simulado, iOS 27.2, «Apps en ventanas»)

`AdaptiveNavigationUITests.test_narrowingTheWindow_keepsEveryPageOpen_andWideningBringsTheSidebarBack` cae en la
iteración de Registros con «La barra estrecha perdió «Más»». Los botones de la barra, según la accesibilidad:
`["Panel", "Estadísticas", "Planificación", "Registros", "Buscar"]`; el fotograma del vídeo en ese instante enseña
«Más» en ese hueco. Panel, Estadísticas y Planificación pasan.

Inferido, sin medir la causa: con Registros elegida la barra estrecha lleva cuatro páginas, así que
`RootTabLayoutLogic.showsSearchTab` quita Buscar y `showsMoreTab` pone Más en el MISMO paso (al pasar de la barra
lateral, que no tiene Más, a la de abajo). UIKit reutiliza el botón del hueco y le cambia título e icono, pero no la
etiqueta de accesibilidad. Con Panel elegido Buscar sigue (tres páginas) y no hay relevo.

## Por qué no se arregló en el lote

Decisión de Jürgen (2026-11-06, opción A): el arreglo toca la lógica de la barra que ya cerró la app al redimensionar
(pestañas ocultas y seleccionadas, ítems sin controlador) y puede sacar un instante el «Más» nativo de iOS. Va en una
sesión propia de la barra, con QA en iPad.

## Criterio de hecho

- [ ] Al estrechar con Registros (y con Reportes y Grupos, que el caso no llega a recorrer) el quinto botón se anuncia
      «Más», y el caso de arriba pasa en el iPad Pro 13.
- [ ] Sin crash al estrechar ni al ensanchar con cualquiera de las seis páginas, ni con Buscar elegido.

Evidencia: `~/Claude/entregas/2026-11-06-lote-bugs-ui-idioma-ipad-grupos/evidencia/ipad-registros-estrecho.png`.
Simulador para reproducir: `YalaLane-Adapt-iPad-Pro-13` (ya con «Apps en ventanas»).
