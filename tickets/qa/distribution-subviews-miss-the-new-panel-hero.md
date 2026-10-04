---
id: distribution-subviews-miss-the-new-panel-hero
status: qa
priority: medium
area: "panel, statistics"
created: 2026-09-09
updated: 2026-10-04
qa-status: needs-testing
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

**Hecho, pendiente de pasada en el iPhone** (2026-10-04). Ver «Decisión», «Qué cambió» y «Guion de QA» abajo.

## Relacionados

- [[pie-header-total-unmarked]] — la cabecera de «Análisis del gasto», en esta misma zona, tiene un
  defecto vivo. Si se rehace el hero, se arregla o se arrastra.
- [[hero-estadisticas-stock-vs-flujo-entre-pestanas]] — el hero de Estadísticas cambia de
  significado entre pestañas. Con cuatro implementaciones paralelas se entiende por qué; conviene
  resolverlo en el mismo diseño y no después.

## Ampliación Jürgen (2026-09-17)

No solo Distribución: **alinear el Hero de Estadísticas (todas sus subvistas) con el nuevo hero del Panel, incluidos los FABs**. Si hay más vistas con hero en la app, también.

Esto ensancha el alcance del ticket: Panel hero + FABs como referencia única; Estadísticas completa; auditar otras pantallas con hero paralelo.


## Decisión Jürgen (2026-10-03 ~22:29 Lima)

El hero del Panel **se queda visible** en categoría, subcategoría, etiquetas y Gráficas/Detalle; los FABs los
decide la sesión. Responde a «La pregunta que falta» de arriba: es **unificar** las cabeceras con la del Panel.

## Qué cambió (2026-10-04)

- **Una maqueta para todos los heros: `HeroHeader`** (`Yala/App/Views/Shared/HeroHeader.swift`). Rótulo de la cifra
  arriba a la izquierda, píldora de período a su derecha, cifra (`panelHeroAmount`) y detalle debajo, todo en el
  eje izquierdo de la pantalla. La usan el Panel (`HeroMonthView`, sin cambio visual), las cuatro pestañas de
  Estadísticas, la página Registros (por `RecordsTabView`) y Pagos planificados.
- **Ningún número cambia.** Cada pestaña sigue con su cifra y su rótulo (decisión del 06-sep,
  [[hero-estadisticas-stock-vs-flujo-entre-pestanas]]); el rótulo solo sube al hueco de «Disponible».
- **Distribución:** un solo hero para el carrusel y para Gráficas/Detalle, encima de todo; ninguna subvista lo
  sustituye.
- **FABs:** Yala IA y «+» pasan de solo Registros a **las cuatro pestañas** de Estadísticas, con el margen inferior
  de dos botones (`fabStackClearance`). Motivo: en el Panel «Nuevo registro» está siempre a mano.
- **iPhone girado:** Resumen y Registros conservan la banda (`SummaryHeaderStack`); solo cambia la vista vertical.
- **Tests:** `StatisticsHeroLikePanelUITests` (nuevo: rótulo a la izquierda y los dos FABs en cada pestaña y en cada
  subvista de Distribución) y `SmartRefinementFabUITests` (el caso que afirmaba el FAB ausente en Resumen pasa a
  afirmarlo presente).

## Guion de QA (iPhone)

Montaje: build de TestFlight o `Yala Dev` desde Xcode en tu iPhone, con datos de varios meses.

1. Abre **Panel** y fíjate en el hero: «Disponible» arriba a la izquierda, la píldora del período a la derecha, la
   cifra grande debajo.
2. Toca **Estadísticas**. En **Resumen**, la cabecera debe leerse igual: «Neto del período» arriba a la izquierda,
   la píldora a la derecha, la cifra debajo, todo alineado con «Tu salud financiera».
3. Repite en **Tendencias** y en **Registros** (desliza los chips para verlo).
4. En **Distribución**: el rótulo dice «Saldo de cuentas». Desliza el carrusel de pies a **Subcategorías** y a
   **Etiquetas**: la cabecera no se mueve ni cambia. Toca **Detalle** y vuelve a **Gráficas**: igual.
5. En las cuatro pestañas, abajo a la derecha están **Yala IA** y **«+»**. Toca «+»: se abre Nuevo registro.
   Ciérralo sin guardar.
6. Baja hasta el final de cada pestaña: la última tarjeta queda por encima de los dos botones, no debajo.
7. Gira el iPhone en **Resumen**: la cabecera pasa a la banda compacta de siempre (cifra a la izquierda, período y
   entradas/salidas a la derecha). Vuelve a vertical.
8. **Planificación → Pagos planificados**: «Total del mes · Este mes» arriba a la izquierda y la cifra debajo.

Falla si en algún punto la cabecera sale centrada, si falta el rótulo o si en alguna pestaña no están los dos botones.
