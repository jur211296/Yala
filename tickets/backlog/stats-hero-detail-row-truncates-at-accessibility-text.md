---
id: stats-hero-detail-row-truncates-at-accessibility-text
status: backlog
priority: low
area: "estadisticas, a11y"
created: 2026-10-10
updated: 2026-10-10
source: "capturas del encargo `2026-10-10-spacing-chips-to-title-matches-panel` (tablero `hay-un-vacio-sobrante-entre-los-chips-y`)"
---

# Con texto grande, la fila de entradas y salidas del hero de Estadísticas sale cortada

## El problema, en lenguaje de usuario

Con el tamaño de texto de accesibilidad (AX3) en un iPhone 17 Pro, debajo de la cifra de Estadísticas › Resumen la
fila de entradas y salidas no cabe: la cifra de salidas se queda en «……» y el chip de variación («= +0 %») sale
partido contra el borde y medio tapado por los botones flotantes. La persona que más necesita el texto grande es la
que no puede leer cuánto gastó.

## Lo medido (2026-10-10)

Visto en el simulador, seed `grupos`, tema claro, `UICTContentSizeCategoryAccessibilityXXXL`: captura
`~/Claude/worktrees/_capturas/2026-10-10-spacing-chips-to-title-matches-panel/antes/stats-resumen-claro-ax.png` (y la
misma en `despues/`: el encargo de espaciado no lo cambió). No mirado aún en Tendencias, Distribución ni Registros, ni
en el Panel, que comparte `HeroHeader`.

## Por dónde va

Decisión de diseño antes que código: apilar entradas y salidas en dos filas a tamaños de accesibilidad, o soltar el
chip de variación a la línea siguiente. Molde existente: `AdaptiveRowStack` (`swiftui-ds.md`).
