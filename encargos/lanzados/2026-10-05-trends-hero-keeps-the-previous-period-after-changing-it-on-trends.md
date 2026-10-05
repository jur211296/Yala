# Que el hero de Tendencias (cifra grande, ingresos, gastos y la frase) siga al período cuando se cambia desde Tendencias

## Contexto
Ticket `tickets/backlog/trends-hero-keeps-the-previous-period-after-changing-it-on-trends.md` (medium, statistics). Medido el 2026-10-03 en simulador con seed `realista`: en Estadísticas › Tendencias con «Todo el tiempo», al elegir «Mes pasado» las gráficas pasan a septiembre pero el hero sigue con las cifras de «Todo el tiempo» y «Aumento +0 %». Si el cambio se hace en Resumen y luego se va a Tendencias, el hero sale bien. El ticket lee en el código que el hero lee `insightsViewModel.insightData` y que `DetailContainerView.performCalculation` solo recalcula `calculateInsightsData()` en `.insights` / `.categories`; es una lectura sin traza, verifícala antes de arreglar.
El Trend Insight Card ya tuvo el mismo problema y se resolvió en PR #345 con un conteo propio (`StatisticsViewModel.periodTransactionCount`); el hero quedó fuera de alcance.
Es la cola autónoma de bugs de Yala sobre `2.1`. El PR anterior (#360, grupos/drain) está en cola de auto-merge y no toca estadísticas.

## Que se pide
- Reproducir el fallo (test que falle primero) y arreglarlo para que el hero de Tendencias muestre siempre el período elegido, venga el cambio de donde venga (Tendencias, Resumen, Categorías, relanzar).
- Jürgen quiere siempre la opción más robusta y la mejor práctica aunque tarde más, no la más chica. Elige entre recalcular `insightData` también en Tendencias o derivar el hero de lo que ya calcula `StatisticsViewModel` (o una fuente única de verdad para el período) con ese criterio, mide el coste si recalcular pesa, y deja el porqué en el PR.
- Revisar si otras cifras de Estadísticas tienen el mismo patrón (dependen de la pestaña desde la que se cambió el período); si hay más, arreglarlas si son el mismo fallo o dejar ticket si son otra cosa.
- Tests unitarios del arreglo; UITest solo si el seam ya existe y es barato.
- Capturas antes y después (Tendencias con «Mes pasado» elegido desde Tendencias) en `capturas/antes.png` y `capturas/despues.png` del worktree, con las rutas en el resumen de cierre.
- Ticket a `tickets/qa/` con guion corto de device-QA en iPhone.

## Que NO hay que tocar
- El diseño del hero ni de Tendencias: esto es un bug de datos, no un rediseño. Si aparece una duda de diseño visible, deja propuestas y espera a Jürgen.
- Grupos, drain, modo nube y el trabajo del PR #360.
- marketing/.

## Como se sabe que esta bien
- Cambiar el período desde Tendencias actualiza hero y gráficas a la vez, con cifras iguales a las que salen cambiándolo desde Resumen.
- Test nuevo rojo antes y verde después; gate verde.
- PR a `2.1` con antes/después y el porqué de la opción elegida; auto-merge si el gate pasa.

## Orden en la Mini (obligatorio)
Pipeline serial: limpiar → build con `xcodebuild -jobs 2` sin simulador → arrancar UN simulador → tests y capturas → apagar y borrar ese simulador. No solapar compilación, simulador y UITests.
Gate después del CI del PR anterior: la sesión arranca ya sobre `origin/2.1`. Justo antes del gate, mira si #360 sigue en CI. Si sigue, espera a que entre y rebasa una sola vez, con el simulador apagado. Si `2.1` no se movió, sigue de frente. Si ese CI falla, no esperes: rebasa con lo que haya y sigue. El build y el simulador van después de ese rebase, una sola vez.
DerivedData y cachés: al lanzar y al cerrar, borra sin preguntar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen. No toques los de una sesión viva. Si el borrado falla, dilo en el cierre.
Cierre limpio: apagar y borrar el simulador usado, y si el PR ya entró, quitar worktree, su DerivedData y cachés.

/cerrar-total

## Paso 0 — decisiones (resueltas en autónomo, bypass)

1. **Causa verificada:** `DetailContainerView.performCalculation` calculaba `insightData` solo con Resumen o
   Distribución a la vista (puerta desde `3439fe380`). Reproducido en simulador con `realista`: hero en S/ 56.010,80
   con «Mes pasado» elegido en Tendencias (Resumen da S/ 3.292,00). Segundo síntoma del mismo fallo: entrar por
   «Ver más en Tendencias» desde el Panel deja el hero vacío.
2. **Fuente del hero: la de Resumen (`InsightsCalculator` → `PeriodSummary`).** Derivarlo de `StatisticsViewModel`
   obliga a reescribir variaciones alineadas, etiquetas y marcas «≈» en un segundo sitio. Misma fuente ⇒ mismas cifras
   que Resumen por construcción.
3. **Se quita la puerta por pestaña** en vez de añadir Tendencias a la lista: la lista a mano es lo que se rompió. La
   firma de entradas de `InsightsViewModel` ya evita repetir trabajo. Recalcular solo el `PeriodSummary` se descarta:
   dejaría un `insightData` a medias.
4. **Coste:** se mide en simulador con `realista` antes de cerrar.
5. **Test:** la pasada sale a `StatisticsRecalculation` (testeable sin vista). Rojo con la puerta extraída tal cual,
   verde sin ella. UITest barato: abrir Tendencias desde el Panel y exigir el rótulo del hero.
6. `StatisticsViewModel.periodTransactionCount` se queda; solo se corrige su comentario.

Detalle en el ticket `trends-hero-keeps-the-previous-period-after-changing-it-on-trends`.
