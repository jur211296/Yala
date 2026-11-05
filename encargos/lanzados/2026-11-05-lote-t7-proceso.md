# Lote T7 · Proceso: turno de simulador, guion de QA, filtro de tickets y memoria
toca: `qa/`, `tools/`, `.claude/`

Rama base: 2.3. Un solo PR. Máquina: cualquiera. No usa simulador.
Lote proceso (cola-2-3-propuesta.md §3 T7).

Cards:
1. Recetas de traducción y el /qa usan el simulador compartido sin pedir turno, y pueden dar rojos falsos.
2. El guion de la tanda de QA vuelve a dejar fuera, sin avisar, tickets que esperan prueba en el iPhone.
3. Filtro de tickets con Haiku: duplicados y ya resueltos antes de lanzar.
4. Podar el índice de memoria de Frank (MEMORY.md pesa 42,8 KB; el límite de lectura es 24,4 KB).

Hecha cuando: las cuatro hechas; las recetas y el /qa piden sim-lock; el guion avisa los tickets que deja fuera; el índice queda bajo 24 KB sin perder entradas vigentes.

PREGUNTAR, NO SALTAR. `tablero` + cierre con la sección «Saltado o asumido sin preguntar». Termina con /cerrar-total.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.
> Única pregunta hecha al bot: la clave de la API (no estaba en la Max); Jürgen la copió.

**D1 · Rama base** → `2.3`, como dice el encargo (el worktree nació en `2.2`; la rama no tenía commits y se movió a `origin/2.3`).
Por qué: el encargo la nombra. Alternativa descartada: `2.2`, que es la del `CLAUDE.md` pero no la de este lote.

**D2 · Cómo pide turno el `/qa`, que instala con XcodeBuildMCP y no se puede envolver** → sostener el turno con `sim-lock.sh -- sleep 7200` en segundo plano, reentrar con el token del lockfile si corre un XCUITest dentro, y `kill` al acabar. Sin cambios en `sim-lock.sh` (solo su cabecera).
Por qué: es la opción (1) del ticket, la única que previene; el patrón se probó con un lockfile propio (toma, reentra, el ajeno espera y sale 75, el kill libera). Alternativa descartada: un modo `--sostener` nuevo en el script, que obliga a tocar un banco de 37 casos para algo que ya se consigue con el exec.

**D3 · Tope del turno sostenido** → 2 h; si la tanda dura más, se vuelve a pedir.
Por qué: si la sesión muere sin soltarlo, el `sleep` huérfano bloquea a todos como mucho 2 h. Alternativa descartada: sin tope.

**D4 · `/barrido-qa` y el device QA de las recetas ja/zh también piden turno** → sí, con el mismo patrón.
Por qué: instalan sobre el mismo bundle id; el barrido ya decía «como en `/qa`». Es la misma instancia del patrón.

**D5 · `add-l10n-key.sh` imprimía un `xcodebuild` con scheme `Yala` sin cola** → ahora remite a `/l10n-check`, que ya hace cola con `Yala Dev`.
Por qué: dos recetas para la misma batería divergían.

**D6 · El guion: ¿reescribir los montajes o avisar?** → avisar. Comprobador `qa/scripts/guion-tanda-check.py` que cruza `tickets/qa/` con los ids del guion; con `--escribir` deja un bloque de aviso arriba del propio guion. Repartir en montajes sigue siendo del `/barrido-qa`, que ahora lo corre al terminar y `/qa-guiado` al empezar.
Por qué: el criterio del encargo es «el guion avisa»; montar 17 tickets es un barrido entero. Alternativa descartada: que el CI falle con desfase, que bloquearía cualquier PR que mueva un ticket a `qa/`.

**D7 · Banco del comprobador en el CI** → sí, como paso del job `coverage-index`, igual que los demás `*-test.sh`.

**D8 · Filtro con Haiku: qué toca y qué no** → script en `tools/` que solo lee `tickets/backlog/` y el código de la base, y escribe un informe fuera del repo; nunca mueve tickets. Modelo Haiku, clave leída de `~/Secrets/yala-ai-bench/anthropic.key` sin imprimirla. Corrida entera sobre el backlog con el gasto estimado antes, y muestra revisada a mano.
Por qué: la card lo pide así. La base es `origin/2.3`, no `2.1` (la card es anterior al cambio de rama).

**D9 · Podar `MEMORY.md` sin perder entradas vigentes** → el índice queda con una línea corta por entrada; las memorias de lecciones de código se agrupan en sub-índices temáticos que el índice enlaza; solo se borran entradas cuyo fichero no existe o que están superadas, y se listan en el PR.
Por qué: 350 líneas a ~140 bytes no caben en 24 KB; cortar los ganchos no basta sin agrupar.
