---
id: statistics-first-entry-takes-a-second-to-render
status: done
priority: low
area: "performance, statistics"
created: 2026-10-30
updated: 2026-11-11
card: tablero-entrar-en-estadisticas-tarda-1-s-casi-to-7zc7
source: "encargo eficiencia-carga-por-vista (S27e), Time Profiler en el simulador"
---

# Entrar en Estadísticas tarda un segundo, casi todo en pintar

## Qué pasa

Medido el 2026-10-30 con `LoadTimesUITests` (corpus `rendimiento`, 2.337 movimientos, iPhone 17 Pro, iOS 27.0, build
Debug): **~1,02 s** desde elegir la pestaña hasta el resumen con datos (mediana de 5). Es la pantalla más lenta tras el
arranque.

El perfil (Time Profiler, ~1 s de hilo principal) no tiene un punto caliente único: ~55 % es el grafo de vistas de
SwiftUI (AttributeGraph), ~16 % Charts, ~25 % lecturas de propiedades de SwiftData repartidas entre los calculadores
(`FinancialScoreCalculator.calculateRhythm`, `TransactionClassificationLogic.isIncome`, `CashFlowCalculator`), y el
fetch completo de movimientos ~50 ms. Registros y Estadísticas tienen cada uno su `DetailContainerViewModel` y cada uno
trae el histórico entero.

## Por qué no se arregló en el encargo

No hay un arreglo pequeño: bajar esto pide compartir los datos entre pantallas, precalcular fuera del hilo principal o
aligerar la jerarquía de vistas del resumen. Se quitó lo barato (el rango de fechas que se ordenaba en cada repintado y
el segundo cálculo por observar `allTransactions`).

## Hecho cuando

Medido en un iPhone (Release) antes de decidir: si en el dispositivo baja de ~300 ms, cerrar; si no, elegir una de las
tres vías con su medida.

## Medido de nuevo (2026-11-05, lote P3 de 2.3)

`LoadTimesUITests`, mismo corpus `rendimiento` (2.337 movimientos), iPhone 17 Pro simulado, iOS 27.2, Debug: **917 ms**
de mediana en 5 entradas (909 · 915 · 917 · 921 · 945). Antes, 1.020. En Release la app no escribe esta marca y en la
Max no hay iPhone, así que la medida que pide el criterio sigue pendiente.

## Guion de QA para Jürgen (iPhone, TestFlight)

1. Con la app abierta en el Panel y tus datos de siempre, toca la pestaña **Estadísticas**.
2. Fíjate en cuánto tarda en aparecer el resumen con cifras. Vuelve al Panel.
3. Repite dos veces más (tres en total).
4. Responde: **¿se nota la espera? (sí / no)** y, si sí, cuánto más o menos (medio segundo, un segundo…).

Si no se nota, se cierra. Si se nota, se elige una de las tres vías en una sesión aparte.

## Medido en el iPhone y cerrado (2026-11-11, lote 2.3 «Estadísticas con diez años»)

La medida que pedía el criterio ya está, y la vía la eligió Jürgen el 9-nov (decisión 28 de la revisión 2.3, opción
G1 + G2 + G3). iPhone 14, iOS 27.2, Release-Dev optimizado con la semilla «pesado» (11.633 registros), Instruments Time
Profiler, «Todo el tiempo»:

- **Antes**: la primera entrada colgaba el hilo principal 7,5 s en el `onAppear` (Resumen 4,1 s, Tendencias 1,2 s,
  Registros 0,7 s, carga 0,4 s) y 150 ms después corría otra pasada completa de 2,4 s; la segunda entrada, 1,9 s + 2,0 s.
- **Después**: la pestaña cambia en el acto con la barra de chips y un esqueleto; la primera pasada corre una sola vez,
  en tramos (6,9 s en cuatro cuelgues de 0,7 a 4 s, con el esqueleto a la vista), y la segunda entrada no recalcula
  (0,75 s, todo pintar).

No hay un punto caliente único: es acceso a SwiftData por movimiento repartido entre calculadores (`isIncome`,
`InsightsCalculator`, `FinancialScoreCalculator.calculateRhythm`). Bajar los 6,9 s pide sacar el cálculo del hilo
principal (copiar los datos a valores), que queda fuera de la decisión 28. Con datos normales (2.337 movimientos) la
espera ya era de ~1 s en el simulador en Debug, y ahora además no bloquea el toque.
