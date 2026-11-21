Yala
# Flujo de caja y Comparativa fluidos, y chips de variación en Comparativa
---
toca: Yala/App/Views/Reports/CashFlow/,Yala/App/ViewModels/CashFlowPlanViewModel.swift,Yala/App/Logic/Calculators/CashFlowCalculator.swift,Yala/App/Logic/Calculators/CashFlowProjectionCalculator.swift,Yala/App/Logic/FlujoMotorMes/,Yala/App/Views/Reports/ReportComparisonViews.swift,Yala/App/Views/Reports/NetFlowSummaryView.swift,Yala/App/Views/Reports/PivotRowView.swift,Yala/App/Views/Statistics/PeriodComparisonChartView.swift,YalaTests/FlujoDeCajaFluidez/,tickets/backlog/2026-11-20-flujo-de-caja-fluidez.md,tickets/done/2026-11-20-flujo-de-caja-fluidez.md
esfuerzo: high
cierre: cierra-sola
---

Rama base: 2.3. Pedido de Jürgen (20-nov), con un video grabado en su iPhone que esta sesión no tiene; sus palabras: «En flujo de caja tenemos mucha lentitud y hay un "rebote" horrible en la parte superior. Necesitamos eficientar bastante esta página, genera lentitud, también al viajar desde ahí a otras páginas con Filtros aplicados.»

Jürgen agregó después: «El rebote raro que queremos corregir también pasa en Comparativa. Así que también revisar la eficiencia ahí.» Todo lo de abajo aplica igual a Comparativa (rebote arriba, lentitud y navegación con filtros). Si el rebote viene de un componente compartido por las dos pantallas (encabezado, selector de periodo, chips de filtros), arréglalo en ese componente una sola vez y verifica las dos.

Qué hay que lograr, un PR y un cierre:

1. **Rebote arriba.** Reproducir en el iPhone 14 (o simulador) el salto o rebote de la parte superior de Flujo de caja: al entrar, al cambiar de mes o periodo, al hacer scroll y al volver de otra pantalla. Encontrar la causa real (altura que cambia tras cargar, contenido que llega en dos tiempos, animación implícita, `safeAreaInset`, encabezado que se recalcula, etc.) y quitarla. La parte superior queda quieta: el contenido aparece ya en su lugar, sin saltos.
2. **Lentitud de la página.** Medir con Instruments (SwiftUI y Time Profiler) o con signposts el tiempo de entrada, el scroll y el cambio de mes, antes y después. Sacar del camino de dibujo los cálculos pesados (proyección, motor del mes, resúmenes): que se calculen una vez, fuera del `body`, y se reutilicen; evitar recomputar todo por cambios que no afectan. El resultado no puede cambiar ningún número.
3. **Viajar a otras páginas con filtros aplicados.** Medir y agilizar la ida desde Flujo de caja a la pantalla destino (detalle de mes, detalle de línea, registros filtrados, etc.) y la vuelta. Lo ideal es que el filtro viaje ya resuelto y que el destino no recalcule desde cero.
4. **Pruebas.** Tests en `YalaTests/FlujoDeCajaFluidez/` que fijen que los números no cambian (mismos resultados antes y después) y, donde aplique, que el cálculo no se repite. En el artifact final, tabla antes/después con los tiempos medidos y un video o capturas que muestren la parte superior quieta.

5. **Chips de variación en Comparativa.** Pedido de Jürgen: «En la vista comparativa aparece el monto del periodo actual y el del periodo anterior, pero no hay un chip de variación con un color para ver rápidamente cuáles subieron y cuáles bajaron.» Agregar en cada fila un chip con la variación (porcentaje, y monto si cabe) y color según si es bueno o malo: en gastos subir es malo y bajar es bueno; en ingresos, al revés. Reutilizar el chip de variación que ya existe en Estadísticas (mismo estilo, colores, flecha y textos) en vez de crear otro. Casos: sin periodo anterior o con anterior en cero (sin porcentaje infinito: mostrar «Nuevo» o equivalente ya usado), variación cero (chip neutro). Textos en su tabla de strings, en todos los idiomas. Tests de la lógica del chip en `YalaTests/FlujoDeCajaFluidez/`.

Si arreglar la navegación exige tocar archivos fuera del `toca:` (por ejemplo la pantalla destino), hazlo solo en lo mínimo y anótalo en «Decidido sin consultar» con el motivo.

## Cómo trabajar
- iPhone 14 (Jürgen, 19-nov): queda conectado a la Mini para cualquier sesión de cualquier máquina vía DeviceMCP. Antes de recurrir al simulador, verifica de verdad si está libre (que responda y que ninguna otra sesión lo esté usando en ese momento); no lo des por ocupado sin comprobarlo. Si lo usas, suéltalo al terminar.
- Textos nuevos en su propia tabla, nunca en Localizable.strings. Nunca un botón debajo de otro.
- En la Max puedes usar un segundo simulador además del de otra sesión, o el iPhone 14 por DeviceMCP; en la Mini, uno solo. No uses `-derivedDataPath /tmp/claude-*`.
- Nada en producción (ni CloudKit ni Supabase).
- Commit y PR sin firma de IA, contra 2.3. Deja el auto merge activado y no cierres hasta ver el PR dentro de 2.3. Si hay conflicto o el CI falla por tu PR, arréglalo tú. Si tras unos 45 minutos el CI sigue rojo por algo ajeno, cierra y anota el motivo.
- Lo menor y reversible se decide con la opción recomendada y se anota. Lo vital, según el modo fijado al arrancar: en semi (05:30–20:00) preguntas y esperas con la sesión viva; en nocturno (20:00–05:30) dejas un checkpoint recuperable y una card «Espera decisión» para Jürgen, sin cerrar como completo, sin mergear ni desplegar lo incompleto.
- Entregable del cierre: artifact visual de Claude (capturas antes y después y mediciones), nunca Markdown ni PDF.
- Cierre: `/cerrar-total`, con «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada», y el link del artifact.

## Paso 0 — decisiones

> Modo semi: lo menor se resuelve con la recomendación y se discute en el PR; lo de diseño que Jürgen ya decidió antes
> se le pregunta.

**D1 · ¿Qué chip lleva cada fila de la Comparativa?** → Contestó Jürgen (20-nov, en vivo): se queda la marca de cambio
que ya existe (`ComparisonChangeBadge`, flecha, verde/rosa, «igual» y «nuevo»), y **en la Comparativa no depende de
«Mostrar variaciones»**: con ese ajuste apagado no salía ninguna marca, que es lo que él veía. Se quita esa dependencia
de las filas, de «Te quedó», de la columna «Cambio» y de los chips de con qué comparar.

**D1 bis · ¿Qué es el rebote?** → Contestó Jürgen: «cuando bajas bastante en el flujo de caja y scrolleas rápido hasta
el título, se queda como pegado ahí rebotando». Reproducido en vídeo (XCUITest `test_rebote`): la barra de pestañas se
encoge y despliega sin parar y la lista salta ~88 pt cada ~1,2 s; en el Panel, con el mismo gesto, no. Causa: el scroll
de Reportes iba dentro de un `VStack` con la guía de la Comparativa encima. Arreglo: el scroll es la raíz y la guía va
dentro de él (molde `StatsGuideSlot`). La guía de la Comparativa pasa a irse con el contenido al desplazar.

**D2 · ¿Dónde se mide?** → Simulador iPhone 17 Pro con la semilla `pesado` (10 años) para el antes y el después, con el
mismo conductor; el iPhone 14 solo si está libre y para confirmar. Por qué: misma máquina y mismos datos dan una tabla
comparable. Alternativa descartada: medir solo en el iPhone (no hay vídeo de Jürgen y se compite con otras sesiones).

**D3 · ¿Cómo se evita recalcular?** → Firma de entradas (molde `StatisticsCalculationStamp`: `dataVersion`, guardados
de SwiftData, día, divisa, revisión del plan…) y solo se recalcula si cambió. La Comparativa no calcula mientras no se
ve: queda marcada y calcula al aparecer. Por qué: el molde ya está medido en el Panel y Estadísticas. Alternativa
descartada: mover el cálculo a otro hilo (los `@Model` no cruzan de hilo).

**D4 · Medición** → `FlujoFluidezMedida` (signpost + log, solo DEBUG) se queda en el código. Por qué: deja repetir la
medida. Alternativa descartada: instrumentación temporal (no se podría repetir).

**D5 · Ficheros fuera del `toca:`** → `FinancialReportView.swift` (es el anfitrión de las dos pestañas: el rebote y el
recálculo viven ahí) y un conductor de medición en `YalaUITests/FlujoDeCajaFluidez/` que se salta sin su variable. Se
anotan en «Decidido sin consultar».
