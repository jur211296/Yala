# Los comentarios de IA de Insights, del flujo de caja y de las desviaciones salen en el idioma de la app

## Contexto
Hay dos tickets en `tickets/backlog/` de 2.1 que son el mismo problema visto desde dos lados. Trabájalos juntos en esta sesión:
- `insights-cashflow-and-deviation-prompts-do-not-ask-for-the-language` (prioridad alta, sale del banco de Insights de la sesión 2 del gateway, informe `gateway/bench/results/2026-10-07/REPORT-insights-y-tendencias.md`).
- `ai-comments-ignore-the-app-language` (sale de `docs/ai-usage-review-2026-10.md`, hallazgo H1).

Lo que le pasa al usuario: con Yala en inglés, alemán, japonés o cualquier idioma que no sea español, el comentario de la IA bajo el flujo de caja y el de las desviaciones del plan sale casi siempre en español, y el vocabulario del prompt español se cuela en otros idiomas («Dein Gasto», «gasto oscylował», «ingressos»). Además el análisis de Insights manda la región de formato del iPhone y no el idioma de la interfaz, así que alguien con la app en inglés y el iPhone en región Perú lo recibe en español.

Según los tickets (son pistas, verifícalas en este árbol antes de tocar nada): los prompts de `InsightsLLMService.generateCashFlowInsight` y `generateDeviationInsight` no dicen en qué idioma contestar, y `InsightsViewModel` manda `Locale.current.language.languageCode` en vez de `AppLocale`, que es lo que ya usan el chat, las sugerencias y Tendencias. Medido el 2026-10-07: el acierto de idioma de todos los modelos del banco se queda entre 21 y 57 %, también con `gpt-4.1-mini`.

La app tiene 10 idiomas (es, en, pt, fr, de, it, nl, pl, ja, zh-Hans) y las variantes es-419, es-AR, es-ES, en-GB, pt-BR, pt-PT. El banco cubre 14 locales.

Hoy se cerraron el PR #389 (sesión 2 del gateway, ya mergeado) y el PR #390 (índice de docs debajo del frontmatter, en cola de auto-merge a 2.1). Ninguno depende de este encargo.

Para orientarte: `CLAUDE.md`, las `.claude/rules/` que toquen y los dos tickets.

## Que se pide
1. Que los comentarios de IA de Insights, del flujo de caja (proyección) y de las desviaciones salgan en el idioma de la app, con la fuente de idioma de toda la app (`AppLocale`) y de la forma más robusta, coherente con cómo lo resuelven ya el chat y Tendencias. Revisa si el prompt español además necesita dejar de colar vocabulario propio en otros idiomas.
2. Volver a correr el banco sobre esas tareas (`npm run bench -- --task insights.cashflow,insights.deviation`, y la de Insights si existe en el banco) y dejar el resultado nuevo junto a los de la sesión 2.
3. Cubrirlo con test: que el payload y los prompts lleven el idioma de la app y no la región, con un control que salga rojo con el código viejo.
4. Capturas: solo si el cambio se puede ver en el simulador con la app en inglés (comentario antes en español, después en inglés), deja `capturas/antes.png` y `capturas/despues.png` en el worktree con rutas absolutas en el cierre. Si no se puede ver sin inventar datos, no hagas capturas.
5. Mueve los dos tickets a donde toque según las convenciones del repo.
6. Cierre: `/cerrar-total` autónomo (PR a 2.1 con auto-merge, limpieza). Al cerrar, mueve la card del tablero «Los comentarios de IA de Insights y del flujo de caja salen en el idioma de la app» a «done» si no le queda nada a Jürgen, o a «in qa» asignada a jurgen si queda device-QA, con `tablero mover <id> --a "<estado>" --agente frank`.

## Que NO hay que tocar
- El gateway, el mapa de modelos por tarea ni los proveedores: esto es solo idioma en prompts y payload.
- El código muerto de OCR local `Yala/App/Services/ImageOCR/`.
- `qa.yml`, `nocturna-vigilante.yml`, `ping-avisador.yml` ni `avisar-grok-push-principal.yml`.
- Nada de marketing/ ni Web/.

## Pipeline de la Mini (serial, obligatorio)
1. Limpiar sims muertos, DerivedData de sesiones cerradas y cachés de XcodeBuildMCP de worktrees que ya no existen, sin preguntar. El disco anda justo (~20 GB libres, por debajo del umbral de 32).
2. Build con `xcodebuild -jobs 2` sin simulador booteado.
3. Boot de 1 solo simulador, y solo si hace falta.
4. Tests.
5. Apagar y borrar ese simulador.
Prohibido solapar swift-frontend + SpringBoard + app + UITests.

Gate tras el CI del PR anterior: la sesión arranca ya sobre `origin/2.1`. Justo antes del gate, mira si el PR #390 sigue en CI. Si sigue, espera a que entre y rebasa una sola vez, con el simulador apagado. Si `2.1` no se movió, sigue de frente. Si ese CI falla, no esperes: rebasa con lo que haya y sigue. El build y el simulador van después de ese rebase, una sola vez.

DerivedData y cachés de XcodeBuildMCP: al lanzar y al cerrar, borra el DerivedData de esta sesión y las cachés de worktrees retirados o ya mergeados, sin pedir aprobación. No toques los de otra sesión viva. Si el borrado falla, dilo en el cierre.

## Como se sabe que esta bien
- Los comentarios de flujo de caja y desviaciones salen en el idioma de la app en los 14 locales del banco, sin bajar del 100 % en lo que no es idioma; Insights usa el idioma de la interfaz y no la región.
- Test con control rojo con el código viejo.
- Builds `Yala` y `Yala Dev` verdes.
- PR a 2.1 en auto-merge, card del tablero movida, Mini limpia (sin sim vivo, sin DerivedData de la sesión).

## Paso 0

Decidido antes de tocar código (sesión autónoma, sin preguntas: nada de esto es de producto ni de acceso).

- **Fuente del idioma: `AppLocale.identifier`** (BCP-47 con región: «es-PE», «de», «zh-Hans»), la misma de Tendencias y
  el chat. Vive en un solo sitio, `AIPromptLanguage.current`. La región (`Locale.current.region`) sigue solo como pista
  de tono, igual que hoy.
- **Medido en el árbol** (los tickets daban coordenadas viejas): `InsightsViewModel.swift:286` manda
  `Locale.current.language.languageCode`; los prompts de flujo y desviaciones no llevan idioma; las tres instrucciones
  de trato dicen `Tutea ("tú")` fijo.
- **Los tres prompts de Insights comparten la línea de idioma** (`InsightsLLMService.languageInstruction`): pide el
  idioma de la app aunque las instrucciones estén en español y que las palabras que citan las reglas («gasto»,
  «ingreso», «presupuesto») vayan traducidas. Tendencias no se toca: el banco le da 100 %.
- **Trato por idioma**: la tabla del chat sale a `AIPromptLanguage.informalRegister(forBaseLanguage:)` y la usan los dos.
  El chat sigue mandando exactamente el mismo texto (su cálculo del idioma base no cambia, ni su fallo con «es-ES» y
  «pt-BR», que va a ticket aparte).
- **Las cachés llevan el idioma**: la de tarjetas (5 min) y las de flujo y desviaciones (24 h). Sin eso, cambiar de idioma
  devolvía el comentario viejo.
- **Los nombres de mes del payload de flujo salen en el idioma de la app** (`AppLocale.current`), no en el del sistema.
- **Prompts como funciones puras** (`cashFlowSystemPrompt`, `deviationSystemPrompt`) para poder probarlos sin red; el
  banco cambia sus marcadores (`gateway/bench/lib/insightsRequests.ts`), no el gateway.
- **Banco**: solo la fila activa de cada tarea (`gpt-6-luna`, el esfuerzo de su fila), `--reps 2`, en
  `gateway/bench/results/2026-10-07-idioma/`, junto a los de la sesión 2.
- **Capturas**: sí se ven. Con `Yala Dev`, el secreto de staging (`~/Secrets/yala-gateway/staging-dev-shared-secret`), el
  seed `realista`, el iPhone en español-Perú y el idioma de Yala forzado a inglés, el resumen de Insights salía en español
  (antes) y sale en inglés (después). El flujo de caja no tiene plan sembrado: no se capturó.
