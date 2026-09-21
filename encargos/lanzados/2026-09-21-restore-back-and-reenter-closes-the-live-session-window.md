# Salir de Restaurar y volver a entrar no puede apagar la ventana del intento vivo

## Contexto
Acaba de mergear a 2.1 el PR #195 (`restore-says-no-data-when-the-icloud-import-never-settled`): Restaurar ya distingue «iCloud tarda» de «no hay datos», y «Empezar desde cero» pregunta en desenlaces no concluyentes. Ese copy nuevo empuja el gesto salir→volver a entrar, y ahí cae este bug high medido en la review.

Ticket: `tickets/backlog/restore-back-and-reenter-closes-the-live-session-window.md` (léelo entero). Cola A serial: este es el siguiente tras el cierre del #195. Device-QA del #195 queda para Jürgen en iPhone — no es tu trabajo ahora.

## Que se pide
Que un flujo de Restaurar abandonado (atrás / desmontaje) **no apague** la ventana de sesión de restore de otro intento que sigue vivo. Criterios del ticket:
- Un flujo abandonado no apaga la ventana de otro que sigue vivo.
- El latch de `ICloudRestoreSessionSignal` deja de ser asimétrico (encendido idempotente + apagado incondicional que cierra sobre el dueño legítimo).
- El `forceFetchAndWait` abandonado no puede, al despertar del tope, tumbar el intento vivo.

Mueve el ticket a in-progress al empezar; al cerrar, board del repo + `docs/TICKETS.md` al día. Bugs/decisiones nuevas → ticket propio (`--solo-crear`) antes de /cerrar-total.

## Que NO hay que tocar
- marketing/ ni Web/
- Device-QA del restore-says-no-data (Jürgen, iPhone)
- No relanzar ni reabrir el ticket ya en qa `restore-says-no-data-when-the-icloud-import-never-settled`
- No tocar la decisión aparcada `reverse-before-mount-has-no-way-to-abandon-the-return` (necesita a Jürgen)

## Como se sabe que esta bien
Gate verde · mutantes del defecto original muertos · review · PR a 2.1 · merge · board + `docs/TICKETS.md` · `/cerrar-total`.

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board del repo, actualizar `docs/TICKETS.md` (índice al día), merge y `/cerrar-total` sin preguntar si corre el gate o el commit. Bugs/decisiones nuevas → ticket propio antes de cerrar. Solo parar ante decisión/acceso real. Board de proyectos Yala = `tickets/` + `docs/TICKETS.md` (create/move directo en disco).

## Horario (Lima)
**Nocturno (21:00–6:00):** elige lo recomendado sin AskUserQuestion a Jürgen. Si la decisión es demasiado importante para asumirla, aplaza el ticket (ticket propio / no inventar) y avisa por webhook.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL y key en fichero local, no en git; no las escribas en el repo) cuando:
  (1) necesitas una decisión de producto o de acceso de Jürgen;
  (2) abriste el PR o dejaste preview/artifact listo;
  (3) terminaste el ticket y vas a /cerrar-total — incluye en el aviso un resumen corto de cierre en lenguaje de usuario (qué se hizo), no solo «cerré»;
  (4) acabaste un tramo y no tienes siguiente paso claro (aunque no haya pregunta formal) — una vez, no en bucle.
NO avises por: un test rojo que vas a reclasificar, un build que vas a reintentar, ni ruido de CI advisory. URL/key solo en la Mini.
