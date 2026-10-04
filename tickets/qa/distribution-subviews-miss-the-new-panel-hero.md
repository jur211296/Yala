---
id: distribution-subviews-miss-the-new-panel-hero
status: backlog
priority: medium
area: "panel, statistics"
created: 2026-09-09
updated: 2026-09-17
source: idea Jürgen 2026-09-09
---

# El rediseño del hero del Panel no llegó a las subvistas de Distribución

## La idea

Llevar el hero rediseñado del Panel a **todas** las subvistas de Distribución (Estadísticas →
Distribución), para que la cabecera se lea igual en todas y no queden dos diseños conviviendo en la
misma app.

## Por qué importa

Distribución es adonde va el usuario a entender un número que vio en el Panel. Si al llegar la
cabecera es otra, tiene que volver a orientarse justo en el momento en que estaba comparando.

## Lo medido (2026-09-09)

No es que a Distribución le falte un hero: es que **hay cinco heros distintos y ninguno se comparte**.

- El del Panel es `HeroMonthView` (`Yala/App/Views/Panel/HeroMonthView.swift:18`) y se usa en **un
  solo sitio de producción**: `Yala/App/Views/Panel/Sections/PanelHeroSection.swift:24`. Ninguna
  vista de Estadísticas lo instancia (verificado con control positivo).
- Estadísticas tiene **cuatro** implementaciones paralelas, una por pestaña:
  `CategoriesTabView.swift:332` (es la que el usuario ve como «Distribución»),
  `InsightsTabView.swift:190`, `TrendsTabView.swift:208` y `RecordsTabView.swift:138`.
- El propio código lo dice: `// MARK: - Hero Summary (edge-to-edge, paralelo a
  InsightsTabView/TrendsTabView)` — `CategoriesTabView.swift:329`.
- Las subvistas de Distribución, para acotar el «todas»: el carrusel de pies con las páginas
  `category` / `subcategory` / `tags` (`CategoriesTabView.swift:504,508,514`) y el toggle de modo
  **Gráficas / Detalle** (`enum DistributionContentMode`, `CategoriesTabView.swift:1729-1739`).
  El `heroSummary` de la pestaña es **uno solo** para todas ellas.

## La pregunta que falta (para Jürgen, antes del spec)

Como Distribución tiene un hero propio y uno solo, «llevarlo a todas las subvistas» puede querer
decir dos cosas: **unificar** las cuatro cabeceras de Estadísticas con la del Panel, o que el hero
**siga visible** en subvistas donde hoy se pierde. No se resuelve leyendo el código: hay que verlo
juntos en pantalla.

## Estado

Idea capturada, **sin spec**.

## Relacionados

- [[pie-header-total-unmarked]] — la cabecera de «Análisis del gasto», en esta misma zona, tiene un
  defecto vivo. Si se rehace el hero, se arregla o se arrastra.
- [[hero-estadisticas-stock-vs-flujo-entre-pestanas]] — el hero de Estadísticas cambia de
  significado entre pestañas. Con cuatro implementaciones paralelas se entiende por qué; conviene
  resolverlo en el mismo diseño y no después.

## Ampliación Jürgen (2026-09-17)

No solo Distribución: **alinear el Hero de Estadísticas (todas sus subvistas) con el nuevo hero del Panel, incluidos los FABs**. Si hay más vistas con hero en la app, también.

Esto ensancha el alcance del ticket: Panel hero + FABs como referencia única; Estadísticas completa; auditar otras pantallas con hero paralelo.

