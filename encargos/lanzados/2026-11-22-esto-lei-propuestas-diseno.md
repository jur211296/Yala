Yala
# Propuestas de diseño para la hoja «Esto leí» tras leer un registro por foto o voz
---
toca: docs/propuestas/2026-11-22-esto-lei/,tickets/backlog/2026-11-22-esto-lei-propuestas-diseno.md,tickets/done/2026-11-22-esto-lei-propuestas-diseno.md
esfuerzo: high
cierre: cierra-sola
---

Pedido de Jürgen del 22-nov 06:34 Lima (t1877u), con GO a esta sesión de propuestas a las 06:38 (t1878u, «que vaya primera por ser propuesta»). SOLO PROPUESTA: no se cambia código de la app en esta sesión.

## Contexto
Después de leer un registro por foto o por voz, sale la hoja «Esto leí» (título, miniatura de la imagen, botón cerrar; una tarjeta con comercio, «Falta la categoría», monto, chips «Selecciona categoría», cuenta con ✦, fecha, «+ Etiqueta», una nota «Elegí BCP Crédito porque la imagen lo dice. Toca la cuenta para cambiarla», el aviso «Si cierras sin guardar, lo encontrarás en tu Bandeja de Entrada» y abajo «Otra foto» y «Guardar» deshabilitado). Ubícala en el código (busca «Esto leí» en los textos) y mira cómo se ve hoy con foto, con voz, con varios registros leídos a la vez y con todo completo.
Jürgen: «NO me encanta. El UI es feo. El UX no es tan fácil». Quiere que desde ahí se pueda COMPLETAR lo que falta y también ABRIR la hoja completa del registro (el editor B1 de Nuevo registro).

## Qué entregar
Un artifact visual de Claude con 2 o 3 propuestas comparables lado a lado, cada una con:
- Maqueta en iPhone (claro y oscuro) y una en iPad, con datos reales de ejemplo (un registro, varios registros y uno al que le falta la categoría).
- El recorrido paso a paso: completar lo que falta desde ahí, abrir el registro completo, guardar, otra foto/voz y cerrar sin guardar.
- Pros y contras, y tu recomendación marcada.
- Coherencia con el rediseño B1 de Nuevo registro y con la Bandeja (mismos chips, colores y jerarquía). Nunca un botón debajo de otro; texto de botones del toolbar en primary, no índigo (decisión t1876u).
Base las maquetas en capturas reales del simulador (puedes usar un segundo simulador en la Max o el iPhone 14 por DeviceMCP, verificando antes que esté libre). Incluye capturas del estado actual para comparar.
Deja el artifact y sus fuentes en `docs/propuestas/2026-11-22-esto-lei/`.

## Cómo trabajar
- Nada de código de la app ni nada en producción.
- Commit y PR sin firma de IA, contra 2.3, solo con la carpeta de la propuesta y el ticket. Auto-merge activado.
- Lo menor se decide con la recomendada y se anota. No hay decisiones vitales: la elección final es de Jürgen sobre el artifact.
- Cierre: `/cerrar-total`, con «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada», y el link del artifact bien visible para que Jürgen elija.

## Paso 0 — decisiones (resueltas en semi, sin preguntar: menores y reversibles)

1. **Base de las capturas del estado actual**: simulador iPhone 17 Pro de la Max (libre: ninguna otra sesión de Yala ni `xcodebuild` vivo), con los seams `-uitest-image-result` (one · incomplete · two · many) y `-uitest-voice-result` (one · incomplete · two), claro y oscuro. Una prueba de capturas **temporal**, fuera del commit. Motivo: el iPhone 14 no aporta nada que el simulador no enseñe en una hoja estática.
2. **iPad**: se crea un iPad temporal para capturar la hoja actual y se borra al acabar. Si el iPad falla al compilar o lanzar, la maqueta iPad se dibuja sobre el layout de hoy sin captura y se dice.
3. **Formato**: un solo artifact HTML con maquetas dibujadas en HTML/CSS (no imágenes retocadas), con los tokens de B1 (cápsula de moneda, «● Categoría · ● Necesidad ▾», fila Hoy · Cuenta · #, texto del toolbar en primary). Tres propuestas: A (pulir la tarjeta y completar en línea), B (lista de filas tipo Bandeja con un editor B1 por fila), C (la hoja B1 misma con la foto arriba, «Esto leí» como cabecera). Recomendada marcada con su porqué.
4. **Elección de Jürgen**: un selector en el artifact que guarda su veredicto en la base del artifact (colección `decision`), como en las maquetas de Nuevo registro.
5. **Sin código de la app**: el diff lleva solo `docs/propuestas/2026-11-22-esto-lei/` y el ticket. La prueba temporal se borra antes del commit.
6. **Decisiones pendientes del pie del encargo**: no son de esta sesión (pertenecen a otros encargos); no se incorporan aquí y se dice en el cierre.
