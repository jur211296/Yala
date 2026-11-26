# Lote 3 · Yala no muere en segundo plano — antes y después en el iPhone 14

Medido el 26-nov-2026 entre las 16:16 y las 16:45 (Lima) en el iPhone 14 de Jürgen («iPhone de JURGEN», iOS 27.2.1), por
cable a la Max, desbloqueado y cargando. La misma copia de perfilado que el informe de origen (`Release-Dev` optimizada
con `DEBUG` encendido solo en la copia) y el mismo almacén `YalaModel-UITest` de 16.004 movimientos, abierta con
`-uitest -uitest-skip-onboarding` (sin reset). Sin Instruments: la consola de la app (`devicectl … --console` con
`OS_ACTIVITY_DT_MODE`) y los informes de cierre del teléfono (`devicectl … --domain-type systemCrashLogs`).

- **Antes**: la rama del lote 1 (`origin/encargo/2026-11-26-eficiencia-1-volver-sin-recalcular`, del que depende este
  lote), sin cambios. Lleva ya el lote 2 de `2.3`.
- **Después**: la misma base con los cambios de este lote.

## Resultado

| Escenario | Antes | Después |
|---|---|---|
| Abrir Yala en frío, salir a otra app a los 3 s, 3 s fuera, volver (5 vueltas) | **4 de 5 cerradas por iOS** (`0x8BADF00D`, «scene-update watchdog … 10.00 seconds», en segundo plano) | **0 de 5** |
| 10 ciclos: volver, tirar para actualizar, salir a los 2-5 s, 3 s fuera | 0 cierres; **5 recálculos completos** del Panel (~7-8 s de hilo cada uno) por tirar para actualizar | 0 cierres; **0 recálculos** («tirar para actualizar → sin cambios, no recarga», 10 de 10) |
| Informes nuevos en el teléfono tras las dos pasadas | 4 × `Yala-*.ips` | **ninguno** (ni `Yala-*.ips` ni `cpu_resource`) |
| Arranque en frío hasta el Panel listo (`PERF arranque`) | 10,5 s (10,7-11,9 s en las vueltas con salida) | 10,6 / 10,8 / 12,3 s |

Contra la mejora esperada del encargo («cero cierres del vigilante en 10 ciclos con salidas a los 2-5 s de volver»):
**se cumple** en los ciclos en caliente y también en el caso que de verdad cerraba la app, el arranque en frío con salida
rápida. **El arranque en frío no baja de 3 s**: sigue en ~11 s porque el cálculo del Panel con 16 k cuesta eso entero; lo
reparte en tramos el lote 4. Este lote no lo prometía (solo pedía medirlo).

## Dónde moría, medido

Los cuatro cierres del «antes» (`datos/antes-frio2/cierres_ips.txt`) tienen el hilo principal en
`WidgetDataCache.flushPendingUpdate()` → `updateCacheNow` → `buildSnapshot` → `buildPeriodSummary` (y
`Account.sumsInBalance`), llamado desde `YalaApp.handleScenePhase` al pasar a segundo plano. La secuencia, en la consola
(`datos/antes-frio2/consola.*.extracto.txt`): el cálculo del Panel del arranque empieza a 1,5 s y ocupa el hilo hasta los
~11 s; la salida a los 3 s no se atiende hasta que termina; entonces la foto de los widgets se hace de una vez, y entre
las dos pasan los 10 s que iOS da para la foto de la escena. Es la misma familia que los dos cierres del informe de
origen (Spotlight y `performCalculation`), con un tercer culpable que el informe no había visto: la foto de los widgets.

## Qué cambió

- **El cálculo del Panel va por etapas** (tendencia · presupuestos y pagos · salud · gastos por cuenta · hero), con una
  pausa de 1 ms entre una y otra en la que mira si se canceló, si el freno está puesto, si la app sigue en primer plano y
  si el almacén es el mismo. Al irse, se corta en la etapa siguiente y lo cortado queda apuntado para la vuelta.
- **La foto de los widgets al irse** se termina por etapas con el permiso de segundo plano de iOS
  (`beginBackgroundTask`), no de una vez. Si iOS agota el permiso, la foto queda pedida.
- **Spotlight** lee por tramos de 1.000 en un contexto propio por tramo, cede el hilo entre tramos, calcula entradas y
  plan fuera del hilo principal y se corta al pasar a segundo plano (`CancellationError`, olvida su firma: la vuelta
  reconcilia). En la consola del «después»: «segundo plano — se corta la reconciliación en vuelo» en las 5 vueltas.
- **Tirar para actualizar** solo recarga si cambió la firma del Panel.

## Lo que no se pudo, y por qué

- **Spotlight entero fuera del hilo principal**: los `@Model` son del main actor (`SWIFT_DEFAULT_ACTOR_ISOLATION =
  MainActor`); leerlos en otro hilo exige quitar ese aislamiento a los modelos, fuera de este lote. Lo que se movió fuera
  es lo que no toca modelos.
- **Producción**: Sentry solo ve cierres del vigilante con la app delante (`YALA-IOS-B`, 18 eventos, 2 en producción —
  2.3 (1) y 2.2 (9)—, todos `in_foreground = true`, de memoria) y ninguno `0x8BADF00D` en segundo plano; TestFlight tiene
  0 informes de cierre enviados (`asc testflight crashes list`); App Store Connect no tiene firmas de diagnóstico para
  las builds 4-11 de 2.3 («no resource»). Un cierre en segundo plano en producción no deja rastro en esas tres
  herramientas: solo en los `.ips` del propio teléfono.

## Archivos

- `datos/<pasada>/eventos.csv` (hora de cada salida y vuelta) y `consola.*.extracto.txt` (las líneas que cuentan:
  cálculos del Panel, `PERF`, tirar para actualizar, Spotlight, cierres).
- `datos/antes-frio2/cierres_ips.txt`: código y pila de los cuatro cierres.
- `scripts/frio.sh` (arranque en frío y salida rápida), `scripts/ciclos3.sh` (ciclos en caliente con tirar para
  actualizar y salida a los 2-5 s), `scripts/frio_resumen.py`. Los argumentos de Yala van detrás de `--`
  (`docs/aprendizajes-tecnicos.md`).
- Las consolas completas y los `.ips` quedan en la Max: `~/Claude/entregas/2026-11-26-eficiencia-3-no-morir-en-segundo-plano/`.
