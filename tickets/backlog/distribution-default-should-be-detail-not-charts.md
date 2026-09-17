---
id: distribution-default-should-be-detail-not-charts
status: backlog
priority: medium
area: "statistics, distribution, ux"
created: 2026-09-17
source: "UX Jürgen 2026-09-17 (bugs de experiencia sin ticket)"
---

# En Distribución el default (izquierda) debe ser Detalle; Gráficas pasa a secundario

## Qué quiere el usuario

En Estadísticas → Distribución, el selector Gráficas / Detalle arranca hoy con Gráficas. Jürgen quiere que el **default (lado izquierdo / arranque) sea Detalle**, y que Gráficas quede como modo secundario.

## Por qué

Detalle es la lectura útil al llegar; las gráficas son exploración, no la primera parada.

## Pista de código

Pill en `CategoriesTabView` / `DistributionContentMode` (`modeCharts` / `modeDetail`, ~L91 y ~L1727). Cambiar el default del `@State` / preferencia persistida sin romper quien ya eligió Gráficas a propósito (decidir: ¿resetear a Detalle siempre, o solo first launch?).
