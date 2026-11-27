# Lote 4 · El recálculo del Panel deja de bloquear — antes y después en el iPhone 14

Medido el 26-nov-2026 entre las 18:10 y las 18:40 (Lima) en el iPhone 14 de Jürgen («iPhone de JURGEN», iOS 27.2.1),
por cable a la Max, desbloqueado y cargando. La misma copia de perfilado que el informe de origen (`Release-Dev`
optimizada con `DEBUG` encendido solo en la copia, `scripts/perfil.sh`) y el mismo almacén `YalaModel-UITest` de
16.004 movimientos y 24 presupuestos, abierta con `-uitest -uitest-skip-onboarding` (sin reset).

- **Antes**: la rama del lote 3 (`encargo/2026-11-26-eficiencia-3-no-morir-en-segundo-plano`, de la que depende este
  lote) con SOLO las marcas nuevas (`MarcasRecalculoPanel`), sin ningún otro cambio.
- **Después**: la misma base con los cambios de este lote (en los extractos, «despues2»: la segunda iteración, la que va
  en el PR).

Dos instrumentos:

1. **Consola** (`scripts/medir.sh`): 3 arranques en frío, 30 s cada uno. Cada cálculo del Panel imprime
   `PERF panel-calculo` con el total, lo que costó cada etapa y, en el después, el tramo más largo sin ceder el hilo.
   En cada arranque hay dos cálculos: el del arranque y el que pide la subida de `dataVersion` unos segundos después.
2. **Instruments** (`scripts/hangs.sh`): Time Profiler 35 s desde el lanzamiento, tabla `potential-hangs` (bloqueos del
   hilo principal de más de 250 ms), y cada bloqueo atribuido a quien tenía el hilo por sus muestras
   (`scripts/dueno.py`).

## Resultado

| | Antes | Después |
|---|---|---|
| **Bloqueos del Panel en el arranque (Instruments)** | 6 · **16,7 s** en total · el más largo **3.657 ms** | 10 · **5,3 s** en total · el más largo **945 ms** |
| Bloqueo más largo dentro del cálculo (consola, 2.º cálculo) | ~2,6 s (la nota de salud, de una vez) | **0,88-0,95 s** (la proyección del saldo) |
| Recálculo completo (consola, 2.º cálculo, 3 arranques) | 7,4 / 7,8 / 8,0 s | **4,5 / 4,5 / 6,3 s** |
| Presupuestos (etapa) | 1,6-1,7 s | **0,39-0,41 s** |
| Nota de salud (etapa) | 2,5-2,7 s, un bloque | **0,76-0,78 s**, en 5 partes que ceden |
| Gastos por cuenta (etapa) | 0,17-0,19 s | **4 ms** |
| Panel listo en el arranque en frío (`PERF arranque`) | 11,0 / 11,7 / 11,9 s | 14,3 / 16,3 / 16,5 s |

Todos los bloqueos del arranque (no solo los del Panel): de 19 que sumaban 24,3 s, con el más largo de 3.657 ms, a 22
que suman 12,2 s, con el más largo de 1.421 ms. Los tres más largos del después son de la foto de los widgets
(`WidgetDataCache.rebuildPendingInStages`, lote 3), no del Panel.

### Contra la mejora esperada del encargo

- «Pasos de < 50 ms (sin congelar)»: **no se cumple del todo**. Casi todo el cálculo cede ahora cada ~25 ms, pero quedan
  piezas compartidas que no se pueden partir desde el Panel. La más larga es **la proyección del saldo, ~0,9 s**: es
  `ProjectedFlowBuilder.build` → `othersRemaining`, y el 80 % de sus muestras está en `FlujoMotorMesEntrada.movimientos`,
  que lee cada movimiento del historial para el motor del flujo de caja. Le siguen el saldo vivo de la curva, la curva y
  el saldo del día 1, de ~0,2-0,25 s cada uno.
- «Su total baja»: **sí**, de ~7,7 s a ~4,5 s por recálculo en caliente.
- «Ningún bloqueo > 250 ms al arrancar y al tirar para actualizar»: **no**. En el Panel quedan 10, todos por debajo de
  1 s (antes, 6 de hasta 3,7 s). Tirar para actualizar ya no recalcula si nada cambió (lote 3), así que no hay nada que
  medir ahí; con datos nuevos cuesta lo mismo que el 2.º cálculo de la tabla.

### Lo que empeoró, y por qué

**El Panel termina de calcular 3-5 s más tarde en el arranque en frío** (`PERF arranque` de ~11,5 a ~15,7 s). No porque
cueste más, sino porque ahora cede el hilo cada ~25 ms y en esas cesiones avanza el resto del arranque, que antes
esperaba a que el Panel terminara: la foto de los widgets y Spotlight. El primer cálculo dura más en reloj (12,5-14,8 s)
y menos en hilo ocupado: casi toda la etapa del «contexto», 8 s en reloj, es otra cosa corriendo entre trozo y trozo.
Mientras tanto la app responde a los toques. El saldo grande sale con la etapa de la tendencia, como antes.

## Qué cambió

- **Un índice por fecha, armado una vez por recálculo** (`Logic/RecalculoPanel/IndiceFechasMovimientos.swift`, ~30 ms
  con 16 k). Presupuestos, cada ciclo de presupuesto de la nota de salud, sus alertas, «Lo que te queda», los ingresos de
  compromisos y los gastos por cuenta piden «los movimientos de este intervalo» en vez de recorrer los 16 mil. Devuelve
  los mismos movimientos y en el mismo orden que el filtro, así que las sumas salen idénticas al bit.
- **Cesión del hilo dentro de cada etapa** (`CesionDelHilo`): los cuatro recorridos del historial de la tendencia van por
  trozos de 1.024, y entre widget y widget, presupuesto y presupuesto, y parte y parte de la nota se cede si el tramo pasó
  de 25 ms. Si al volver el cálculo ya no sigue (la app se fue, cambió el almacén), se abandona sin publicar.
- **La nota de salud por partes** (`FinancialScoreCalculator.plan`): presupuesto, ritmo, compromisos, lo que te queda y
  alertas, los mismos pasos que `calculate`.
- **El ritmo de la nota sin ordenar los movimientos**: el hueco sale de los días con registro, cada día calculado una vez.
- **Un borrado a mitad del cálculo lo corta y recarga**: con más cesiones hay más ventanas en las que otra tarea puede
  borrar un movimiento que el cálculo tiene en la mano, y leerlo aborta en el iPhone. Un guardado sin borrados no corta.
- **Marcas**: `os_signpost` «Panel.performCalculation» y uno por etapa (subsystem `com.yala`, categoría
  `PanelRecalculo`), y en DEBUG la línea `PERF panel-calculo` por consola.

## Lo que quedó fuera

- **La proyección del saldo (~0,9 s)**: partirla es tocar `ProjectedFlowBuilder` y el motor del flujo de caja, que
  comparten el flujo de caja, Tendencias y el widget de Saldo. El siguiente paso razonable es que el Panel arme la entrada
  del motor (`FlujoMotorMesEntrada.movimientos`) una vez por recálculo y la reuse, o que el motor la reciba por tramos.
- **Llevar el cálculo fuera del hilo principal**: los `@Model` son del main actor; habría que pasar a valores todo lo que
  leen las calculadoras compartidas. Del punto 4 del encargo («leer date, amount, account y category una vez») solo se
  hizo la fecha, que era la lectura que se repetía.
- **La foto de los widgets** sigue dejando bloqueos de hasta 1,4 s en el arranque (lote 3, `WidgetDataCache`).
