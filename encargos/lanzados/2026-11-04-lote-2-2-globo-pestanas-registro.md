# Lote 2.2 de tres arreglos chicos: globo de ayuda de Estadísticas, withAnimation de pestañas y «Nuevo registro a medias vuelve vacío»
toca: Estadisticas-globo-ayuda, transiciones-pestana, NuevoRegistro-borrador

Base: origin/2.2 en jur211296/Yala. Una sola sesión, un PR contra 2.2, un cierre. Usa tu propio worktree y un solo simulador de iOS 27.2, que apagas y borras al final.
1. El globo de ayuda de Estadísticas todavía explica P-1 y A-1, que ya no existen. Actualízalo para que explique los chips y la comparativa actuales.
2. Fluidez: busca los withAnimation de cambio de pestaña que la auditoría de fluidez no listó y ajústalos con el mismo criterio que esa auditoría.
3. La card «Nuevo registro a medias vuelve vacío» está en curso sin sesión. Hay que hacer que un registro a medio llenar se conserve al salir y volver.
Mueve a «in qa» las cards que cierres. Si tienes una duda que cambie el resultado, pregunta con preguntar-bot; no la asumas. Esta sesión corre en paralelo con otra de Yala que solo genera video en ~/Claude/propuestas/. No toques esa carpeta.

Termina con /cerrar-total.

## Paso 0 — decisiones

> D1-D4 las contestó Jürgen por el bot dueño (2026-11-04). D5-D6, resueltas en autónomo con mi recomendación; se discuten en el PR.

**D1 · Globo de Estadísticas (P-1/A-1)** → sin cambios de código: ya se reescribió el 31-oct en los 16 idiomas (card g6nw). Jürgen lo vio en un build anterior.
La hoja de ayuda vieja de la Comparativa («Toca M… o A…»), que ya no se abre desde ningún sitio, no se toca: queda como hallazgo y como card en backlog.

**D2 · withAnimation de pestaña que la auditoría no listó** → sin cambios: lo cerró la card oxyr en el PR de fluidez del 3-nov. Evidencia: correr hoy TabImplicitAnimationsWiringTests y adjuntar la lista de los sitios vivos con su clasificación. Si algo falla o queda un sitio sin clasificar, se arregla en este lote.

**D3 · Alcance del borrador** → solo en memoria (opción a). Sobrevive a que se rehaga la hoja dentro del mismo proceso, en los tres caminos de entrada (voz, foto compartida y enlace al Panel), y se descarta al cerrar la hoja o al guardar. No se guarda nada en disco.
Opción b («Nuevo registro: conservar el borrador si iOS cierra Yala») → backlog.

**D4 · Tablero** → lo muevo yo con `tablero` antes de cerrar. Si da 401, va la lista por preguntar-bot.

**D5 · Quién guarda el borrador** → quien presenta la hoja (un `@State` del modificador que presenta, en Estadísticas, Panel y Registros), con `onDismiss` para descartarlo.
Por qué: lo medido es que la hoja sigue presentada y lo que se rehace es su contenido, así que quien presenta sobrevive. Alternativa descartada: `SceneNavigation` global, que exige limpiar a mano y arriesga un borrador viejo en la apertura siguiente.

**D6 · Qué retoma el formulario rehecho** → el modelo del formulario y la foto de partida (así cerrar sigue preguntando si hay algo escrito). No vuelve a precargar desde el contexto, porque eso pisaría la cuenta elegida. El estado efímero de la vista (teclado, pistas) se pierde.
Por qué: los datos que escribió la persona viven en el modelo. Alternativa descartada: mover todos los `@State` del formulario, un refactor grande que nadie pidió.
