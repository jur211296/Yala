---
name: panel-conjunto-de-cuentas
description: PR #87 cierra en código que el Panel respeta el conjunto de cuentas; falta device-QA y quedan tres preexistentes con ticket. El ticket decía «cuatro sitios» y eran más.
metadata:
  type: project
---

**El saldo del Panel respeta el conjunto de cuentas filtradas** — cerrado en código el 2026-09-07,
PR **#87**, ticket `panel-colapsa-la-seleccion-de-cuentas-a-la-primera` → `qa/`.

**Why:** era la última vía conocida por la que el saldo del Panel y el KPI de Distribución podían
seguir sin cuadrar tras `distribution-balance-kpi-skips-fx` (#78). Decisión de Jürgen del 2026-09-06,
que revoca su «no tocar Panel» del 26-ago.

**How to apply:**

- **Lo que espera es device-QA**, no código: dos cuentas desde Registros → Filtros, comparar Panel vs
  Distribución, repetir con «excluir» y con el toggle de grupos. El escenario paso a paso está en el
  ticket. Sin números de aparato no hay PASS.
- **No reabras el modelo «Panel = una cuenta».** Y si tocas la elegibilidad en un VM, toca el otro:
  `PanelViewModel` y `StatisticsViewModel` tienen que resolverla igual, y `BalanceKPIParityTests` lo
  fija.
- La regla durable quedó en `.claude/rules/session-filters.md`, que se carga sola al tocar
  `SessionState`, los cuatro VMs o los calculadores.

**Tres preexistentes salieron de camino y NO se tocaron** (ticket cada uno, todos en `backlog`):
`panel-lee-el-filtro-de-cuentas-en-singular-fuera-del-saldo` (el subtítulo «en N cuentas» cuenta
todas mientras el saldo filtra; y el prefill del formulario propone una cuenta arbitraria, en modo
excluir la excluida) · `saldo-con-seleccion-no-contable-diverge-entre-panel-y-estadisticas` (con una
cuenta excluida de estadísticas: saldo grande = total, widgets = 0, KPI = 0; incluye el ID fantasma
que deja `EntityDeletionService` al borrar una cuenta) ·
`filtro-de-cuentas-se-colapsa-al-navegar-a-registros`.

**El ticket decía «cuatro sitios» y eran más**, y ninguna de sus rutas existía (citaba los ficheros
sin su carpeta). Refuerza [[la-premisa-del-encargo-tambien-se-mide]]: el grep del símbolo devolvió
tres vistas del Panel que el análisis no nombraba, y un defecto vivo —`LiveBalanceCalculator` no
conocía `isExcludeMode`— que hacía falso el AC de paridad.

Relacionado: [[mi-fix-hereda-la-forma-del-bug]] (el defecto que introduje aquí y cazaron las lentes)
· [[bisect-de-un-flaky-miente]] (el rojo de `EdgeCasesUITests` de este gate).
