---
esfuerzo: medium
---
# Banco de IA: el mejor juez también en Tendencias

**Prioridad:** low · **Card:** `tablero-banco-de-ia-el-mejor-juez-tambien-en-ten-4ejo` (vence 2026-10-15) · No hay ticket en `tickets/`: la card es la spec.

## Contexto
Tras el PR #410 (mergeado), Insights lo juzga solo Gemini 3.8 Flash: la coincidencia con la nota a mano subió de 67 % a 87 %. En Tendencias (`trends.summary`), Sonnet también juzga mal (medido aparte). Jürgen pidió decidir siempre lo mejor.

**Créditos (2026-10-09 14:01):** hay créditos de Claude. Para OpenAI y Gemini usa las claves del banco con el tope de gasto por corrida de siempre (`--max-usd`, `.claude/rules/ai-gateway.md`).

## Que se pide
1. Arranca sobre `origin/2.1`. Lee cómo lo hizo el PR #410 para Insights (`JUDGES` en `gateway/bench`).
2. Mide, con el banco y tope de gasto, la coincidencia de cada juez disponible con la nota a mano en `trends.summary` (mismo método que #410). Si no hay notas a mano suficientes para Tendencias, dilo en el PR con el número que hay.
3. Pon en `JUDGES` para `trends.*` el juez que más coincida. Regla: nadie juzga a su propio proveedor.
4. No toques los jueces de otras tareas ni el modelo que sirve Tendencias en producción.
5. Tests del banco que cubran `JUDGES` en verde (`cd gateway && npm run typecheck && npm test`), con un caso que falle si Tendencias vuelve al juez anterior.
6. Nota corta en el doc del banco (`docs/ai-model-bench-2026-10*.md` o el que ya exista) con la tabla de coincidencia y el porqué. En el PR: coincidencia antes y después y gasto de API.
7. Rebase al final, sin esperar a nadie: justo antes de abrir el PR, `git fetch` y rebase sobre `origin/2.1`, resolviendo ahí cualquier conflicto (strict=false). Si el rebase trae cambios que tocan lo tuyo, repite los tests.
8. Tickets nuevos al tablero (antes del `/cerrar-total`): por cada ticket nuevo que abra esta sesión en `tickets/`, mira primero con `tablero listar --proyecto Yala --todas` que no tenga ya card y, si no la tiene, créala: `tablero crear --proyecto Yala --agente frank --asignado frank --estado backlog --prioridad <la del ticket> --titulo "<título claro en español neutro>" --contexto "<una línea>" --enlace "Ticket|https://github.com/jur211296/Yala/blob/2.1/tickets/backlog/<slug>.md" --enlace "PR #<N>|<url del PR>"`. Lista esas cards (título e id) en el aviso de cierre. Va SIN --fecha (la fecha de las cards es opcional desde el ADR-068; no pongas fecha de relleno).
9. Cierre: `/cerrar-total` autónomo (PR a 2.1 con auto-merge, limpieza de worktree/tmux/cachés). Card 4ejo a «done» (frank) si no queda nada para Jürgen.

## Carga de la Mini (OBLIGATORIO)
Esta tarea no debería necesitar Xcode. Si por algo lo necesitas:
- Todo `xcodebuild` va como `nice -n 10 xcodebuild -jobs 2 ...`.
- Nunca dos builds o tests a la vez (ni en paralelo ni en segundo plano).
- Antes de cada build o test, espera a que la carga de 1 minuto baje de 8: `while [ $(sysctl -n vm.loadavg | awk '{print int($2)}') -ge 8 ]; do sleep 30; done`.
- No filtres la salida de xcodebuild con `| head`: escribe a un log y busca en él.
- En zsh, los `-only-testing:` van en un array, no en una variable de texto.
- No enciendas simuladores.

## Paso 0

- **Muestra:** había 10 respuestas de Tendencias puntuadas a mano. Asumido: ampliar a 40 antes de decidir (30 más del 7-oct, puntuadas por Frank antes de lanzar ningún juez), en vez de decidir con 10.
- **Jueces medidos:** los cuatro de `JUDGES` (Sonnet 5.5, Gemini 3.8 Flash, Grok 4.3, gpt-oss-120b). No se añade un juez de OpenAI: no está en la lista y sería otro encargo.
- **Regla:** uno solo por respuesta, como en Insights; el relevo, el segundo que más coincida de otro proveedor.
- **Tope de gasto:** el CLI del juez no tenía `--max-usd`; se añade con la forma de `run.ts` y se corre con 1 USD.
- **Ficheros:** `gateway/bench/lib/insightsJudge.ts`, `insightsReport.ts` (comentario), `gateway/test/ai.bench.insights.test.ts`, `gateway/bench/README.md`, `docs/ai-model-bench-2026-10-claude.md`, y los resultados del 7-oct (notas a mano y juicios nuevos).
