---
esfuerzo: high
---
# Las sugerencias del chat que reescribe la IA se muestran también en alemán, polaco e inglés, y las que inventan un comercio siguen fuera

## Contexto
Card del tablero `tablero-con-la-app-en-aleman-o-polaco-las-sugere-aq9g` (lista para lanzar, vence 2026-10-10). Ticket: `tickets/backlog/suggestions-rewriter-drops-german-and-polish-rewrites.md` (banco de `chat.rewrite`, sesión 2 del gateway de IA, `gateway/bench/results/2026-10-07/REPORT-chat-y-nota.md`). El triage de Frank del 2026-10-07 lo confirmó vivo en el código de 2.1.

Lo que le pasa al usuario: con Yala en alemán, las sugerencias del chat que reescribe la IA no se enseñan nunca: la app las descarta y pone las fijas, con cualquier modelo. En polaco y en inglés pasa a veces.

Según el ticket (son pistas, verifícalas en este árbol antes de tocar nada):
- `SuggestionsRewriterService.isValid` (`Yala/App/Services/SuggestionsRewriterService.swift`, ~L132 en 2.1 de hoy) toma por nombre propio toda palabra con mayúscula que no sea la primera. En alemán todos los sustantivos van con mayúscula («Ausgaben», «Monat»), así que ninguna reescritura pasa.
- En polaco no casan los nombres declinados («w Biedronce» frente a «Biedronka»); en inglés, los meses («October»).
- El banco replica el validador en `gateway/bench/lib/chatRewrite.ts` y lo mide aparte («lo que la app conserva»). La clave del banco cobra del mismo saldo prepago que producción (`.claude/rules/ai-gateway.md`): pon tope de gasto por corrida.

Antes de esta sesión va en la cola `voice-note-parser-prompt-knows-six-currencies`; no depende de ella.

Para orientarte: `CLAUDE.md`, `.claude/rules/ai-gateway.md`, `.claude/rules/l10n.md`, `.claude/rules/testing.md` y el ticket.

**Créditos (actualizado 2026-10-09 14:01):** Jürgen confirmó que volvió a haber créditos de Claude, así que sí se puede gastar API en esta sesión. Para OpenAI y Gemini usa las claves del banco con el tope de gasto por corrida de siempre (`.claude/rules/ai-gateway.md`); para Claude, también con tope.

## Que se pide
1. Reproducir con test: frases reales y correctas en alemán, polaco e inglés que hoy no pasan el validador.
2. Arreglar con la opción más robusta: que el validador siga cazando comercios o nombres inventados sin tomar por nombre propio los sustantivos alemanes, los meses y días ni las formas declinadas de un comercio que sí está en la lista blanca. Decide el criterio con los casos del banco delante, no a ojo.
3. Mantener la réplica del banco (`gateway/bench/lib/chatRewrite.ts`) igual que la app, y medir «lo que la app conserva» antes y después con tope de gasto.
4. Tests: reescrituras correctas en alemán, polaco e inglés pasan; una con un comercio inventado sigue sin pasar, en los tres idiomas y en español. Control rojo con el código viejo.
5. Anota lo medido en el ticket y muévelo según las convenciones del repo.
6. Cierre: `/cerrar-total` autónomo (PR a 2.1 con auto-merge, limpieza). Al cerrar, mueve la card `tablero-con-la-app-en-aleman-o-polaco-las-sugere-aq9g` a «in qa» asignada a jurgen si queda device-QA, o a «done» asignada a frank si no queda nada para él, con `tablero mover <id> --a "<estado>" --agente frank` y `tablero asignar <id> --a <quien> --agente frank`.
7. Tickets nuevos al tablero (antes del `/cerrar-total`): por cada ticket nuevo que abra esta sesión en `tickets/`, mira primero con `tablero listar --proyecto Yala --todas` que no tenga ya card y, si no la tiene, créala: `tablero crear --proyecto Yala --agente frank --asignado frank --estado backlog --prioridad <la del ticket> --titulo "<título claro en español neutro>" --contexto "<una línea>" --enlace "Ticket|https://github.com/jur211296/Yala/blob/2.1/tickets/backlog/<slug>.md" --enlace "PR #<N>|<url del PR>"`. Lista esas cards (título e id) en el aviso de cierre. Va SIN --fecha (la fecha de las cards es opcional desde el ADR-068; no pongas fecha de relleno).

## Que NO hay que tocar
- El prompt de la reescritura y la tabla de modelos del gateway; nada de desplegar el Worker.
- Las sugerencias fijas.
- El código muerto de OCR local `Yala/App/Services/ImageOCR/`.
- `qa.yml`, `nocturna-vigilante.yml`, `ping-avisador.yml` ni `avisar-grok-push-principal.yml`.
- Nada de marketing/ ni Web/.

Regla día/noche (hora de Lima): entre las 06:00 y las 21:00, si aparece una decisión de producto o de riesgo, pregúntala con AskUserQuestion. Entre las 21:00 y las 06:00, decide tú la opción recomendada y sigue, o difiere lo de alto riesgo dejándolo propuesto en el ticket (A/B/C con recomendación); en ese horario no uses AskUserQuestion.

## Pipeline de la Mini (serial, obligatorio)
1. Limpiar sims muertos, DerivedData de sesiones cerradas y cachés de XcodeBuildMCP de worktrees que ya no existen, sin preguntar. El disco anda justo (~32 GB libres el 2026-10-08, justo en el umbral de 32).
2. Build con `xcodebuild -jobs 2` sin simulador booteado.
3. Boot de 1 solo simulador.
4. Tests.
5. Apagar y borrar ese simulador.
Prohibido solapar swift-frontend + SpringBoard + app + UITests.

Rebase al final, sin esperar a nadie: la sesión arranca ya sobre `origin/2.1` y trabaja sin esperar el CI de ningún otro PR. Justo antes de abrir su PR, hace `git fetch` y rebasa sobre `origin/2.1`, y resuelve ahí cualquier conflicto (el ruleset de `2.1` tiene strict=false). Si el rebase trajo cambios que tocan lo suyo, vuelve a compilar y a correr los tests afectados sobre el árbol rebasado, con un solo simulador.

DerivedData y cachés de XcodeBuildMCP: al lanzar y al cerrar, borra el DerivedData de esta sesión y las cachés de worktrees retirados o ya mergeados, sin pedir aprobación. No toques los de otra sesión viva. Si el borrado falla, dilo en el cierre.

## Como se sabe que esta bien
- Con Yala en alemán, una reescritura correcta se enseña; una con un comercio inventado no.
- Lo que la app conserva en el banco sube en alemán, polaco e inglés sin dejar pasar inventados (números en el PR).
- Tests con control rojo con el código viejo; builds `Yala` y `Yala Dev` verdes.
- PR a 2.1 en auto-merge, ticket movido, card del tablero movida, Mini limpia (sim apagado y borrado, sin DerivedData de la sesión).

## Paso 0

Medido en este árbol (2026-10-09) antes de tocar nada:

- **El ticket es cierto y se queda corto.** En el banco del 2026-10-07 (7 candidatos × 2 pasadas) la app conserva de
  las reescrituras 15 de 70 en alemán, 29 de 42 en polaco y 30 de 42 en inglés (el resto de idiomas, 42 de 42). Y en
  alemán ni siquiera llegan a reescribirse bien: la primera pasada ya marca inválidas las 5 sugerencias del caso
  («Monat», «Budget»), así que todo va a reescritura.
- **En inglés el «I» pasa por casualidad**: no está en `commonWords` y lo salva la regla de subcadena porque algún
  nombre del usuario contiene la letra «i». Con una lista sin «i» («Food», «Gas»), toda frase con «I» cae.

Decisiones (autónomo, de día; ninguna es de producto):

1. **Criterio: listas de palabras comunes por idioma + raíz para declinaciones**, no etiquetado gramatical
   (`NLTagger` no cubre polaco y no se puede replicar en el banco). `isValid` recibe el idioma. Alemán: sustantivos
   genéricos de una pregunta de finanzas (tiempo, totales, comparación), meses, días y el «Sie» formal; inglés: «I»,
   meses y días. **No entran sustantivos que podrían ser una categoría inventada** («Abos», «Rechnungen», «Miete»):
   un falso rechazo cae a las fijas (lo de hoy), un falso acierto enseña algo que el usuario no tiene.
2. **Declinación**: una palabra casa con un nombre de la lista si comparten raíz (prefijo común ≥ máx(largo − 2, 5) y
   la palabra no lo supera en más de 3 letras). «Biedronce» → «Biedronka», «Rozrywkę» → «Rozrywka»,
   «Restauracjach» → «Restauracje». El mínimo de 5 evita que «Comisión» pase por «Comida».
3. **La réplica del banco lee las listas del Swift** (como ya hacía con `commonWords`), así que no pueden divergir.
4. **Tope de gasto por corrida**: `--max-usd` en el banco, que deja de lanzar llamadas al llegar al tope. Se mide con el
   modelo de producción (`gpt-6-luna`) y el re-cálculo de las 250 frases ya guardadas, que no cuesta nada.
5. Se añade a `chat.suggestions` la misma métrica («cuántas sugerencias de primera pasada conserva la app»), porque en
   alemán el fallo empieza ahí.
