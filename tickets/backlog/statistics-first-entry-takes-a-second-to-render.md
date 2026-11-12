---
id: statistics-first-entry-takes-a-second-to-render
status: backlog
priority: low
area: "performance, statistics"
created: 2026-10-30
updated: 2026-10-30
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
