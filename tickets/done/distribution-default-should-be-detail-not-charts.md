---
id: distribution-default-should-be-detail-not-charts
status: done
priority: medium
area: "statistics, distribution, ux"
created: 2026-09-17
source: "UX Jürgen 2026-09-17 (bugs de experiencia sin ticket)"
updated: 2026-10-25
---

# En Distribución el default (izquierda) debe ser Detalle; Gráficas pasa a secundario

## Qué quiere el usuario

En Estadísticas → Distribución, el selector Gráficas / Detalle arranca hoy con Gráficas. Jürgen quiere que el **default (lado izquierdo / arranque) sea Detalle**, y que Gráficas quede como modo secundario.

## Por qué

Detalle es la lectura útil al llegar; las gráficas son exploración, no la primera parada.

## Pista de código

Pill en `CategoriesTabView` / `DistributionContentMode` (`modeCharts` / `modeDetail`, ~L91 y ~L1727). Cambiar el default del `@State` / preferencia persistida sin romper quien ya eligió Gráficas a propósito (decidir: ¿resetear a Detalle siempre, o solo first launch?).

## Medido en 2.1 (triage 2026-10-08)

- Sigue igual: `@State private var contentMode: DistributionContentMode = .charts` en `CategoriesTabView.swift:92`; el orden del pill sale de `DistributionContentMode` (`:1737`, `.charts` primero).
- La duda de «resetear o solo first launch» no existe: el modo es `@State` sin persistir, así que cada visita arranca en Gráficas. Basta con cambiar el default y el orden de los `case`.
- Ojo: `StatisticsHeroLikePanelUITests.swift:129-136` asume el orden Gráficas, Detalle (`element(boundBy: 1)` = Detalle) y recorre el carrusel antes de tocar el pill; hay que actualizarlo en el mismo commit.

Triage 2026-10-08: abierto · medium → medium · el modo sigue arrancando en Gráficas (`CategoriesTabView.swift:92`), sin commit que lo cambie desde el 17-sep.

## Cerrado (cola 2.2 · lote 12.5, 2026-10-25)

Distribución arranca en Detalle, a la izquierda del selector; Gráficas pasa a la derecha. El enlace de los widgets de subcategorías sigue abriendo la gráfica (cambia a Gráficas antes de mover el carrusel). Medido en el simulador (`capturas/antes-1-distribucion.png` / `despues-1-distribucion.png` del PR). Tests: `DistributionContentModeOrderTests` y `StatisticsHeroLikePanelUITests.test_distributionSubviewsKeepThePanelHero` (arranca en Detalle sin gráficas a la vista).
