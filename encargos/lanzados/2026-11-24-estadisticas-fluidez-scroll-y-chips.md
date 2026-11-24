Yala
# Estadísticas: corregir lentitud y trabas al hacer scroll y al cambiar entre Resumen, Tendencias y Distribución
---
toca: Yala/App/Views/Statistics/DetailContainerView.swift,Yala/App/Views/Statistics/StatisticsView.swift,Yala/App/Views/Statistics/StatisticsFocusScroll.swift,Yala/App/Views/Statistics/InsightsTabView.swift,Yala/App/Views/Statistics/TrendsTabView.swift,Yala/App/Views/Statistics/CategoriesTabView.swift,Yala/App/Views/Statistics/StatsHeroView.swift,Yala/App/Views/Statistics/Components/,Yala/App/ViewModels/DetailContainerViewModel.swift,Yala/App/ViewModels/StatisticsViewModel.swift,Yala/App/ViewModels/StatisticsRecalculation.swift,Yala/App/ViewModels/InsightsViewModel.swift,Yala/App/ViewModels/TrendsAIViewModel.swift,YalaTests/EstadisticasFluidez/,tickets/backlog/2026-11-23-estadisticas-fluidez-scroll-y-chips.md,tickets/done/2026-11-23-estadisticas-fluidez-scroll-y-chips.md
esfuerzo: high
cierre: cierra-sola
---

Pedido de Jürgen (23-nov, pruebas de Yala 2.3 en iPhone real).

## Problema reportado
En Estadísticas, al hacer bastante scroll en **Resumen**, **Tendencias** y **Distribución**, o al ir avanzando y cambiando entre esos chips, la app se siente lenta: se atora y no responde de inmediato.

## Qué se pide
1. **Diagnosticar las causas reales** antes de tocar código (medir y revisar qué corre en el hilo principal durante scroll largo y al alternar entre los chips Resumen, Tendencias y Distribución). Revisar en particular:
   - Lectura de offset de scroll (`onScrollGeometryChange`, `GeometryReader`, `PreferenceKey`, `StatisticsFocusScroll`) que dispare cambios de estado por frame y re-evalúe vistas o gráficos completos mientras se scrollea.
   - Recálculos síncronos o redundantes en `DetailContainerViewModel`, `StatisticsViewModel`, `StatisticsRecalculation`, `InsightsViewModel` o `TrendsAIViewModel` al cambiar de chip o al reaparecer una subpestaña (sin caché por período/filtros).
   - Gráficos pesados (Swift Charts, Sankey, barras, `Canvas`), `VStack` en lugar de `LazyVStack`, o capas de material/glass/sombras re-renderizando en cada frame.
   - Animaciones amplias (`withAnimation`) al cambiar de chip que obliguen a interpolar árboles grandes en el hilo principal.
2. **Corregir los cuellos de botella encontrados** para que:
   - El scroll largo en Resumen, Tendencias y Distribución sea fluido y sin trabas.
   - El cambio entre los chips Resumen, Tendencias y Distribución sea inmediato, sin congelamientos ni recálculos innecesarios cuando los filtros y el período no cambiaron.
   - No se rompa ningún filtro, sincronización de período, animación intencional ni funcionalidad visual (no cambies el diseño de las pantallas; concéntrate en fluidez y arquitectura de render/cálculo).
3. Agregar pruebas unitarias en `YalaTests/EstadisticasFluidez/` que verifiquen que cambiar de chip sin cambiar filtros/período no dispara recálculos innecesarios (y cualquier invariante de caché/invalidación que introduzcas).

## Pruebas, entorno y cierre
- Base: `origin/2.3`.
- **Importante para medir fluidez:** comprueba primero si el iPhone 14 conectado a la Mini vía DeviceMCP está libre (no lo des por ocupado sin comprobarlo) para validar en dispositivo real además de simulador. Si corres en la Max y necesitas simulador, tienes permiso explícito para usar un segundo simulador (tope 2 en la Max; en la Mini tope 1).
- En la Mini, respeta el pipeline serial y limpia DerivedData propio y cachés de XcodeBuildMCP de worktrees ya retirados sin preguntar.
- En el cierre, reporta qué causas reales encontraste, qué cambiaste y qué mejora observaste al scrollear y cambiar entre los chips.
- Abre un PR sin firma de IA contra `2.3` con auto-merge activado y espera a que el PR entre de verdad en `2.3` antes de `/cerrar-total` (si tras ~45 min el CI sigue rojo por algo ajeno al PR, cierra y anótalo).

## Paso 0 — decisiones

> Resueltas en autónomo (bypass, modo nocturno): las recomendaciones se dan por buenas. Se discuten en el PR.

**Hechos medidos antes de decidir** (simulador iPhone 17 Pro de la Max, Debug-Dev, semilla `pesado` de diez años,
período «Todo el tiempo», `sample` del hilo principal): al alternar Resumen → Tendencias → Distribución ocho veces, el
hilo principal estuvo ocupado ~1,6 s (sin contar las consultas de accesibilidad del propio conductor). De eso, ~1,1 s
(70 %) eran recálculos de lo que ya estaba calculado: las tarjetas de Tendencias (~240 ms por entrada), el Sankey de
Distribución (~175 ms) y «Tu dinero hoy» de cada hero (~27 ms por montaje). La causa: `StagedTabPages` desmonta la
página que se va y la que vuelve nace sin su `@State`. El scroll largo en las tres páginas dejó el hilo principal
ocupado un 15-20 % del tiempo, sin cuerpos de Yala reevaluándose por fotograma (17 muestras en 4,9 s): en el simulador
el scroll no está atado al hilo principal. El iPhone 14 no estaba disponible (la Mini lo ve «unavailable»).

**D1 · ¿Mantener montadas las páginas visitadas o recordar sus cálculos?** → Recordar los cálculos.
Por qué: `StagedTabPages` desmonta a propósito la página vieja (el título grande vive en su scroll; con dos montadas la
nueva no lo recibe, medido en vídeo el 31-oct). Alternativa descartada: páginas vivas ocultas, que rompe el título.

**D2 · ¿Dónde vive lo recordado?** → En el `StatisticsViewModel` del contenedor (`@ObservationIgnored`) para Tendencias,
Distribución y el Sankey, y en un objeto por contenedor, por el entorno, para «Tu dinero hoy».
Por qué: sobreviven al desmontaje de la página y mueren con el contenedor. Alternativa descartada: un singleton de
proceso, porque `dataGeneration` es por contenedor y dos contenedores podrían compartir número con datos distintos.

**D3 · ¿Qué invalida lo recordado?** → Una firma con todo lo que la página observa para recalcular mientras está
montada, más el intervalo del período (cubre el cambio de día), la divisa y el interruptor de Grupos en Estadísticas.
Un test de cableado exige que cada `onChange` que recalcula tenga su campo en la firma.
Por qué: lo que la recalcula montada es lo que tiene que invalidarla desmontada. Alternativa descartada: reutilizar
`StatisticsCalculationStamp` del contenedor, que no ve el estado local de la página (agrupación por tarjeta).

**D4 · ¿Se toca el recálculo del contenedor al cambiar de chip?** → No. Ya solo calcula si cambió su firma
(`requestCalculationOnEntry`) y no apareció en las muestras.

**D5 · ¿Se toca el scroll?** → No con cambios a ciegas. En el simulador no hay trabajo de Yala por fotograma; lo que
trababa el primer scroll tras cambiar de chip era el recálculo de D1 cayendo justo después. Queda anotado para medir en
el iPhone 14 (device-QA).

**D6 · ¿Se conserva el estado local de cada página (carrusel, «Detalle/Gráficas», agrupación) al volver?** → No: sigue
volviendo como hoy. Solo se recuerdan las cifras. Por qué: el encargo pide no cambiar el diseño ni el comportamiento.
