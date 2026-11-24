---
toca: Yala/App/Views/Statistics/InsightsTabView.swift, Yala/App/Views/Statistics/StatisticsView.swift, Yala/App/Views/Statistics/RecordsTabView.swift, Yala/App/ViewModels/InsightsViewModel.swift, Yala/App/ViewModels/StatisticsViewModel.swift, Yala/App/Logic/Calculators/InsightsCalculator.swift, Yala/App/Logic/Calculators/AntExpensesCalculator.swift, Yala/App/Logic/AntExpensesAILogic.swift, Yala/Utils/L10n+InsightsResumenOpcionB.swift, Yala/Resources/es-419.lproj/InsightsResumenOpcionB.strings, Yala/Resources/es.lproj/InsightsResumenOpcionB.strings, Yala/Resources/es-AR.lproj/InsightsResumenOpcionB.strings, Yala/Resources/es-ES.lproj/InsightsResumenOpcionB.strings, Yala/Resources/en.lproj/InsightsResumenOpcionB.strings, Yala/Resources/en-GB.lproj/InsightsResumenOpcionB.strings, Yala/Resources/pt-BR.lproj/InsightsResumenOpcionB.strings, Yala/Resources/pt-PT.lproj/InsightsResumenOpcionB.strings, Yala/Resources/pt.lproj/InsightsResumenOpcionB.strings, Yala/Resources/fr.lproj/InsightsResumenOpcionB.strings, Yala/Resources/de.lproj/InsightsResumenOpcionB.strings, Yala/Resources/it.lproj/InsightsResumenOpcionB.strings, Yala/Resources/ja.lproj/InsightsResumenOpcionB.strings, Yala/Resources/nl.lproj/InsightsResumenOpcionB.strings, Yala/Resources/pl.lproj/InsightsResumenOpcionB.strings, Yala/Resources/zh-Hans.lproj/InsightsResumenOpcionB.strings, YalaTests/EstadisticasResumenOpcionB/, tickets/backlog/2026-11-23-estadisticas-resumen-opcion-b-decidir.md, tickets/done/2026-11-23-estadisticas-resumen-opcion-b-decidir.md
esfuerzo: high
---
# Implementar rediseño de Estadísticas → Resumen (opción B · Decidir)

## Contexto
Jürgen aprobó el 23-nov-2026 la **opción B · Decidir (recomendada)** de la propuesta visual entregada en PR #1145 (`docs/propuestas/estadisticas-resumen-2-3/index.html` y `docs/propuestas/estadisticas-resumen-2-3/README.md`, ticket `tickets/done/2026-11-23-estadisticas-resumen-propuesta-rediseno.md`).

Lee `docs/propuestas/estadisticas-resumen-2-3/index.html` y `README.md` al inicio para tomar la especificación visual, jerarquía, copy y cálculos nuevos definidos para la opción B.

## Qué se pide
1. Rehacer **Estadísticas → Resumen** (`InsightsTabView` y su ViewModel/calculadores) siguiendo la **opción B · Decidir**:
   - **Franja de salud financiera compacta** que muestre el puntaje y destaque el factor que más baja la nota (en lugar de ocupar tanto alto para cuatro números).
   - **Bloque «Para decidir hoy»**: hasta tres acciones priorizadas con navegación real a su destino correspondiente (Presupuestos, Pagos planificados o Tendencias), con criterio claro de orden y silencio cuando no haya acciones relevantes.
   - **Gastos hormiga como bloque protagonista**, ordenado, incorporando el cálculo de ritmo del mes (`≈ al mes` también en períodos de hasta 31 días cuando aplique) y la capa de **Yala IA** integrada en su propia franja (respetando estado gratis/Pro y ajustes de Smart Insights).
   - **Cálculo de lo que queda por día de un presupuesto** donde lo use la acción o resumen, y **filtro de Registros por comercio** para que tocar un comercio de gastos hormiga lleve a sus registros filtrados.
   - **Fila «Ir a»** con accesos directos a Distribución, Tendencias, Registros y Presupuestos (sin «Comparativa», que vive en Informes).
   - **Retirar** las cajas de «Categoría principal», «Subcategoría principal» y la caja ancha de «Promedio diario».
2. **Textos e idiomas**:
   - Poner los textos nuevos en su tabla dedicada (`Yala/Utils/L10n+InsightsResumenOpcionB.swift` y `InsightsResumenOpcionB.strings` en los 16 `.lproj`, sin tocar `Localizable.strings` salvo que sea imprescindible).
   - Español neutro latinoamericano en `es-419`, sin español de España.
3. **Verificación visual y pruebas**:
   - Agregar pruebas unitarias en `YalaTests/EstadisticasResumenOpcionB/` cubriendo: ritmo mensual de gastos hormiga, monto restante por día de presupuesto, orden y silencio de «Para decidir hoy», factor que más baja la nota de salud, y filtro de Registros por comercio.
   - Antes de usar simulador, verificar si el **iPhone 14 conectado por DeviceMCP** está libre y usarlo si conviene; nunca darlo por ocupado sin comprobarlo. Si la sesión corre en la Max, tienes permiso explícito para usar un **segundo simulador** (tope 2 en Max; tope 1 en Mini).
   - En la Mini seguir el pipeline serial: limpiar sims muertos y DerivedData propio/cachés de XcodeBuildMCP de worktrees retirados (sin preguntar) → build con `xcodebuild -jobs 2` sin simulador booteado → boot 1 sim → tests y capturas → apagar/limpiar el sim. Al cerrar, borrar DerivedData propio y cachés de XcodeBuildMCP retiradas.
   - Dejar capturas de antes y después en `capturas/` en modo claro y modo oscuro, verificando que no haya recortes ni desbordes en iPhone.
   - Documentar el ticket `tickets/done/2026-11-23-estadisticas-resumen-opcion-b-decidir.md` y actualizar `docs/TICKETS.md` si corresponde.

## Qué NO hay que tocar
- No cambiar el comportamiento de Informes / Comparativa ni otras pestañas fuera de los accesos y el filtro de Registros por comercio necesarios para Resumen.
- No modificar lógica de sincronización CloudKit ni gateway/MCP ni `marketing/`.
- Commits y PR sin firma de IA (el hook la rechaza).

## Cómo se sabe que está bien
- Estadísticas → Resumen implementa completa la opción B · Decidir de `docs/propuestas/estadisticas-resumen-2-3/index.html`, se ve limpia en claro y oscuro, y cada acción/enlace navega correctamente.
- Las pruebas unitarias nuevas en `YalaTests/EstadisticasResumenOpcionB/` y las existentes de `Insights` / `AntExpenses` pasan en verde.
- Hay capturas de antes y después en `capturas/` (claro y oscuro).
- El PR contra `2.3` pasa el CI real y queda mergeado en `2.3` antes de `/cerrar-total` (si a los ~45 min el CI sigue rojo por algo ajeno al PR, cerrar y anotarlo).

## Paso 0 (decidido sin consultar, sesión nocturna)

- Ficheros: InsightsTabView (rehecha por bloques), vistas nuevas en `Views/Statistics/ResumenOpcionB/`, lógica pura en
  `Logic/ResumenOpcionB/`, InsightsCalculator (días que quedan del presupuesto, fin de lo pendiente, ritmo hormiga),
  AntExpensesCalculator (ritmo), AntExpensesAILogic (claves de cada unión), RecordsViewModel + RecordsTabView (filtro por
  comercio), DetailContainerView (cierre que abre Registros filtrado), L10n + tabla `InsightsResumenOpcionB` en 16 idiomas,
  tests nuevos y ajuste de los tests de cableado que leían las secciones retiradas.
- «Para decidir hoy» solo con un período que incluye hoy. Orden: presupuesto pasado → presupuesto ≥ 90 % → lo que falta
  pagar → presupuesto 80–90 % → gasto diario ≥ 5 % más. Máximo 3. Sin ninguna, el bloque no sale.
- Lo que queda por día: `BudgetRemainingLogic.perDay` con los días de `BudgetPeriodInterval` (hoy cuenta), como Planificación.
- Ritmo hormiga: «Este mes» en curso (≥ 3 días y antes del último) → «a este ritmo cierras el mes en X»; períodos de menos
  de 28 días con ≥ 3 días → «unos X al mes»; más de 31 días → lo mismo con el cálculo de siempre. Sin «≈» (decisión 31:
  «≈» solo marca conversión aproximada).
- Filtro por comercio: efímero en el chip Registros de Estadísticas (como el modo duplicados), con cápsula «Solo X» y ✕.
- Se quedan como hoy: resumen con IA / teaser Pro, el selector Detalle | Observaciones y Observaciones.
- «Lo que te falta pagar», «Tus presupuestos» y «Distribución del gasto por necesidad» salen del Resumen: los dos
  primeros vuelven como acción; la necesidad queda en la línea «Lo que más pesa» con su barra.
