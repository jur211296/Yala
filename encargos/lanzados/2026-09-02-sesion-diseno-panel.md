# Sesión de diseño del panel: medir vs referencia y renderizar propuestas

## Contexto
Jürgen va a mandar pantallazos de una app cuyo panel le gusta: más limpio y ordenado. Claude compara con el nuestro (tamaños, distancias, fuentes y tamaños de fuente, lugar de los botones, jerarquía) y renderiza propuestas. No clonar el ejemplo ni copiar marca ajena: llevar el nuestro hacia esa limpieza.

parte Yala ahora: rama `2.1`, sincronizada con origin, 7 ficheros sin commitear (no de este encargo). PRs abiertos: ninguno. Sesiones en worktree: ninguna. ESTADO (2026-09-01): release 2.1, 9 tickets in-progress parados (sesión secundaria / invitados) y 15 en qa/; nada de eso es este trabajo.

Dónde vive el panel:
- `Yala/App/Views/Panel/PanelView.swift`
- `Yala/App/Views/Panel/PanelShell.swift`
- `Yala/App/Views/Panel/PanelSectionsConfigView.swift`
- `Yala/App/Views/Panel/PanelSectionPreferencesSheet.swift`
- `Yala/App/ViewModels/PanelViewModel.swift`
- `Yala/App/Views/Shared/PanelBackgroundView.swift`
- tema/modificadores: `Yala/App/Theme/ViewModifiers.swift`
- DS: `.claude/rules/swiftui-ds.md` (se carga al tocar SwiftUI)

Esta sesión es de diseño. Jürgen entra con las imágenes y prueba ahí. El éxito de ESTE encargo no es cerrar el rediseño: es sesión abierta, contexto cargado, lista para pantallas y propuestas.

Worktree (`lanzar-sesion`): rama + PR. No mezclar los 7 ficheros sucios del árbol principal.

## Qué se pide
1. Al arrancar, localizar el panel nuestro (archivos de arriba) y las reglas de UI. Primer mensaje: deja claro qué pantalla es el panel y que esperas los pantallazos de Jürgen para medir y proponer.
2. Cuando lleguen las imágenes: analizar vs lo nuestro (tamaños, distancias, fuentes, tamaños de fuente, lugar de botones, jerarquía). Luego renderizar propuestas. No clonar; acercar el nuestro a esa limpieza.
3. No hace falta implementar el rediseño entero en esta sesión salvo que Jürgen lo pida ahí.

## Qué NO hay que tocar
- `marketing/` (Lola).
- Replicar pixel a pixel o copiar marca ajena.
- Rewrites masivos de lógica; es UI del panel.
- Inventar las pantallas de referencia.
- Los 7 ficheros sin commitear del árbol principal.
- Tickets de sesión secundaria / invitados / qa drenaje.
- Datos de clinicas-dentales-bi.

## Como se sabe que está bien
Ventana Yala abierta, agente frank. El primer mensaje de Claude ya sabe qué panel es el nuestro y que espera screenshots para medir y proponer.
