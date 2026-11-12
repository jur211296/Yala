# Presupuestos en riesgo (Observaciones)

Cierre: **cierra-sola** → al terminar, `/cerrar-total`.
Versión **2.2**. Base `origin/2.2`. Esfuerzo: medium.
Slug: `presupuestos-en-riesgo` · Sesión cola **S26** · al cerrar → **S27**.

## Encargo
Cumple **íntegramente** el brief per-card:

`~/Claude/tmp-frank/presupuestos-en-riesgo-observaciones-d98t.md`

Léelo y ejecútalo tal cual (contexto, qué se pide, qué NO tocar, cómo se sabe que está bien). Este wrapper solo fija el hueco en la cola automática S0–S29.

## Qué NO tocar
Lo que diga el brief per-card. Además: no lanzar otras sesiones Yala; no tocar marketing/ ni Web/.

## Cómo se sabe que está bien
El criterio del brief per-card + PR a 2.2 cuando aplique.

## Pie pipeline
- Base: `origin/2.2`. Una sesión Yala a la vez. Rebase único antes del PR.
- Pipeline serial Yala: (1) limpiar sims muertos, DerivedData y cachés XcodeBuildMCP de worktrees cerrados; (2) build `xcodebuild -jobs 2` sin sim booteado; (3) bootear 1 sim; (4) tests; (5) apagar y limpiar.
- Al cerrar: Frank publica digest y lanza la siguiente según `~/Claude/tmp-frank/siguiente-activo.txt` y `~/Claude/tmp-frank/cola-2-2-orden-activo.txt`.
- marketing/ y Web/ = Lola. No relances otras sesiones Yala.


## Paso 0 — decisiones (resueltas en autónomo, bypass)

1. **Periodo de cada presupuesto en Observaciones:** el EN CURSO (`currentBudgetInterval`), como hasta ahora; no el período elegido en Estadísticas. Es lo que muestra Planificación por defecto.
2. **Presupuestos con categoría legada:** se cuentan como Planificación, que ignora `budget.category`. La paridad manda; ningún flujo actual crea ya presupuestos con categoría.
3. **Color de la fila:** el de la categoría legada si la hay; si no, el de `displayProperties` (antes no había fila).
4. **Ajuste de grupo y divisa:** el mismo `adjustment` que ya recibe Observaciones y su `converter`; `calculateSpending` aplica «Contar mi parte…» por presupuesto.
5. **Premisa medida:** Observaciones YA sumaba sobre los movimientos sin filtro (`allTransactions: transactions`). Se mantiene y se fija con un test.
6. **Fórmula de `calculateSpending`:** no se toca.
