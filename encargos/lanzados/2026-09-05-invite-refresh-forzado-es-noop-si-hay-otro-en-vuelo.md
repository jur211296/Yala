# El refresco forzado del invite deja de ser no-op cuando ya hay uno en vuelo (alerta falsa al recién instalado)

## Contexto
Cola autónoma Yala (Jürgen OK 2026-09-05, «dale como consideres»). Ticket backlog high:
`tickets/backlog/invite-refresh-forzado-es-noop-si-hay-otro-en-vuelo.md`.

Síntoma de usuario: recién instalado + enlace de invitación en frío → alerta «Hubo un problema
con el grupo…» falsa. Causa medida: `refreshIfDue(force: true)` sale por `inFlight` y no espera
al refresco del arranque; la re-lectura sigue con flag apagado y cae en `.backendUnavailable`.

Coords de partida (pueden estar caducadas — greppea, no abras la línea citada):
`CloudRemoteConfig.refreshIfDue`, `AppBootstrapper` handleInviteLink / paso 14.56,
`GroupInviteChannelRoutingLogic.route`.

MODO AUTÓNOMO HASTA TERMINAR: gate, commit, docs/board (mover ticket a qa cuando toque),
merge a 2.1 y /cerrar sin preguntar si corre el gate o el commit. Solo parar ante decisión
de producto o acceso real.

Secrets.xcconfig / secrets gitignored viven en el árbol principal, no en el worktree —
enlázalos antes del primer build. UI tests del CI en Yala son advisory; no bloquear merge
por el patrón flaky ya documentado en 2.1 — contrastar con la base. Tras pushes rápidos,
espera un solo run vivo sobre el HEAD final.

Avisos al bot dueño (Frank): POSTea al webhook local de la Mini (URL y key en fichero
local, no en git; no las escribas en el repo) cuando:
  (1) necesitas una decisión de producto o de acceso de Jürgen;
  (2) abriste el PR o dejaste preview/artifact listo;
  (3) terminaste el ticket y vas a /cerrar — incluye en el aviso un resumen corto
      de cierre en lenguaje de usuario (qué se hizo), no solo «cerré»;
  (4) acabaste un tramo y no tienes siguiente paso claro (aunque no haya pregunta
      formal) — una vez, no en bucle.
NO avises por: un test rojo que vas a reclasificar, un build que vas a reintentar,
ni ruido de CI advisory. URL/key solo en la Mini.

## Qué se pide
1. Lee el ticket y mide el estado actual en el árbol (coords pueden estar viejas).
2. Haz que el camino del invite con `force` no ignore un refresco en vuelo: o espera al
   in-flight y reutiliza su resultado, o equivalente que deje de emitir la alerta falsa
   cuando Groups ya está (o puede estar) bien. Alcance mínimo salvo incoherencia.
3. Tests que fijen el comportamiento (el force ya no es no-op silencioso con inFlight).
4. Gate verde local; PR a 2.1; merge cuando el check permita (UI advisory contrastado);
   docs/board; /cerrar con resumen de usuario.

## Qué NO hay que tocar
- No reinventar el routing de invites ni el fail-closed de flags en producción.
- No ampliar a invite-aasa / joiner residual / pending-member (otros tickets).
- No clinicas-dentales-bi. No marketing/.
- No subir SECONDARY_SESSION ni flips de release.

## Como se sabe que esta bien
- Con refresco de arranque en vuelo, el camino force del invite ya no cae en la alerta
  falsa de canal/grupo por no-op de inFlight (demostrado con test y/o medición).
- Gate local verde; PR mergeado a 2.1; ticket en qa (o done según convención del board);
  /cerrar con resumen en lenguaje de usuario.
