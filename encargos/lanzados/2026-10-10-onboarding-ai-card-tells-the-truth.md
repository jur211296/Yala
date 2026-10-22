# La tarjeta «IA segura» del onboarding dice algo cierto (card q2qc, v2.1)

Effort: medium. Decisión de Jürgen, opción B (10-oct, 16:25).

## Qué se pide
1. En la tarjeta «IA segura» del último paso del onboarding, cambiar el título y el subtítulo por un texto verdadero y corto, en los 16 idiomas. Punto de partida: título «IA a través de nuestro servidor» y subtítulo «Tú decides si usarla». Puedes afinarlo, pero tiene que ser cierto: la foto, la voz y el chat pasan por nuestro servidor hasta OpenAI, y solo con el consentimiento del usuario. Que entre sin truncarse en iPhone SE y en los idiomas largos (de, pl).
2. Borrar las dos claves sin uso: «no comparten ni almacenan datos sensibles» y «solo datos resumidos a OpenAI». Usa grep para confirmar que nadie las usa.
3. Extender el test de frases prohibidas (el del PR #445) para que esas frases y «IA segura» no vuelvan en ningún idioma.
4. Hacer capturas antes y después de la tarjeta (es y en) en ~/Claude/worktrees/_capturas/ y enlazarlas en el PR.
5. Abrir un PR a 2.1 en auto-merge. No hace falta QA en el teléfono salvo que lo justifiques.
## Reglas de siempre
- Arranca sobre `origin/2.1` y trabaja sin esperar a nadie. Justo antes de abrir el PR: `git fetch` y rebase sobre `origin/2.1`, resolviendo ahí los conflictos (strict=false); si el rebase toca lo tuyo, recompila y repite los tests afectados con un solo simulador.
- Tickets nuevos al tablero (antes del `/cerrar-total`): por cada ticket nuevo en `tickets/`, mira con `tablero listar --proyecto Yala --todas` que no tenga card y, si no, `tablero crear --proyecto Yala --agente frank --asignado frank --estado backlog --prioridad <la del ticket> --titulo "<título claro en español neutro>" --contexto "<una línea>" --enlace "Ticket|https://github.com/jur211296/Yala/blob/2.1/tickets/backlog/<slug>.md" --enlace "PR #<N>|<url>"`. SIN --fecha (opcional desde el ADR-068; sin fecha de relleno). Lista esas cards en el aviso de cierre.
- Sin deploy, sin secretos y sin decisiones de UI de Jürgen: si algo lo pide, para y anótalo en el cierre.
- Cierre: `/cerrar-total` autónomo (PR a 2.1 en auto-merge, limpieza de simulador, worktree y DerivedData).

## Carga de la Mini (OBLIGATORIO)
- Todo xcodebuild va con `nice -n 10 xcodebuild -jobs 2 ...`.
- Nunca dos builds o tests a la vez (ni build + tests); pipeline serie: build → 1 simulador → tests → erase.
- Antes de cada build espera a que la carga baje de 8: `while [ $(sysctl -n vm.loadavg | awk '{print int($2)}') -ge 8 ]; do sleep 30; done`.
- Nunca pases xcodebuild por `| head` (mata el build): escribe a un log y lee el log.
- Los `-only-testing:` van en un array de zsh, no en un string.
