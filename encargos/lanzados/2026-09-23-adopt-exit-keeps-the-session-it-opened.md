# Si cancelas o se rinde el adopt, cierra la sesión que abrió

## Contexto
PR #229 acaba de mergear a `2.1`: la bienvenida del adopt ya dice el motivo del fallo y tiene «Cancelar la activación». Ese cancelar (y la flecha desde el error) todavía dejan la sesión abierta — el mismo agujero que ya cubre este ticket para el techo y el cancelar desde Almacenamiento.

Ticket: `tickets/backlog/adopt-exit-keeps-the-session-it-opened.md` (medium). Decisión de Jürgen 2026-09-23 ya anotada en el ticket:

**A:** al cancelar o al rendirse el techo, cerrar la sesión que abrió el adopt (alineado con Migrar / `closeSessionIfOpened`). La reentrada por la marca (`AdoptClaimScope.offersReentry`) sigue disponible.

También lo alcanza el «Cancelar la activación» nuevo de la bienvenida (#229): al confirmar, vuelve al chooser con la sesión todavía abierta.

Horario Lima ~23:42 (nocturno 21:00–6:00): no uses AskUserQuestion. La decisión ya está tomada. Si surge otra decisión de producto/acceso demasiado importante para asumir, aparca en ticket propio y sigue con lo que sí está decidido. No despiertes a Jürgen.

## Que se pide
Implementar la decisión A en todos los caminos del adopt donde hoy se sale sin cerrar la sesión abierta por el adopt:
- cancelar (Almacenamiento y bienvenida)
- rendición por techo
- cualquier otra salida terminal del adopt que hoy deje la sesión puesta

Criterio: al salir, la sesión que abrió el adopt queda cerrada; en el siguiente arranque no se registra sola como cuenta de Grupos. La reentrada por la marca sigue funcionando sin sesión.

Alinea con el cierre que ya hace Migrar via `closeSessionIfOpened`. Cubre también el cancelar de la bienvenida del #229 (nota en el ticket).

Tras el fix: gate, tests/mutantes según el patrón del lane, actualizar ticket + `docs/TICKETS.md`, PR a `2.1`, merge y `/cerrar-total`.

## Que NO hay que tocar
- marketing/, Web/
- No reabrir la decisión A ni proponer la opción opuesta
- No inventar copy nuevo salvo que el cierre de sesión lo exija de verdad (y entonces frases alineadas con Almacenamiento / vecinas)
- No tocar tickets low de copy (`welcome-adopt-cancel-dialog-says-from-here`) ni el técnico low (`welcome-adopt-exit-offers-retry-on-a-blocked-account`) salvo hallazgo de camino → ticket propio
- No schema nuevo si se puede cerrar con lo que ya hay
- No device-QA obligatorio: este camino no se monta a voluntad; a `done` sin iPhone si el gate y la evidencia de tests bastan (como #226–#229)

## Como se sabe que esta bien
- Cancelar o rendirse el adopt cierra la sesión que abrió; reentrada por marca sigue disponible
- Bienvenida: «Cancelar la activación» también cierra esa sesión al confirmar
- Gate verde; mutantes del cambio muertos o equivalentes documentados
- Ticket a `done`, `docs/TICKETS.md` al día, PR mergeado a `2.1`, `/cerrar-total`

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board del repo (mover ticket + actualizar `docs/TICKETS.md`), merge y `/cerrar-total` sin preguntar si corre el gate o el commit. Bugs/decisiones nuevas → ticket propio (`--solo-crear` / fichero en tickets/) antes de cerrar; no dejarlos solo en ESTADO. Board: create/move directo en tickets/ (sin inbox Tim).

OVERRIDE (Jürgen 2026-09-22): la regla del repo «espera aprobación si >3 ficheros» / «¿Sigo?» tras el plan queda SUSPENDIDA en este encargo. Implementa hasta gate/PR/merge/`/cerrar-total` sin pedir permiso para continuar. Solo para ante decisión/acceso real no cubierto (de noche: aparca).

Avisos al bot dueño (Frank): POSTea al webhook local de la Mini (URL y key en fichero local, no en git; no las escribas en el repo) cuando:
  (1) necesitas una decisión de producto o de acceso de Jürgen;
  (2) abriste el PR o dejaste preview/artifact listo;
  (3) terminaste el ticket y vas a /cerrar-total — incluye en el aviso un resumen corto de cierre en lenguaje de usuario (qué se hizo), no solo «cerré»;
  (4) acabaste un tramo y no tienes siguiente paso claro (aunque no haya pregunta formal) — una vez, no en bucle.
NO avises por: un test rojo que vas a reclasificar, un build que vas a reintentar, ni ruido de CI advisory. URL/key solo en la Mini.

## Paso 0

Decisiones resueltas antes de tocar código (sesión nocturna: auto-contestadas, ninguna es de producto — la de producto, A, ya estaba tomada).

1. **¿Qué sesión es «la que abrió el adopt»?** La que firmó el propio intento: en Almacenamiento, el camino que autentica
   (`startMigration` → `continueToClaim(…, sessionOpenedByThisAttempt: true)`); en la bienvenida, la que firmó ESA pantalla
   (`ensureSignedIn`, también la del alta que acaba en `existing_stable`). **No** lo es la sesión que ya estaba: la de Grupos
   con «Activar la nube en este dispositivo» por `.useLiveSession`, ni la que trae la puerta de Grupos al cover del adopt
   (`adoptCompleteAccountFromGroups`, que salta el sign-in). Esa no se cierra nunca, como en Migrar.
2. **¿En memoria o durable?** Durable. El techo del efecto son 72 h y casi siempre vence tras un relanzamiento (el resume del
   arranque), y la cancelación puede llegar días después. En memoria —el molde de `migrationAttempt`— solo cubriría el caso
   raro. Sin schema: una key de `UserDefaults` (`cloudSync.adoptSessionOwnedAccountHash`) con el hash de la cuenta que abrió
   el intento, el mismo hash del faro que ya usa `adoptClaimAccountHash`.
3. **¿Quién la escribe?** Cada inicio de un intento que va al claim de la ida, ANTES de conducir el runner (la primera
   pasada hace el claim y hasta el efecto dentro de un solo `submit`: un kill ahí dejaba el adopt sin marca). El adopt que
   abrió su sesión apunta su cuenta; el que no, la conserva solo si ya describe la sesión viva (un «Retomar» tras relanzar),
   y si no la borra. «Migrar» la borra. Si la llamada vuelve sin entrar en el claim, se retira: su `authenticating`
   normalizado se leería como salida y la bienvenida perdería la sesión de su «Retomar».
4. **¿Quién cierra, y cuándo?** El controller, por NIVEL, tras `resume`, `pollLeader` y `cancelMigration`, y al empezar
   `resumeIfNeeded` (el arranque y el re-kick). Con la marca puesta, «salió» es `failedRollback` (el techo de cualquier paso)
   o `notStarted` sin el efecto pendiente (toda cancelación, también la del líder de un adopt que contestó `created`, que no
   deja `adoptClaimExit`). La nube persistida es el éxito y olvida la marca. Solo cierra la sesión de ESA cuenta; sin
   sesión legible no decide. El cierre reusa `closeSessionIfOpened(true)`: sigue habiendo un solo `signOut` en el controller.
5. **La marca describe una SESIÓN, no una cuenta**: `CloudAuthService` la borra en cada sign-in y sign-out. Sin eso, una
   sesión de Grupos firmada después con la misma cuenta la heredaba (hallazgo de la review).
6. **Reentrada**: `offersReentry` sin sesión devuelve `true` y `blocksReentry` sigue atando la cuenta. El «Reintentar» de
   `.adoptExit` vuelve a firmar, y el «Retomar» de la bienvenida sin sesión también (`runFlowAfterConsent`).
7. **El registrador de Grupos no registra la sesión de un adopt** (`AdoptSessionOwnership.ownsLiveSession`). Lo cazó la
   review: `signOut` espera antes de borrar la sesión, y en el arranque el registrador podía llegar antes. De paso cierra el
   caso del arranque a MITAD del adopt, que había anotado como ticket aparte: ya no hace falta.
8. **Review adversarial**: sí (sesiones y sync). **Device-QA**: no, como #226–#229: el camino no se monta a voluntad.
