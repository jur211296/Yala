Sesión INTERACTIVA de decisiones, solo docs. Sin simulador y sin cambios de código en la app, así que corre en paralelo con la sesión de código que esté viva. Base origin/2.2.

Objetivo: dejar decidido el lote 2.2 · 02, el formulario de registro (22 cards UX/UI 2.2 · L2-1 a L2-22 en backlog; búscalas con `tablero listar --proyecto yala --buscar "L2-"`) para que quede LISTO PARA LANZAR. Es la pantalla más usada de Yala y un hito de 2.2 según docs/ROADMAP.md.

Pasos:
1. Lee cada card, el informe de la auditoría UX 2.2 sobre el formulario y el código actual del formulario, para entender el estado de hoy. Si ayuda, usa capturas que ya existan en el repo; no arranques simuladores.
2. Pregúntale a Jürgen con AskUserQuestion, por bloques temáticos (cuenta y guardar, categorías y etiquetas, divisas y tipo de cambio, calcular y repartir, favoritos y recurrentes, fecha, feedback tras guardar, jerarquía visual y glass). En cada pregunta van 2 o 3 opciones concretas con la recomendada marcada y el porqué. Lo más robusto y la mejor práctica es lo preferido de Jürgen. Haz solo las preguntas que de verdad necesitan decisión, y lo obvio decídelo y anótalo.
3. Con sus respuestas, escribe en la nota de cada card la decisión y el «hecha cuando» (tablero editar --nota reemplaza la nota entera, así que conserva lo que había). Mueve las 22 a «lista para lanzar». Escribe el brief de implementación en ~/Claude/tmp-frank/lote-decidido-2-2-02-formulario-registro.md, con el mismo formato que los otros lote-decidido, y si conviene pártelo en dos sesiones. Registra la decisión en DECISIONS.md con un PR solo de docs contra 2.2 (fetch y rebase justo antes de abrirlo).
4. Antes de cerrar, enséñale a Jürgen el resumen de las decisiones y espera su OK. Recién con su OK haces /cerrar-total. Sin su OK NO cierres.
Seguridad: no toques los ficheros sin commitear del árbol principal (Cloudkit Schemas/yala_dev-*.ckdb, Yala.xcscheme, encargos/pendientes/), ni los iPhones o el iPad reales, ni tmux salud--, sat-lab-- o clinicas-dentales-bi--.

## Paso 0 — decisiones

Sesión interactiva: las de producto las contestó Jürgen el 21-oct con AskUserQuestion; las técnicas y de proceso, Frank.

- **Base:** rama recolocada sobre `origin/2.2` (lanzar-sesion la dejó sobre 2.1). PR solo de docs contra 2.2.
- **Qué faltaba por decidir:** la opción de las 22 cards ya estaba elegida el 14-oct; se decidieron solo los detalles abiertos, medidos contra el código de 2.2.
- **Jürgen (21-oct):** tras guardar, el formulario se cierra con aviso Editar · Deshacer; «Mi parte» abre en Iguales la 1.ª vez y luego recuerda; se llaman «Favoritos»; entran las 3 cards de backlog que tocan el mismo código.
- **Frank (asumido):** precedencia de la cuenta precargada, textos y umbrales (3 registros, 6 aperturas), orden manual de favoritos, divisa del importe sin convertir, alcance de «Categoría». Todo anotado en la nota de cada card.
- **Implementación:** dos sesiones en serie (A flujo y datos, B textos y visual). Brief en `~/Claude/tmp-frank/lote-decidido-2-2-02-formulario-registro.md`.
- **Registro:** entrada en `docs/DECISIONS.md`. No se toca código de la app.
