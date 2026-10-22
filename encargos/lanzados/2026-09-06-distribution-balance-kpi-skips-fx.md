# KPI Balance en Distribución = mismo stock vivo que el Panel (no flujo)

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board, merge a 2.1 y /cerrar-total sin preguntar. Solo parar ante decisión/acceso real de Jürgen.

## Contexto
Ticket: `tickets/backlog/distribution-balance-kpi-skips-fx.md` (high). Owner vio KPI distintos Panel vs Distribución (multi-moneda). Investigación: Distribución **sí** convierte FX, pero usa flujo histórico; Panel Balance usa stock vivo (`LiveBalanceCalculator` + TC actual).

**Decisión Jürgen 2026-08-26 (ya en el ticket — no repreguntar):**
1. No mantener stock vs flujo para Balance. Igualar Balance a **stock**.
2. No tocar Panel. Panel = fuente de verdad.
3. Solo el KPI de Balance en Distribución (hero/header cuando `natures` vacío) = mismo número de stock vivo que Panel.
4. Ingresos/Gastos en Distribución siguen siendo flujo del período.
5. No inventar PASS de device sin números; sí implementar el cableado medido.

Cola nocturna bypass. Panel-perf (#77) ya en 2.1. Rama desde origin/2.1. Secrets en worktree-enlaces.

## Que se pide
1. Re-medir paths Panel vs CategoriesTabView / TopSpendingCategoriesCalculator en HEAD.
2. Cuando métrica Balance (`natures` vacío), hero/header de Distribución usan el mismo stock vivo que Panel (`LiveBalanceCalculator` / TC actual). Panel sin cambios.
3. Ingresos/Gastos en Distribución siguen flujo del período.
4. Tests que fijen igualdad Balance Distribución ↔ Panel (o el harness más cercano).
5. Ticket → qa/board; PR a 2.1; merge gate verde (UI advisory: contrastar base); /cerrar-total.
6. Device-QA multi-moneda queda para Jürgen (anotar en ticket/PR); no inventar PASS.

## Que NO hay que tocar
- marketing/
- Rediseñar pie como stock por cuenta
- trends-comparison-kpi-vs-curve (otro ticket)
- groups-pending-member / kill-switch

## Como se sabe que esta bien
- Con Balance seleccionado, KPI Distribución == KPI Panel (misma base live).
- Ingresos/Gastos intactos como flujo.
- Gate verde; PR mergeado; /cerrar-total con resumen usuario.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL y key en fichero local, no en git) cuando: (1) decisión de producto/acceso; (2) PR o preview listo; (3) terminaste y /cerrar-total — resumen de qué se hizo; (4) idle mid-ticket una vez. NO avises por test rojo a reclasificar, build a reintentar, ni ruido de setup cp/cd. URL/key solo en la Mini.
