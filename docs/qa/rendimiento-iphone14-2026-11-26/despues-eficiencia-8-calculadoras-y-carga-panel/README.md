# Lote 8 · Calculadoras compartidas de saldo y carga del Panel — iPhone 14

Medido el 27-nov-2026 entre las 12:33 y las 13:23 (Lima) en el iPhone 14 de Jürgen («iPhone de JURGEN», iOS 27.2.1), por
cable a la Mini, desbloqueado. Mismo método y almacén que el lote 7: copia de perfilado (`Release-Dev` optimizada con
`DEBUG` encendido solo en la copia) y el almacén `YalaModel-UITest` de **16.004 movimientos**, abierto con
`-uitest -uitest-skip-onboarding`.

- **Antes**: `origin/2.3` en `a2b8bc3b2` (con el lote 7).
- **Después**: la rama de este lote, el mismo código que va en el PR.

Cada lado: una traza de arranque en frío de 60 s (Time Profiler + os_signpost, `scripts/arranque_traza.sh`) y 3 arranques
en frío con consola (`scripts/arranques.sh`).

## Resumen

| Qué | Antes | Después |
|---|---|---|
| **Saldo vivo**: tramo más largo sin ceder | 197 ms (foto) · 197 ms (Panel) · 201 ms (nota de salud) | **≤ 50 ms** en la foto y en el cálculo del Panel · la nota de salud sigue en **204 ms** (fuera del encargo, abajo) |
| **Saldo vivo**: tramos de más de 50 ms | 7 | 1 (la nota de salud) |
| **Valoración de la curva** (lectura de tasas de la foto): tramo más largo | 146 ms, dentro de un tramo de 218 ms de la curva | **29 ms**; la curva entera, **46 ms** |
| **Saldos por cuenta**: tramo más largo | 158 ms (foto) · 149 ms (carga del Panel) · 165 ms (nota de salud) | **≤ 50 ms** en la foto y en la carga del Panel · la nota de salud, **140 ms** |
| **Carga del Panel**: tramo más largo sin ceder | 293 ms (huérfanos 108 + saldos de las cuentas 149 + listas) | **27 ms** en la traza · **29 / 29 / 48 ms** en los 3 arranques (`PERF panel-carga`) |
| **Foto de los widgets**: tramo más largo (`PERF widgets-foto`) | 205 / 210 / 211 ms | **128 / 126 / 128 ms** |
| **Foto**: bloques de más de 100 ms | 4 (198, 218, 160, 152 ms) | **1** (153 ms: la proyección del saldo, `ProyeccionFoto.resultado`; no es de este lote) |
| **Cálculo del Panel**: tramo más largo (`PERF panel-calculo`) | 638 / 649 / 659 ms | **425 / 432 / 435 ms** |
| **Arranque**: cuelgues > 250 ms en los primeros 60 s | 6 · 2,6 s · el mayor 607 ms | **4 · 1,4 s · el mayor 422 ms** |
| **Arranque**: cuelgues de la foto de los widgets | 1,1 s | **0** |
| **Arranque**: Panel listo (`PERF arranque`, 3 arranques) | 10,6 / 10,5 / 10,7 s | **10,0 / 10,0 / 10,1 s** |
| **Arranque**: cálculos completos del Panel | 1 / 1 / 1 | 1 / 1 / 1 |

«Tramo sin ceder» es una racha de muestras del hilo principal (1 ms cada una, huecos de menos de 3 ms) con la pieza en la
pila (`scripts/tramos_calculadoras.py`), el corte del lote 7. Una cesión deja un hueco de ~2 ms, así que este corte puede
unir dos tramos separados por una cesión: el «después» sale por lo alto, nunca por lo bajo. Con un corte de 1,5 ms el
muestreo parte tramos que no cedieron (la suma de saldos de la foto, de una vez, salía en 80 + 71 ms): por eso no se usa.

## Qué cambió

**Las tres calculadoras, un solo cuerpo de reglas.** Cada una gana un acumulador fila a fila con dos entradas: el
movimiento (`TransactionItem`) y lo ya leído de él (cuenta, fecha, divisa, importe). La versión de una vez, con la misma
firma de siempre, recorre con ese acumulador, así que Tendencias, saldo a fin de mes, alertas, notificaciones, borrado de
cuenta, flujo de caja y la nota de salud siguen dando lo mismo:

- `LiveBalanceCalculator.SumaSaldoVivo` (saldo vivo; `addNative` también pasa por la misma suma).
- `AccountBalanceCalculator.SumaSaldosPorCuenta` (saldos por cuenta; la conversión a la divisa de la cuenta es la misma
  función, `amountInAccountCurrency`).
- `BalanceValuation.LecturaDeTasas` (la lectura de las tasas de los cierres, de una vez o por tandas de días).

**La foto de los widgets** suma el saldo vivo y los saldos de las tarjetas sobre las filas que ya leyó (`FilaFotoWidget`),
sin volver a leer de SwiftData los 16 mil movimientos, y por tramos de ~20 ms (`RecorridoConReloj`). La curva
(`TendenciaFoto`) suma las filas por día y lee las tasas por tandas de 24 días, también por tramos.

**El Panel**:

- La carga del arranque va por tramos que ceden el hilo (`PanelViewModel.cargarPorTramos`, `CesionDelHilo`). El ajuste de
  los gastos de grupo y el recuento de movimientos sin cuenta reciben solo las filas que miran (con gasto de grupo o sin
  cuenta: `CargaPanelPorTramos.importaAGruposOHuerfanos`), y los saldos de las cuentas y las líneas de la tarjeta «Grupos»
  se suman en una sola pasada (antes, dos). Marca `os_signpost` «Panel.carga» (`com.yala` / `PanelCarga`) y, en DEBUG,
  `PERF panel-carga`.
- En el cálculo, el saldo vivo del último punto de la curva se suma por tramos y **una sola vez** (lo pedían la tendencia y
  la comparación con el período anterior, con las mismas cuentas y movimientos), y el saldo grande también por tramos.

## Paridad

`YalaTests/Eficiencia8CalculadorasYCargaPanel/`, contra copias congeladas del código previo
(`ReferenciaCalculadorasPreLote8.swift`):

- `CalculadorasPorTramosParidadTests`: saldo vivo y saldos por cuenta, de una vez, por tramos y sobre filas, iguales al
  código previo, con y sin filtros de cuentas y con dos calidades de tasa; y la foto de los widgets (saldo total y tarjetas).
  Fixture: dos divisas y movimientos en otra divisa que la de su cuenta, cuenta excluida, cuenta archivada, sin cuenta,
  fechas futuras, ajustes de saldo, saldo inicial y transferencias.
- `BalanceValuationPorTandasTests`: la valoración con tasas leídas por tandas de 1, 7 y 24 días vale lo mismo, cierre a
  cierre, que la de una vez, con el converter real sobre filas parciales, huecos, una tasa a cero y un tramo de 40 días sin
  filas; y las tasas leídas son las mismas día a día. La curva de la foto por etapas sale igual que la de una vez.
- `CargaPanelParidadTests`: la carga de una vez y la recarga por tramos dejan el ajuste de grupos (fila a fila), el recuento
  de huérfanos, los saldos de las cuentas, las líneas de Grupos y el saldo grande iguales al código previo sobre el
  historial entero, con gastos de grupo de dos patas, liquidaciones, filas sin cuenta con y sin puntero, y fechas futuras.

**Mutantes** (cada uno pone en rojo su prueba):

| Mutante | Cae |
|---|---|
| El saldo vivo deja de cortar en el final de hoy | saldo vivo (las tres vías, 6 casos) y el saldo grande del Panel |
| Los saldos por cuenta suman el importe sin convertir a la divisa de la cuenta | saldos por cuenta (las tres vías), tarjetas de la foto y saldos del Panel |
| Cada tanda de tasas pisa las anteriores | la valoración por tandas (9 de 9 combinaciones). Antes de reforzar la prueba **sobrevivía**: `value` pide sola la tasa que falta y da el mismo número, así que ahora se comparan también las tasas leídas |
| El filtro de la carga deja fuera las filas sin cuenta | huérfanos, en la carga de una vez y en la por tramos |
| Las líneas de Grupos dejan de cortar en el final de hoy | líneas de Grupos, en las dos cargas |

## Lo que queda (fuera de este encargo)

- **La nota de salud del Panel** (`FinancialScoreCalculator.plan`, `FinancialScoreAlertsLogic.negativeAccounts`) llama a
  las versiones de una vez del saldo vivo (204 ms) y de los saldos por cuenta (140 ms), como antes (201 y 165 ms). Partirlas es tocar esos dos
  ficheros, que no estaban en el encargo: ya tienen el acumulador y `CalculadorasPorTramos` listos para usarlos.
- **La curva de saldo de la app** (`TrendDataProcessor.fillBalanceBuckets`): tramos de 181, 178 y 177 ms en el Panel. No es
  `BalanceValuation` (su lectura de tasas en el Panel no pasa de 30 ms) sino las pasadas de esa función por los 16 k
  movimientos; partirla es tocar `TrendDataProcessor.swift`.
- **La proyección del saldo en la foto** (`WidgetDataCache.ProyeccionFoto.resultado`, el motor del mes): el único bloque de
  más de 100 ms que le queda a la foto (153 ms). `FlujoMotorMes*` lo tocaba otra sesión en paralelo.
- El resultado cambiario (`FXPnLLogic`, 79 ms) y el resto del cálculo del Panel (contexto, proyección, nota de salud:
  tramo máximo ~430 ms) no son de las tres calculadoras.

## Archivos

- `datos/{antes,despues}_tramos_calculadoras.txt`: tramos sin ceder de cada pieza en la traza de arranque.
- `datos/{antes,despues}_cuelgues_arranque.txt`: cuelgues > 250 ms de los primeros 60 s con su dueño.
- `datos/{antes,despues}_foto_arranque.txt`: la foto de los widgets en la traza (método del lote 7).
- `datos/{antes,despues}_bloques_panel.txt`: rachas del hilo principal ocupado por el Panel. Ojo: una racha une las tareas
  que se intercalan sin hueco (la foto corre a la vez), así que no mide «sin ceder» de una pieza; para eso, los tramos.
- `datos/consola-{antes,despues}.N.extracto.txt`: líneas `PERF` de cada arranque en frío.
- `scripts/`: `arranque_traza.sh`, `arranques.sh`, `tramos_calculadoras.py` y `bloques_panel.py` (nuevos), y
  `trazas.py`, `arranque_cuelgues.py`, `foto_en_traza.py` (del lote 7). Las trazas (`.trace`) quedan en la Mini:
  `~/Claude/entregas/2026-11-27-eficiencia-8-calculadoras-y-carga-panel/trazas/`.
