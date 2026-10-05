---
id: trends-hero-keeps-the-previous-period-after-changing-it-on-trends
status: qa
priority: medium
area: statistics
created: 2026-10-03
updated: 2026-10-05
source: hallazgo de trends-insight-card-v2-bullets (simulador, 2026-10-03)
---

# El número grande de Tendencias se queda con el período anterior al cambiarlo desde Tendencias

## Qué pasa

En Estadísticas › Tendencias, si cambias el período desde esa misma pestaña, el hero (cifra grande,
ingresos, gastos y la frase de debajo) sigue mostrando el período de antes. Las gráficas sí cambian.

**Medido el 2026-10-03** en el simulador, seed `realista`: Estadísticas → Tendencias con «Todo el
tiempo» → elegir «Mes pasado». Las gráficas pasan a septiembre (Comparativa «+5,1 % vs Ago 26») y el
hero sigue en S/ 63.193 / 270.163 / 206.970 con «Aumento +0 %», que son las cifras de «Todo el
tiempo». Si el cambio se hace en Resumen y luego se va a Tendencias, el hero sale bien (S/ 3.292).

## Por qué (leído en el código, no medido con traza)

El hero de Tendencias lee `insightsViewModel.insightData`, y `DetailContainerView.performCalculation`
solo llama a `calculateInsightsData()` con `selectedTab == .insights || .categories`
(`DetailContainerView.swift`, `performCalculation` y `calculateInsightsData`). En Tendencias el
cambio de período recalcula la tendencia pero no `insightData`.

El Trend Insight Card tenía el mismo problema en su gate de «≥ 5 movimientos»; en
`trends-insight-card-v2-bullets` el gate pasó a un conteo propio (`StatisticsViewModel.periodTransactionCount`).
El hero no se tocó: fuera de alcance.

## Qué hay que decidir

Recalcular `insightData` también en Tendencias (coste: el cálculo de Resumen y la Salud Financiera
en cada cambio) o derivar el hero de Tendencias de lo que ya calcula `StatisticsViewModel`.

## Paso 0 (2026-10-05, sesión autónoma)

**Causa, verificada en el código del árbol** (`DetailContainerView.performCalculation`): el cálculo de
`insightData` lleva una puerta por pestaña (`selectedTab == .insights || .categories`) desde que se creó Resumen
(`3439fe380`, marzo). Era una optimización: solo lo calculaba quien lo pintaba. El hero de Tendencias empezó a leer
`insightData.periodSummary` después y nadie añadió Tendencias a la lista. No es solo el cambio de período: cualquier
entrada que cambie estando en Tendencias (filtro, dato nuevo, toggle de grupos) deja el hero viejo, y abrir
Estadísticas directamente en Tendencias lo deja vacío.

**Decisiones:**

1. **Fuente del hero: la de Resumen (`InsightsCalculator` → `PeriodSummary`), no una derivación de
   `StatisticsViewModel`.** El hero pinta neto, ingresos, gastos, las tres marcas «≈» y las variaciones contra el
   período anterior alineado (MTD, `DateAlignmentHelper`). Derivarlo de `StatisticsViewModel` obliga a reescribir esa
   alineación y esas variaciones en un segundo sitio, y dos formas de calcular lo mismo divergen. El criterio del
   encargo («cifras iguales a las de Resumen») sale por construcción solo si la fuente es la misma.
2. **Se quita la puerta por pestaña, no se añade Tendencias a la lista.** Una lista de «quién lee `insightData`» a
   mano es exactamente lo que se rompió. Sin puerta, `insightData` sigue a sus entradas en cualquier pestaña, y la
   firma de entradas de `InsightsViewModel` ya evita recalcular si nada cambió. Recalcular solo el `PeriodSummary` y
   dejar lo demás con puerta se descarta: dejaría un `insightData` a medias (resumen nuevo, el resto viejo).
3. **Coste:** se mide `InsightsCalculator.calculate` + Salud Financiera con la semilla `realista`. Si pesa, se
   reconsidera antes de seguir.
4. **Test:** la orquestación sale de la vista a un tipo testeable (`StatisticsRecalculation`), con un test que
   cambia el período y exige que el resumen del período lo siga. Rojo primero con la puerta extraída tal cual.
5. **`StatisticsViewModel.periodTransactionCount`** (el conteo propio del Trend Insight Card, PR #345) se queda: es
   correcto y quitarlo es otro cambio. Solo se corrige su comentario, que dejará de ser cierto.

**Asumido:** el resto de cifras de Estadísticas se revisan con el mismo criterio (¿quién las calcula y con qué
puerta?); si sale otra cosa, ticket aparte.

## Hecho (2026-10-05)

- La pasada de cálculo de Estadísticas sale de la vista a `StatisticsRecalculation` y ya no mira qué pestaña está a
  la vista: `insightData` sigue al período y a los filtros en las cuatro.
- **Medido en simulador (`realista`, iPhone 17 Pro, iOS 27.0).** Antes: «Mes pasado» elegido en Tendencias dejaba el
  hero en S/ 56.010,80 (el de «Todo el tiempo»); entrar por «Ver más en Tendencias» desde el Panel lo dejaba vacío.
  Después: S/ 3.292,00 · 11.719 · 8.427 · +37,9 % / −5,3 %, lo mismo que Resumen; y con «Este año», S/ 29.720,30 en
  las dos pestañas. Desde el Panel el hero sale con su rótulo y su cifra.
- **Coste medido** (build Debug, 2.313 movimientos): resumen + Salud Financiera, 51–63 ms por cambio (131 ms la
  primera vez, con el fetch de pagos), dentro de una pasada de 125–200 ms. Resumen ya lo pagaba; ahora también
  Tendencias, que lo pinta, y Registros, que no. Si algún día pesa en Registros, la salida es calcular bajo demanda,
  no volver a una lista de pestañas.
- Tests: `YalaTests/StatisticsRecalculationTests` (3; rojos con la puerta extraída tal cual) y
  `StatisticsHeroLikePanelUITests#test_trendsOpenedFromThePanelShowsItsHero`.
- Revisado el resto de Estadísticas: el único estado que sobrevive a cambiar de pestaña es `insightData` (lo demás se
  recalcula al montar cada pestaña o en cada pasada), así que no hay otro caso del mismo fallo.

## Guion de device-QA (iPhone)

1. Abre Yala con tus datos reales. Ve a **Estadísticas › Resumen** y elige **Todo el tiempo** en la píldora de
   período. Apunta la cifra grande.
2. Pasa a **Tendencias** y, en la píldora de período de esa pestaña, elige **Mes pasado**.
3. **Esperado:** la cifra grande, ingresos, gastos y la frase de debajo cambian a la vez que las gráficas. No se
   quedan con la cifra del paso 1.
4. Vuelve a **Resumen**. **Esperado:** las mismas tres cifras que viste en Tendencias.
5. Ve al **Panel**, toca **Ver más en Tendencias** (junto al título «Tendencias»). **Esperado:** el hero de
   Tendencias sale con «Neto del período» y su cifra, no vacío.
6. En Tendencias, toca el filtro (icono de líneas arriba a la derecha), elige una sola cuenta y vuelve.
   **Esperado:** el hero cambia con el filtro.

Si en el paso 3 o 6 el hero se queda con lo de antes, el arreglo no llegó a ese build.
