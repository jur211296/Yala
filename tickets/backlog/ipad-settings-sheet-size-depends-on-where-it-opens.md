---
id: ipad-settings-sheet-size-depends-on-where-it-opens
status: backlog
priority: low
area: "ipad, settings, adaptativo"
updated: 2026-10-08
created: 2026-09-29
source: "fase 2 del carril adaptativo (ipad-list-detail-for-groups-and-settings-and-chat-inspector), 2026-09-29"
---

# En iPad, Ajustes solo sale a pantalla completa con dos columnas si lo abres desde Grupos

## Qué pasa

Desde la fase 2, Ajustes es una lista y el ajuste abierto a la vez, dentro de su hoja (`ProfileView`, un
`ListDetailSplit` con `.presentationSizing(.page)`). Medido el 2026-09-29 en `YalaLane-Adapt-iPad-Pro-13`:

- **Desde Grupos** (el avatar está dentro de un `NavigationSplitView`): la hoja ocupa la pantalla entera y lista y
  ajuste van lado a lado, como la app Ajustes del sistema.
- **Desde el Panel** (y previsiblemente Registros, Estadísticas, Reportes y Más, que presentan fuera de un split): la
  hoja mide 810 pt, en vertical y en horizontal. Ahí el split no pone las dos columnas lado a lado: la lista flota
  sobre el detalle, se aparta al abrir un ajuste y vuelve con el botón de la barra (lo mismo que el iPad mini en
  vertical). Antes de la fase 2 era una hoja de 575 pt con una sola pila.

Un `PresentationSizing` propio que pide `.infinity` sale igual a 810: el sistema lo limita. Inferido, no medido: la
diferencia la pone desde dónde se presenta la hoja.

## Medido otra vez el 2026-10-03 (puede que ya no pase)

Desde el **Panel**, en `YalaLane-Adapt-iPad-Pro-13` (iOS 27.0, árbol `b474ce098`): la hoja sale con lista y ajuste
**lado a lado**, en vertical (a pantalla completa) y en horizontal (1168 pt de ancho, de 104 a 1272). En el iPad mini
girado, también lado a lado; en el mini en vertical la lista flota, como estaba previsto (744 pt no dan para dos).
Capturas en `qa/evidencia-adaptativo-20261003/cola-b-redesigns-must-hold-up-at-ipad-width/` (`*__01-ajustes-*`,
`*__02-personalizacion-*`). Falta medir las otras cinco puertas antes de cerrarlo.

## Qué hacer

1. Medir en qué presentador sale a pantalla completa y por qué (¿el split como presentador?).
2. Si no hay forma limpia con una hoja, decidir con Jürgen si Ajustes en iPad pasa a ser otra cosa (una entrada de la
   barra lateral, una presentación a pantalla completa en ventana ancha). Es una decisión de producto: cambia cómo se
   llega a Ajustes.

## Hecho cuando

Ajustes abre con lista y ajuste lado a lado en el iPad Pro 13 y el iPad mini en horizontal, desde cualquiera de sus
siete puertas, sin cambiar nada en iPhone.

## Medido en 2.1 (triage 2026-10-08)

- Ningún commit posterior al 2026-10-03 cambió la presentación de `ProfileView` (sigue `.presentationSizing(.page)`); los tres que lo tocan son del cierre de sesión con el drain atascado. Lo pendiente sigue siendo medir Registros, Estadísticas, Reportes, Más y el resto de puertas en iPad, y cerrar si salen lado a lado.

Triage 2026-10-08: abierto · low → low · `ProfileView` sigue con `.presentationSizing(.page)` sin cambios de tamaño desde la medida del 2026-10-03, que ya vio lado a lado desde el Panel; faltan medir las otras cinco puertas antes de cerrarlo.
