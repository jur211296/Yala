# Segmento Ver solo / Ocultar

Cierre: **cierra-sola** → al terminar, `/cerrar-total`.
Versión **2.2**. Base `origin/2.2`. Esfuerzo: high.
Slug: `segmento-ver-solo-ocultar` · Sesión cola **S6** · al cerrar → **S7**.

## Encargo
Cumple **íntegramente** el brief per-card:

`~/Claude/tmp-frank/segmento-grafica-ver-solo-ocultar-2-2.md`

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


## Paso 0

Medido al abrir (2026-10-26 12:20): la card del brief (5g94) ya está en `done` con PR #634, pero **#634 no ha entrado
en 2.2**: lleva en cola desde las 06:02 con `coverage-index` (obligatorio) en rojo y un conflicto en
`qa/coverage-index.json`. La card de la cola para S6 es `kjzs` (ajuste decidido por Jürgen el 26-oct: solo preguntar
si hay un excluir activo), que se monta encima de #634.

1. **Cómo aterriza #634** → merge de su rama en la mía (conserva sus SHAs: #634 quedará mergeado con este PR). Conflicto
   del índice: las dos entradas se añadían al final de la misma línea; se conservan las dos.
2. **El rojo de `coverage-index`** → falso positivo de `check-test-isolation.sh`: `CombinedEntityFilterTests` solo nombra
   `makeTestContext()` en un comentario. Se reescribe el comentario. (`gateway` rojo en un bench de IA: no es check
   obligatorio ni toca este diff.)
3. **«Hay un excluir activo»** → asumido, reversible: algo oculto en **cualquier** dimensión de la sesión
   (`hasExcludedFilters`), como dice el título de la card original («con exclusiones activas»).
4. **Tocar lo que ya se ve solo, sin nada oculto** → asumido, reversible: quita el filtro, como hacía el toque antes de
   #634. «Ver solo X» sobre lo que ya se ve solo no haría nada.
5. **Dónde** → en el host común `.segmentFilterChoiceHost()`: Panel y Distribución pasan por él, así que la paridad sale
   de una sola decisión.
6. **Ficheros**: `SegmentFilterChoiceSheet.swift`, `CombinedEntityFilterTests.swift`, `SegmentFilterChoiceUITests.swift`,
   `qa/coverage-index.json`, `.claude/rules/session-filters.md`, el ticket en `done/`.
