# Revisión de varios registros (foto y voz): resumen arriba y elegir cuáles guardar, a partir de propuestas que elige Jürgen

Base: origin/2.2 en jur211296/Yala. Una sola sesión a la vez.
Card: `tablero-revision-de-varios-registros-foto-y-voz-va62` — Revisión de varios registros (foto y voz): resumen arriba y elegir cuáles guardar.

## Qué pidió Jürgen (2026-11-03)
- Hoy, cuando el registro por foto o por voz detecta varias transacciones, la hoja «Leí N registros» es una lista larga de tarjetas, cada una con chips «Selecciona categoría» / «Selecciona cuenta», y un botón «Guardar N». No hay resumen ni forma de seleccionar o deseleccionar.
- Quiere un resumen arriba (total, quizá una barra de desglose por categoría, rango de fechas) y poder elegir cuáles aprobar y cuáles no, con la lista agrupada (por ejemplo, por día).
- Aplica igual al flujo de foto y al de voz: misma hoja, mismo comportamiento.
- Capturas: `~/Claude/tmp-frank/adjuntos/multi-registro-actual-1.png` y `~/Claude/tmp-frank/adjuntos/multi-registro-actual-2.png` son la pantalla actual. `~/Claude/tmp-frank/adjuntos/multi-registro-referencia.jpg` es solo una idea (pantalla «Scan Transactions»: total grande, barra de categorías de colores, agrupado por día, check por fila, «Deselect All», «Tag All», botón «Add 7 · $346.57»); no es para copiarla tal cual.
- Respeta el README de marca: nada de degradados ni glows. Liquid Glass coherente con el resto de la app.

## Cómo trabajar
1. Paso 0: localiza la hoja «Leí N registros» y cómo la usan los flujos de foto y voz.
2. Prepara de 3 a 4 propuestas distintas (por ejemplo: total grande + barra por categoría + check por fila; resumen compacto con chips glass y acciones «Seleccionar todo» / «Asignar categoría a todos»; lista agrupada por día con subtotales). Haz cada una en claro y en oscuro, y saca capturas reales del simulador.
3. Antes de implementar, pregúntale a Jürgen con AskUserQuestion cuál quiere, adjuntando las capturas. Esta es una decisión de diseño de Jürgen: espera su respuesta.
4. Implementa solo la propuesta que elija, en foto y en voz: resumen arriba, selección por fila (todas marcadas por defecto), y el botón guarda solo las seleccionadas con el conteo y total correctos. Tests y video en el PR.

## Cierre
Esta sesión NO cierra sola antes de que Jürgen elija. Después de que elija y quede implementado, termina con /cerrar-total.

## Paso 0 (2026-11-03, Frank)
- **Dónde vive:** voz (`Views/Voice/VoiceRecordingView.reviewContent`) y foto (`Views/Image/ImageSelectionView.reviewContent`) arman cada una su lista y su «Guardar»; la tarjeta por registro es común (`VoiceDraftReviewCard`). «Guardar» aprueba TODOS los pendientes y solo se enciende si todos están completos (`VoiceEntryFlowLogic.canSave`).
- **Decisión:** la hoja de varios registros pasa a una pieza común que usan las dos; con un solo registro, la hoja de hoy sin cambios.
- **Propuestas:** 3, maquetadas en SwiftUI real detrás de `-mockv N` (DEBUG), con un resultado fijo nuevo de 7 registros en varios días y categorías (2 sin categoría), en claro y oscuro. La maqueta no se commitea; solo la elegida.
- **Asumido:** «Guardar» se enciende cuando los SELECCIONADOS están completos; uno incompleto se puede desmarcar para guardar el resto.
- **Pregunta de datos a Jürgen (mueve datos):** qué pasa con los desmarcados — quedan en la Bandeja (como hoy al cerrar sin guardar) o se descartan.
