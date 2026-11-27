# Lote 7 · Foto de los widgets, arranque en frío y proyección más livianos — iPhone 14

Medido el 27-nov-2026 entre las 06:36 y las 08:10 (Lima) en el iPhone 14 de Jürgen («iPhone de JURGEN», iOS 27.2.1), por
cable a la Max, desbloqueado. Mismo método que el informe y los lotes 1-6: copia de perfilado (`Release-Dev` optimizada con
`DEBUG` encendido solo en la copia, `scripts/perfil.sh`) y el almacén `YalaModel-UITest` de **16.004 movimientos**, abierto
con `-uitest -uitest-skip-onboarding`.

- **Antes**: `origin/2.3` en `a5e93673f` (con los lotes 1 a 6), medido esta mañana.
- **Después**: la rama de este lote, el mismo árbol que va en el PR (comparado fichero a fichero con la copia medida).
  «Después 1» es una iteración intermedia (sin la lectura por tramos de la foto); las cifras finales son las de «después».

## Resumen

| Qué | Antes | Después |
|---|---|---|
| **Foto de los widgets en el arranque**: hilo principal | 5,6 s | **2,9 s** |
| **Foto**: el bloque más largo sin ceder | 1.250 ms | **216 ms** |
| **Foto**: bloques de más de 100 ms | 14 | **3** |
| **Arranque**: cuelgues > 250 ms en los primeros 60 s | 21 · 11,9 s · el mayor 1.370 ms | **6 · 2,4 s · el mayor 659 ms** |
| **Arranque**: Panel listo (`PERF arranque`, 3 arranques) | 14,1 / 15,9 / 16,2 s | **10,7 / 10,4 / 10,6 s** |
| **Arranque**: cálculos completos del Panel | 2 / 1 / 1 | 1 / 2 / 1, y 5 de 5 en la copia instrumentada |
| **Proyección del saldo**: el tramo de una vez | ~0,9 s (lote 4) | por trozos de 256 movimientos; ya no aparece como bloque |
| **Salir y volver** (10 ciclos, ciclos 2-10) | 1,4 s de hilo en 20 s · 0 cuelgues | igual (1,4 s · 0) |
| **Foto al salir** | 0 ms (lo quitó el lote 1) | 0 ms |
| **Scroll**: pasadas fuera de pantalla, mediana | Panel 33 · Tendencias 34 · Distribución 35 · Pagos 34 | igual (32 · 34 · 35 · 34): no se tocó el render |

## 1. Foto de los widgets (Sentry YALA-IOS-16)

**Qué pasaba** (`datos/V_antes_foto_arranque.txt`): la foto se hacía por etapas desde el lote 3, pero cada etapa era de una
vez y cada uno de los ocho períodos volvía a leer de SwiftData los 16 mil movimientos —fecha, cuenta, categoría y el importe
convertido (`amountInPreferredCurrency`), cuatro o cinco veces por período—. Los resúmenes de período eran 3,1 s de los 5,6;
la proyección 0,8 s; leer y filtrar 0,5 s; la curva 0,5 s.

**Qué cambió:**

- **Cada movimiento se lee una vez por foto** (`Yala/App/Logic/FotoWidgetsArranque/FilaFotoWidget.swift`): una fila con la
  fecha, la cuenta, la categoría, la clasificación y el importe ya resuelto con la regla de la app
  (`CashFlowCalculator.resolvedAmount`). Los ocho períodos, las categorías, las subcategorías y el flujo por día suman sobre
  filas. Es la misma regla, no una copia: las funciones de siempre (`buildPeriodSummary(transactions:…)` y sus piezas) leen
  filas y llaman al mismo cuerpo.
- **Etapas reanudables**: las largas (leer los movimientos, leer las filas, los presupuestos, la curva, la conversión de la
  proyección) se cortan a los ~20 ms y siguen donde se quedaron (`RecorridoConReloj`); entre tramo y tramo la foto cede el
  hilo y comprueba que nada se guardó, como entre etapas.
- **La lectura de los movimientos va por tramos de 1.500** con la pieza del Panel (YALA-IOS-K), ahora compartida
  (`Yala/App/Logic/RecalculoPanel/LecturaMovimientosPorTramos.swift`): de una vez eran 414 ms.
- **Marca** `os_signpost` «Widgets.foto» (`com.yala` / `FotoWidgets`) y, en DEBUG, `PERF widgets-foto total … · tramos …
  · tramo máx …`. Antes del cambio no había marca: el «antes» sale del Time Profiler.

**Paridad** (`YalaTests/EficienciaFotoWidgetsArranque/FotoWidgetsFilasParidadTests.swift`): los ocho resúmenes y la curva
salen idénticos, byte a byte en JSON, a una copia congelada del código previo (`ReferenciaFotoPreLote7.swift`) sobre un
almacén con dos divisas, conversión guardada y sin guardar, devoluciones, sin categoría, subcategorías, ajustes de saldo,
cuenta excluida, cuenta archivada y fechas futuras. Mutantes: quitar el filtro de saldo de la curva o cambiar la clave de
las categorías ponen rojos los dos casos de paridad.

**Lo que queda en la foto** (`datos/V_despues2_foto_arranque.txt`): tres tramos de 170-216 ms en calculadoras compartidas que
no se pueden partir sin tocarlas: el saldo vivo (`LiveBalanceCalculator.liveBalanceBreakdown`), la valoración de la curva
(`BalanceValuation`) y los saldos por cuenta (`AccountBalanceCalculator.batchCalculateBalances`). Ninguno pasa de 250 ms.

## 2. Arranque en frío: un solo cálculo del Panel

**Qué pasaba**: la subida de `dataVersion` del final del arranque (`AppBootstrapper`, paso 19) es un empujón para que Grupos
recargue; el Panel la oía como un cambio de datos y, si su primera carga ya estaba en marcha, hacía un segundo cálculo
completo (~6 s con 16 k). Según cuándo caía el empujón: dos cálculos en el arranque 1 del «antes», uno en los otros dos.

**Qué cambió** (`Yala/App/Logic/FotoWidgetsArranque/EmpujonFinDeArranque.swift`): el Panel no recalcula por ESE empujón si,
desde que empezó su carga, no hubo otra subida de `dataVersion`, ni un guardado, ni un cambio de la nube, ni cambios sin
guardar, ni cambio de día. Cualquiera de esas cosas —lo que el segundo cálculo corregía— recarga como siempre.
`dataVersion` no se puede ignorar en general: un borrado con «Deshacer» la sube sin guardar nada.

**Pruebas** (`YalaTests/EficienciaFotoWidgetsArranque/EmpujonFinDeArranqueTests.swift`): la decisión caso a caso; con el
Panel cargado y a mitad de la carga por tramos, un solo cálculo; y los tres controles (guardado, otra subida, aviso de la
nube) recalculan. Mutante: si el Panel no absorbe el empujón, caen los dos casos.

**En el iPhone**: en la consola, `empujón del final del arranque sin datos nuevos → no recarga` en los arranques en que cae
a mitad de la carga. Un arranque de los 8 del «después» hizo dos cálculos; la copia instrumentada (pila de cada petición, no
está en el PR) no lo repitió en 5 arranques y no se sabe qué lo pidió: queda anotado.

## 3. Proyección del saldo

`ProjectedFlowBuilder.PrecalculoMotor` convierte los movimientos del motor del mes (`FlujoMotorMesEntrada.movimientos`, el
80 % de la proyección) por trozos de 256 y cede entre trozo y trozo: la foto con sus etapas reanudables y el Panel con su
`CesionDelHilo`. El motor convierte movimiento a movimiento y en orden, así que unir los trozos da lo mismo que de una vez
(prueba: `proyeccionPorTrozos_igualQueDeUnaVez`, sin plan y con filtros; mutante: perder el último de cada trozo la pone
roja). Con plan de flujo de caja no se convierte nada por adelantado: manda el plan (`CashFlowProjectionCalculator`), que
sigue de una vez — **anotado**, partirlo es tocar ese calculador. `FlujoMotorMes*` no se tocó (lo usaba otra sesión).
Tendencias (`StatisticsViewModel`) y el saldo a fin de mes siguen con la versión de una vez.

## 4. Suelo de pasadas fuera de pantalla en el scroll

Medido con una copia de atribución (interruptores temporales `-perfTempSinBarras` y `-perfTempSinGraficas`,
`scripts/interruptores_render.py`, no están en el PR), pasada D solo del Panel, 3 rondas (`datos/R_*_panel.txt`):

| Variante | Mediana | Máx. |
|---|---|---|
| Como hoy | 32 | 64 |
| Sin la barra de pestañas ni la de navegación | **18** | 51 |
| Sin las gráficas (opacidad 0) | 34 | 72 |
| Sin barras ni gráficas | 20 | 52 |

**El suelo son las barras del sistema** (cristal de iOS sobre el contenido que se desplaza): unas 14 pasadas por fotograma.
Las gráficas no lo mueven. Las barras no son código del Panel y quitarles el cristal es una decisión de diseño, así que no se
tocó nada: queda medido como propuesta. Tendencias, Distribución y Pagos tienen el mismo suelo (34-35, `datos/D_*`); la
barra de pestañas es común a todas, la de navegación de cada una no se aisló.

## 5. Salir y volver

Sin cambios, como se esperaba: la foto ya no corre al salir si nada cambió (lote 1), y la vuelta cuesta lo mismo
(`datos/V_*_por_vuelta.txt`).

## Archivos

- `datos/consola-{antes,despues,despues2,instr}.N.extracto.txt`: líneas `PERF` y de cálculo de cada arranque en frío
  (`scripts/arranques.sh`). `instr` es la copia instrumentada.
- `datos/V_*`: pasada «vuelta» (arranque + 10 ciclos): por vuelta, foto en el arranque, foto después del arranque y cuelgues
  del arranque con su dueño (`scripts/arranque_cuelgues.py`, `scripts/foto_en_traza.py`).
- `datos/D_*_por_pantalla.txt`, `datos/R_*_panel.txt`: pasadas fuera de pantalla por pantalla y por variante.
- `datos/*.ciclos.csv`: los eventos de cada pasada.
- `scripts/`: los guiones (los del lote 6 más los de este lote). Las trazas (`.trace`) quedan en la Max:
  `~/Claude/entregas/2026-11-27-eficiencia-7-foto-widgets-y-arranque/trazas/`.
