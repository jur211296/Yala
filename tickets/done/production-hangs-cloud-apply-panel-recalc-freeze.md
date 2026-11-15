---
id: production-hangs-cloud-apply-panel-recalc-freeze
status: done
priority: high
area: cloud-sync, panel
created: 2026-11-13
updated: 2026-11-13
source: Sentry YALA-IOS-J, YALA-IOS-K y la regresión de YALA-IOS-A (build distribuida 2.2 (9), iPhone14,7, iOS 27.2, 12-nov)
---
# Tres cuelgues de producción: aplicar la nube, recalcular el Panel y el congelamiento

## Qué pasaba

Los tres saltaron en el mismo iPhone 14 el 12-nov, en dos aperturas seguidas. Leído por API de Sentry (eventos completos):

- **YALA-IOS-J** (23:41:38 UTC, App Hang Fully Blocked). Tras «Activar la nube» (`/account/claim` a las 23:40:45), el primer
  pull bajó la cuenta en páginas de 500: los `GET /sync/pull` salen cada 3-4 s, de 23:40:52 a 23:41:36. Cada hueco es una
  página aplicada en el hilo principal. Stack: `pullLoop › applyPage (SyncApplyEngine:330) › saveWithAuthor › dispatchApply
  › EntityApplyMap.findTransactionItem (1164) › fetchFirstOrThrow (1304)`.
- **YALA-IOS-A** (23:41:43, Non Fully Blocked, regresión). Misma apertura (`app_start_time` 23:40:33) y los mismos
  breadcrumbs que J, cinco segundos después: la app seguía colgada por las mismas páginas. El stack es el run loop, sin
  código propio. **No es la foto de perfil**: `ProfileImageStorage` es idéntico en `v2.2` y en `2.3` (la foto se guarda a
  512 px desde el PR 827), y ningún lector nuevo decodifica la foto entera.
- **YALA-IOS-K** (23:47:11, Non Fully Blocked). Siguiente apertura (23:42:10). Stack: `scheduleRecalculation (2712) ›
  loadData (482) › NSManagedObjectContext.performAndWait`: el `fetch` de TODOS los movimientos del Panel, de una vez, en el
  hilo principal. Antes, toques que no respondían (`_handleMultiTapGesture` ×5 en un segundo).

## Causa

- **J y A**: ninguna columna de búsqueda tiene índice (`#Index` no aparece en ningún `@Model`), y el bucle de `applyPage`
  buscaba fila a fila de cinco a diez veces por delta (la fila, el destino de cada ref, el dangler de cada ref, el
  testigo de identidad, el reloj por unidad). Cada búsqueda recorría la tabla entera: el coste de una página era deltas ×
  filas.
- **K**: la recarga del Panel lee todos los movimientos para la tendencia y los saldos, en una sola lectura, y el
  cálculo de widgets va detrás sin soltar el hilo.

## Arreglo

- **J (y con él A)**: `EntityApplyMap.prepareLookups` lee por lote, antes del bucle, lo que la página va a buscar: sus filas
  por tabla (un `IN` por tabla), testigos, relojes y danglers de esas filas, y enteras las tablas pequeñas a las que
  apuntan las refs (cuentas, categorías, subcategorías, etiquetas). La caché (`ApplyPageLookups`) vive solo dentro de la
  página y se mantiene al día con lo que la página inserta o borra. Una lectura por lote que falla deja el tipo sin cubrir
  y la búsqueda va al `fetch` de siempre, que lanza como antes: la página falla exactamente donde fallaba. `CashFlowLine` y
  `CashFlowOverride` no se cubren: los borra en cascada su plan, y esa cascada solo la ve un `fetch`.
- **K**: `PanelViewModel.fetchTransactionsInSlices` lee los movimientos por tramos de 1.500, siguiendo el orden por clave
  (fecha, instante de creación) y descartando por identidad lo ya leído, y cede el hilo entre tramos (1 ms de espera,
  para que el run loop atienda toques). Lo que se pida durante la lectura se suma al cálculo en curso; una recarga
  pedida entonces abre la vuelta siguiente. Dos cosas que cazó la review adversarial: lo que se borra entre dos tramos se
  descarta al final (leer un `@Model` borrado aborta en el iPhone), y la lectura termina cuando un tramo no trae nada
  nuevo, no cuando trae menos de 1.500 (con cambios sin guardar un tramo puede traer uno de más o de menos).

## Medido (simulador iPhone 17 Pro, iOS 27.2, en la Max)

| Caso | Antes | Después |
|---|---|---|
| Página de 500 cambios sobre 4.000 movimientos | 2,83 s | 0,24 s |
| Página de 500 movimientos nuevos sobre 4.000 | 4,77 s | 0,38 s |
| Recarga del Panel con 20.000 movimientos: bloque más largo del hilo principal | 0,45 s | 0,22 s |

En el iPhone 14 de producción cada página costaba ~4 s (los breadcrumbs de J), en línea con ser varias veces más lento que
el simulador. No se midió en el iPhone 14: estaba en la Mini y esta sesión corrió en la Max.

## Tests (`YalaTests/SentryHangs2026Nov/`)

- Review adversarial con dos lentes (corrección de la caché del apply; concurrencia del Panel). La primera no encontró
  nada sólido (diez hipótesis refutadas en el código); la segunda, los dos casos del Panel de arriba.
- `ApplyPageBatchLookupTests` (9): testigo `EntityApplyMap._testSingleRowFetches` (< 30 búsquedas sueltas por página de
  300; sin el arreglo, más de 1.000) y coherencia de la caché. Mutantes: sin poner la caché caen los dos testigos; sin
  apuntar lo insertado caen tres casos de coherencia.
- `PanelSlicedLoadTests` (6): el hilo atiende otro trabajo entre tramos, el resultado es el de la lectura de una vez
  también con empates en el borde, un tramo entero de la misma clave, un borrado entre tramos, cambios sin guardar y la
  recarga completa. Mutantes: sin ceder cae el primero; con `<` en el borde caen tres; sin descartar lo borrado cae el
  del borrado.

## Lo que queda

- El cálculo de widgets del Panel (`performCalculation`) sigue siendo un solo bloque: ~0,22 s con 20.000 movimientos en
  el simulador.
- El pull aplica hasta 50 páginas seguidas; cada una sigue siendo un bloque del hilo principal, ahora ~12 veces más corto.

## QA en el iPhone 14

1. Con una cuenta en la nube con muchos registros y grupos, en una instalación nueva de la build que lo trae: «Ya tengo
   una cuenta» → entrar → esperar a que baje todo. La app responde a toques mientras baja y Sentry no recibe App Hang.
2. Con la app abierta en el Panel, ir a otra pestaña, cambiar algo en Ajustes y volver al Panel: sin trabas al volver.
