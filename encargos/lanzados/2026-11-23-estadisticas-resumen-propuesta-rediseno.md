Yala
# Propuesta visual de rediseño para Estadísticas → «Resumen» (Salud financiera, Detalle y Gastos hormiga)
---
toca: docs/propuestas/estadisticas-resumen-2-3/,tickets/backlog/2026-11-23-estadisticas-resumen-propuesta-rediseno.md,tickets/done/2026-11-23-estadisticas-resumen-propuesta-rediseno.md
esfuerzo: medium
cierre: cierra-sola
---

Pedido de Jürgen (23-nov, pruebas de Yala 2.3 en iPhone). **Esta sesión es solo diseño y propuesta visual: NO modifiques código Swift de la app todavía.**

## Qué observó Jürgen hoy en Estadísticas → «Resumen»
1. **«Tu salud financiera» ocupa demasiado espacio vertical para dar solo cuatro números** (hoy es una card grande con el anillo de puntaje a la izquierda y cuatro barras horizontales: Presupuestos, Ritmo, Compromisos, Lo que te queda). Idea de Jürgen: podría ser un banner mucho más compacto, parecido al del Panel, con los cuatro anillos u otra alternativa limpia.
2. **Bloques de poco valor o sobredimensionados en «Detalle»:**
   - «Categoría principal» casi siempre será «Hogar» (alquiler/hipoteca), así que no suma tener una caja fija dedicada a eso (y además se repite con «Subcategoría principal: Alquiler o hipoteca» y «Mayor gasto: Renta»).
   - «Promedio diario» hoy ocupa una caja gigante de ancho completo para mostrar un solo número.
3. **«Gastos hormiga» está muy desordenado:** mezcla la lista de comercios repetidos, una nota explicativa al medio, una subsección «Con Yala IA» con otro ítem y dos párrafos sueltos debajo. Jürgen quiere que tenga más protagonismo y un diseño más llamativo, limpio y fácil de escanear.
4. **Visión general de la pestaña «Resumen»:** rediseñarla para dar más valor real y mejor experiencia: que al venir desde el Panel el usuario encuentre información más útil que **converse con lo que ya vio en el Panel**, le permita **tomar decisiones rápido** y **derivarse fácilmente a otras vistas de detalle** (Distribución, Presupuestos, Registros, etc.).

## Qué se pide
1. Lee en el repo cómo están hechos hoy `Yala/App/Views/Statistics/InsightsTabView.swift`, el banner de Salud financiera del Panel, `InsightsCalculator.swift`, `AntExpensesCalculator.swift` y `AntExpensesAILogic.swift` para basar la propuesta en datos que la app ya calcula (o marcar explícitamente si alguna métrica sugerida requeriría cálculo nuevo).
2. Diseña **2 o 3 propuestas concretas y comparables** para Estadísticas → «Resumen», entregadas en un **artifact visual de Claude** (HTML interactivo y visual, nunca Markdown ni PDF de texto plano) donde Jürgen pueda:
   - Comparar el estado actual vs cada propuesta lado a lado en marco de iPhone (modo oscuro como principal y toggle a modo claro).
   - Ver qué bloques se compactan (Salud financiera), qué bloques se eliminan o fusionan (Categoría principal, caja gigante de Promedio diario), cómo luce el nuevo bloque protagonista de «Gastos hormiga» (incluyendo la capa de Yala IA de forma ordenada) y cómo se conecta con accesos directos a Distribución, Presupuestos y Registros.
   - Ver una tabla breve de recomendación y qué cambia en cada opción para elegir rápido.
3. Guarda una copia HTML o nota con el enlace al artifact en `docs/propuestas/estadisticas-resumen-2-3/` y deja un PR limpio contra `2.3` sin firma de IA, con auto-merge activado, esperando el merge real antes de `/cerrar-total`.
4. Todo en español neutro latinoamericano.

## Paso 0 — decisiones (resueltas en autónomo, bypass nocturno)

1. **Formato del entregable:** artifact HTML propio (no tipo Design): comparador Hoy fijo + propuesta elegida en marco de iPhone, oscuro por defecto con botón a claro, tabla y bloque de decisión guardado en la `db` del artifact (solo escribe el dueño). Copia en `docs/propuestas/estadisticas-resumen-2-3/index.html` + `README.md` con el enlace.
2. **Tres propuestas:** A «Ordenar» (mismas piezas, compactas), B «Decidir» (recomendada: el Resumen sigue al Panel con acciones y accesos), C «Mosaico» (los cuatro anillos literales + tarjetas). Mismos datos de ejemplo en todas.
3. **Datos:** solo lo que la app ya calcula; lo nuevo se marca «Cálculo nuevo» (ritmo del mes de hormiga, días que quedan de presupuesto, orden de acciones, filtro de Registros por comercio).
4. **Sin capturas del simulador:** la maqueta de «Hoy» sale del código de `InsightsTabView`; la app no cambia, así que no hay antes/después que capturar.
5. **Entrega:** solo docs + ticket (directo en `done`, es diseño entregado). PR contra `2.3` con auto-merge, como pide el encargo.
6. **Decisiones pendientes del lote (build 7, mudanza web):** no tocan esta propuesta; se registran con `decisiones.py` si el script está en la máquina.
