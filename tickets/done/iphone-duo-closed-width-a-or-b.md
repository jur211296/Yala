---
id: iphone-duo-closed-width-a-or-b
status: done
priority: low
area: "platform, iphone-duo, adaptativo"
created: 2026-10-24
updated: 2026-10-25
source: "comentarios de Jürgen a las capturas del Duo (C1, C4, C5), 2026-10-24"
---

# iPhone Duo cerrado: ¿la página por debajo de la barra vertical (B) o en el ancho seguro (A)?

**Decidido el 2026-10-25, vista por vista en el Duo cerrado (sesión interactiva con Jürgen).** La A en toda la app,
con dos excepciones elegidas sobre capturas: las pantallas con logo del Welcome y la lista de Ajustes ocupan también la
columna de la barra (`extendsUnderVerticalBar`). El tajo de los carruseles lo quita un fundido contra la barra
(`fadesTowardVerticalBar`), en todos los carruseles horizontales. Regla al día en `.claude/rules/swiftui-ds.md`
(sección iPhone Duo).

## Qué se ve

Jürgen veía el Duo cerrado «cortado»: la barra vertical parecía una pieza aparte y unas piezas (las cuentas, los chips)
pasaban por detrás de ella y otras (los widgets) no.

- **A (aplicada):** nada de lo que se desplaza pasa por detrás de la barra; bajo ella, solo el fondo. Todo alinea con
  todo. Es la regla de Apple (`app-resizability`, HIG del Duo).
- **B (maqueta):** la página usa todo el ancho y la barra flota encima. La barra se integra, pero tapa «Todo el tiempo»,
  el desplegable de «Tus finanzas», el «Te deben» de Grupos e importes de la derecha.

Comparativa antes / A / B por pantalla y resumen: `qa/evidencia-duo-cerrado-20261024/` (`PROPUESTAS.md`).

## Lo que hay que decidir

1. ¿A en toda la app (como queda) o B?
2. Si A: ¿el **Welcome** en B, como excepción? Ahí no hay barra, solo la hora y el wifi en la columna, y en B el
   carrusel y el titular quedan centrados en la pantalla sin tapar nada (captura `01-welcome-b.png`).

## Hecho cuando

- Decidido. Si cambia algo: aplicado con capturas del Duo cerrado y comparación al píxel en el iPhone 17 Pro.
- Para B en una página: `staysOutOfVerticalBar()` (`ToolbarVerticalBar.swift`) es el sitio; la maqueta usó
  `ignoresSafeArea(.container, edges: .horizontal)` en el scroll de la página, y cada control de la columna de la barra
  tendría que apartarse a mano.
