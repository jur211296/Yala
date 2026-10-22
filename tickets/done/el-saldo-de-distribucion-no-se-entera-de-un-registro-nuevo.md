---
id: el-saldo-de-distribucion-no-se-entera-de-un-registro-nuevo
status: done
priority: medium
area: statistics
created: 2026-09-06
updated: 2026-10-09
source: hallazgo de la review adversarial de distribution-balance-kpi-skips-fx
---

# Registras un gasto y el saldo de Distribución no cambia

## Qué ve el usuario

Estás en **Estadísticas → Distribución** con la métrica Balance. Abres el botón de añadir, registras
un ingreso de 500 y vuelves. El Panel ya dice 6.500; Distribución sigue diciendo 6.000. Se arregla
solo al cambiar de pestaña o de filtro, pero hasta entonces enseña un saldo que no es el tuyo.

Con editar el **importe** de un movimiento existente es peor: no cambia el número de movimientos, así
que ni siquiera el observador que hay salta.

## Causa

`CategoriesTabView` recalcula en `calculateData()`, y sus disparadores son todos de **filtro**
(período, cuentas, categorías, etiquetas, monedas, importe, búsqueda, chips…). El único que mira los
datos es `.onChange(of: allTransactions.count)` (`:202`) y **solo llama a `recomputeSankey()`**, no a
`calculateData()`.

Esto era tolerable mientras el hero mostraba el **flujo del período**: ese número solo cambia con
movimientos dentro del período y de las categorías visibles, y el resto de la pantalla quedaba rancio
a la vez, así que era coherente consigo mismo. Desde 2026-09-06 el hero muestra un **saldo**, y un
saldo cambia con cualquier movimiento de cualquier fecha y cualquier cuenta. La dependencia se
ensanchó y los disparadores no.

Es la contrapartida que `.claude/rules/swiftui-ds.md` avisa al precalcular en un ViewModel: mover un
cálculo fuera del body corta el live-binding a los `@Model`, y entonces el refresco depende entero de
que todo mutador llegue al recálculo.

## Alcance

`totalAmount` (el flujo) tiene el mismo agujero y es **preexistente** — no se abrió con el cambio del
KPI. Lo que cambió es cuánto se nota.

## Qué mirar al arreglarlo

`DetailContainerView` ya tiene un `.onChange(of: sessionState.dataVersion)` (`:201`) que recarga el
array; el problema es que la pestaña observa `.count` y no el contenido. Y hay un debounce de 150 ms
en el contenedor (`:538-548`) del que `calculateData()` no cuelga, así que atarlo a `dataVersion` sin
más puede recalcular de más — medir antes: el cálculo cuesta ~15 ms con 5.475 movimientos.

## Acceptance Criteria

- [x] Registrar un movimiento estando en Distribución actualiza el hero sin cambiar de pestaña.
- [x] Editar el importe de un movimiento existente también.
- [x] No se recalcula más veces por gesto que ahora (medido, no supuesto).

## Hecho (2026-10-09)

**Qué cambia para el usuario.** Registras o editas un movimiento con Estadísticas → Distribución abierta y el hero
(saldo en Balance, flujo en Ingresos/Gastos), los pies, necesidades, etiquetas, la comparación con el período
anterior y el Sankey se ponen al día solos, sin tocar un filtro.

**Cómo.** `DetailContainerViewModel.dataGeneration` avanza cuando una recarga del store trae algo nuevo: otro
`dataVersion` desde la anterior (lo suben todos los mutadores, también las ediciones en sitio) o arrays distintos.
`CategoriesTabView` sustituye su `.onChange(of: allTransactions.count) { recomputeSankey() }` por
`.onChange(of: dataGeneration)`, que llama a `calculateData()` y `recomputeSankey()`. Cuelga del debounce de 150 ms
del contenedor y corre después del fetch. El cálculo del saldo y del flujo no se tocó.

**Medido en el simulador** (iPhone 17 Pro, iOS 27.0, seed `minimal`, período «Este mes», contadores temporales que no
se commitearon):

| Gesto | Antes: `calculateData` / Sankey / pases del contenedor | Después |
|---|---|---|
| Entrar en Distribución | 1 / 2 / 1 | 1 / 2 / 1 |
| Cambiar de período | 1 / 1 / 1 | 1 / 1 / 1 |
| Registrar un ingreso de 500 | **0** / 1 / 3 — hero rancio (8,237) | **1** / 1 / 3 — hero al día (8,737) |
| Abrir «Nuevo registro» y cerrarlo sin guardar | — | 0 / 0 / 1 |

Una primera versión avanzaba el contador en cada recarga y el alta salía 2 / 2 / 3: el contenedor recarga dos veces
por alta (al guardar, por `dataVersion`, y al cerrar la pantalla de éxito, por el `onDisappear`). Por eso el contador
solo avanza si la recarga trae algo.

**La edición en sitio**, en un iPhone, solo se da con la pestaña montada: llega por sync, desde otra ventana del iPad
o desde el chat de Yala IA abierto encima. Editar en otra pestaña principal y volver ya funcionaba antes: cambiar de
pestaña remonta Estadísticas (medido). Esa rama la cubre el test unitario.

**Tests.** `YalaTests/DetailContainerDataGenerationTests` (alta, edición del importe con las mismas filas, recarga sin
nada nuevo) y `YalaUITests/StatisticsHeroLikePanelUITests#test_distributionHeroFollowsANewRecord` (alta desde
Distribución → el hero cambia). Controles rojos: ver el PR.

**Capturas:** `capturas/antes.png` (hero en 8,237 tras registrar 500) y `capturas/despues.png` (8,737).

**Hallazgos con ticket propio:** `trends-cards-ignore-an-in-place-amount-edit` (Tendencias tiene el mismo agujero con
la edición en sitio) y `distribution-sankey-recomputes-on-every-render-with-all-time`.
