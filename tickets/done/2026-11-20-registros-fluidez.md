---
id: 2026-11-20-registros-fluidez
status: done
priority: high
area: "cash-flow-plan, records-list-search"
created: 2026-11-20
updated: 2026-11-20
card: tablero-la-app-se-traba-unos-segundos-leyendo-la-29lf
source: "Sentry YALA-IOS-12, YALA-IOS-Q y YALA-IOS-P (build 2.3 (4), 19-nov-2026) + Jürgen 20-nov 06:35 (barra de búsqueda)"
---

# La app se traba en el Flujo de caja; y Registros sin barra de búsqueda arriba

Tres cuelgues de Sentry en la build 2.3 (4), en el iPhone de Jürgen, el 19-nov en la misma media hora. El encargo los
atribuía a la pestaña Registros; **las pilas dicen otra cosa**: los tres son del Flujo de caja.

- YALA-IOS-12 («leyendo la fecha»): `TransactionItem.date` ← `FlujoMotorMesEntrada.movimientos` ← `CashFlowProjectionCalculator.calculate` ← `ProjectedFlowBuilder` ← la tendencia del Panel.
- YALA-IOS-Q («leyendo el pago planificado»): `TransactionItem.scheduledPaymentID` en el mismo bucle ← `FlujoDetalleLineaLogica.seisMeses` ← la hoja del detalle de una celda del flujo.
- YALA-IOS-P («agrupando por mes»): `String(format:)` de la clave «AAAA-MM» ← `TransactionIndex.init` ← `CashFlowPlanViewModel.recalculate`. El frame `RecordsMonthSectionsLogic.monthKey` era la misma función fusionada por el enlazador.

## Hecho cuando

El cálculo del plan no lee la historia dos veces de SwiftData, el mes de cada movimiento no se pide al calendario uno a
uno y la clave del mes no pasa por `String(format:)`, con un test que caiga sin el arreglo. Y la barra «Buscar en
Registros» no sale en Registros ni en Estadísticas › Registros, sin perder lo que hacía.

## Resolución (2026-11-20)

- El índice de las líneas sale de los movimientos que el motor ya leyó (`TransactionIndex(movimientos:)`), en el plan y en el detalle de una línea.
- `MonthBucketer`: el mes de una fecha con caché del último intervalo (pertenencia exacta, mismo resultado con husos y cambio de hora). `MonthKeyText` arma la clave sin formato de C.
- Medido con 6.000 movimientos en el simulador (Debug): proyección del plan 215 → 122 ms; motor del mes 96 → 66 ms; clave de mes ×6.000 7,2 → 1,9 ms. Una pasada del índice por SwiftData (~60 ms) desaparece del cálculo del plan.
- Probado y descartado (sin ganancia medible, 123 → 121 ms): leer una vez los importes y la categoría para ingreso/gasto y saltar la lectura del id en el ajuste de grupos sin patas. Revertido.
- Tests: `YalaTests/RegistrosFluidez/FlujoSinTrabasTests` (testigos `TransactionIndex._testModelPasses` y `MonthBucketer._testCalendarLookups`, paridad del índice y de la clave, bordes del mes en Lima, Madrid y Santiago). Tres mutantes con el código viejo: los tres caen.
- Barra: fuera de Registros y de Estadísticas › Registros. «Todo» de Buscar usa la misma regla (`RecordsListSearchLogic`: importe y sin tildes); los chips de un campo comparan sin tildes. Lo que no se llevó —buscar solo dentro del período y filtros a la vista, con la suma arriba— va en la card `tablero-buscar-buscar-solo-dentro-del-periodo-y-83q0`.

## Pendiente

- Confirmar en el iPhone que los cuelgues no vuelven (Sentry, siguiente TestFlight). Lo medido es en el simulador: el teléfono tarda más por movimiento, así que la mejora relativa debería sostenerse pero el umbral de 2 s no está medido allí.
