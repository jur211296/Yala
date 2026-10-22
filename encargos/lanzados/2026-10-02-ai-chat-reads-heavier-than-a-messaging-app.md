# Acercar el chat de Yala IA al peso visual de un chat de mensajería (referencia GrokBot)

## Contexto
Cola B (Cola A real-risk vacía; adaptive 13/13 ya cerrado). Acaba de cerrar `settings-redesign-as-grouped-lists-like-ios` con PR #331 en cola de merge a 2.1. Siguiente del pack UI 15-sep: este ticket.

Ticket: `tickets/backlog/ai-chat-reads-heavier-than-a-messaging-app.md`
Referencias: `docs/design/referencias/2026-09-15-chat-grokbot-referencia.png` y `2026-09-15-chat-yala-ia-actual.png`
Memoria/reglas de pulido si aplican: `.claude/agent-memory/frank/reference_skills_pulido_ui.md` (better-ui / emil-design-eng) — contrastar, no copiar recetas web.
Checklist iPad del carril B: `tickets/backlog/cola-b-redesigns-must-hold-up-at-ipad-width.md` — la vista del chat no debe asumir que vive en una hoja (sin tirador ni cierre dentro del hilo; en iPad irá en inspector); ancho legible ~700 pt centrado cuando el contenedor es ancho; decisión por size class / ancho, nunca por tipo de dispositivo.

## Qué se pide
Reducir el peso visual del chat de Yala IA hacia el patrón de mensajería de la referencia GrokBot, conservando lo que sí aporta Yala (las tres sugerencias de arranque — decidir si son tarjetas o líneas tocables).
Antes → después medible en capturas iPhone + al menos una captura ancha (iPad Adapt lane) según el checklist B.
PR a 2.1 con auto-merge cuando corresponda. Al terminar: `/cerrar-total` autónomo (no dejar la sesión colgada).

## Pipeline Mini (obligatorio — serial, 1 sim)
1. Limpiar sims muertos / basura previa
2. Build con `xcodebuild -jobs 2` **sin** sim booteado
3. Boot **1** solo sim
4. Tests
5. Apagar / erase ese sim
Prohibido solapar swift-frontend + SpringBoard + app + UITests. Norma flota: 1 simulador a la vez.

## Qué NO hay que tocar
- Siri / Apple Intelligence (ticket aparte).
- Settings ya migrados en #331 (salvo si el chat reusa un componente compartido roto).
- Prod deploy. No CloudAgent.
- No inventar copy nuevo en idiomas sin necesidad; reusar cadenas.

## Cierre limpio Mini
Tras `/cerrar-total` exitoso: apagar sim usado → erase/limpiar data del device → si PR mergeado o worktree inútil, quitar worktree + caches; no acumular Devices apagados ni worktrees. Si creaste keys en Llavero, el bot dueño las mueve a 1Password (vault Yala); Shared with Grok Bot solo logins/paneles.

## Cómo se sabe que está bien
- Capturas antes/después alineadas con la referencia (burbujas, jerarquía tipográfica, menos interrupciones grises, entrada más ligera).
- Tests/UITests verdes en el pipeline serial de 1 sim.
- Checklist B iPad marcado donde aplique a este ticket.
- PR abierto a 2.1 + resumen de cierre en lenguaje de usuario + `/cerrar-total`.

## Paso 0 — decisiones

Producto, contestadas por Jürgen con AskUserQuestion (19:12 Lima, sesión diurna), las tres con la recomendada:

1. **Sugerencias de arranque** → tres líneas tocables DENTRO de la burbuja blanca del saludo, separadas por una línea fina, sin icono ni flecha. El chat vacío queda en una sola burbuja.
2. **Avisos** («se borra al cambiar de día» y «puede cometer errores») → un único bloque pequeño bajo la fecha, arriba del hilo. Nada bajo la caja de escribir. Se reusan las dos cadenas existentes, sin copy nuevo.
3. **«Reiniciar contexto»** → queda solo el botón pequeño; fuera la línea «Yala IA recuerda N mensajes» (su clave `chat.contextMemory` se retira de los locales).

Técnicas, auto-contestadas (bypass):

4. **Burbujas**: radio `DS.Radius.xl` continuo, padding más generoso; colores sin cambiar (acento para el usuario, blanco `thCard` para Yala IA: las tarjetas blancas son identidad). Texto en párrafos (línea en blanco = párrafo), negrita y `código` por el markdown en línea que ya pide el prompt, dígitos de ancho fijo para las cifras. **No** se toca el prompt.
5. **Caja de entrada**: «+» fuera, a la izquierda, círculo blanco con etiqueta «Temas» para VoiceOver; dentro de la píldora solo placeholder y micro; el micro se cambia por enviar cuando hay texto (patrón de mensajería). Identificadores `chat_input` / `chat_close` intactos.
6. **Cabecera**: se queda la barra nativa (título + X + ajustes). La píldora con icono de GrokBot pediría un icono de Yala IA que no existe: fuera de alcance.
7. **Sin avatar** por mensaje: el color ya dice quién habla y sumaría un elemento.
8. **iPad / ancho**: hilo y caja con tope `DS.Adaptive.readableWidth` (700) centrados; la vista no lleva tirador ni cierre dentro del hilo (ya era así). La columna de iPad (`yalaAIChat`) no cambia.
9. **Fuera**: tarjetas de borrador/adjuntos dentro del hilo (son funcionales), el aviso puntual `contextHint`, el contador de preguntas, Siri.
