# Si entrar en tu cuenta falla desde la bienvenida, mismos textos por motivo que Almacenamiento + Cancelar/atrás

## Contexto
Cola A autónoma (noche Lima). Acaba de mergear a `2.1` el PR #228 (`adopt-follower-waits-for-the-leader-with-no-ceiling`): la espera del seguidor ya tiene techo, aviso y «Dejar de esperar». Quedan callejones de adopt en la bienvenida.

Ticket: `tickets/in-progress/welcome-adopt-effect-failure-has-no-reason-and-no-cancel.md` (Frank ya lo pasó de backlog a in-progress en el árbol principal; alinea el worktree / `docs/TICKETS.md` si hace falta).

Hermanos: el techo y «Cancelar» del efecto ya existen en Almacenamiento (`adopt-effect-retries-forever-with-no-ceiling`, #226). En Welcome, `CloudWelcomeSignInFlow.phase` mapea `.failed` a error genérico de conexión sin mirar `adoptClaimExit`, y `canGoBack` es false en `.adopting`.

Decisión de producto ya tomada (Jürgen 2026-09-23, anotada en el ticket) — no reabrir:
**A:** mismos textos por motivo que en Almacenamiento (`adoptEffectLocalFailure` / `adoptEffectStalled`), más Cancelar o flecha atrás durante el efecto en la bienvenida.

## Que se pide
1. En el flujo de bienvenida al adoptar, cuando el efecto falla o se rinde, mostrar los mismos textos por motivo que en Almacenamiento (no el genérico «Revisa tu conexión» si la causa es local).
2. Durante `.adopting` en Welcome, ofrecer Cancelar o flecha atrás que cancele el efecto con el mismo camino que en Almacenamiento.
3. Tests / mutantes que fijen el mapeo de motivos y que Cancelar/atrás esté disponible en adopting.
4. Gate, PR a `2.1`, merge, board (`docs/TICKETS.md` + ticket a done si no pide device-QA; si pide QA en iPhone, a `qa` con guion), `/cerrar-total`.

## Que NO hay que tocar
- `marketing/`, Web/.
- No reabrir la decisión A.
- No ampliar a `adopt-exit-keeps-the-session-it-opened` salvo bug hermano inevitable descubierto de camino (en ese caso ticket propio; no lo implementes en este PR).
- No inventar schema ni copy nuevo si bastan las claves ya existentes del efecto.

## Como se sabe que esta bien
- Fallo local vs stalled en Welcome usan los textos de Almacenamiento.
- Durante el efecto en Welcome hay salida (Cancelar o atrás) que cancela de verdad.
- Tests en rojo si se vuelve al genérico de conexión o se quita la salida.
- PR mergeado a `2.1`; ticket e índice al día; `/cerrar-total`.

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board del repo, actualizar `docs/TICKETS.md`, merge y `/cerrar-total` sin preguntar si corre el gate o el commit. Bugs/decisiones nuevas → ticket propio antes de cerrar. Solo parar ante decisión/acceso real (noche: elige la opción robusta / recommended; si es demasiado importante para asumir, aplaza en ticket propio — no despiertes a Jürgen). La regla del repo «wait for approval if >3 files» / «¿Sigo?» tras el plan queda suspendida en este encargo: implementa hasta cerrar.

Avisos al bot dueño (Frank): POSTea al webhook local de la Mini (URL y key en fichero local, no en git; no las escribas en el repo) cuando:
  (1) necesitas una decisión de producto o de acceso de Jürgen;
  (2) abriste el PR o dejaste preview/artifact listo;
  (3) terminaste el ticket y vas a /cerrar-total — incluye en el aviso un resumen corto de cierre en lenguaje de usuario (qué se hizo), no solo «cerré»;
  (4) acabaste un tramo y no tienes siguiente paso claro (aunque no haya pregunta formal) — una vez, no en bucle.
NO avises por: un test rojo que vas a reclasificar, un build que vas a reintentar, ni ruido de CI advisory. URL/key solo en la Mini.

## Paso 0

Decisiones (auto-contestadas, MODO AUTÓNOMO, noche):

1. **Textos.** Fase nueva de pantalla `.adoptExit(AdoptClaimExit)` cuando la máquina falla (`.failed(.migration)`) con la
   marca del adopt puesta y distinta de `.cancelled`. El texto sale de la MISMA función que usa Almacenamiento
   (se extrae `StorageFailureCopyLogic.adoptExitMessage`), así que no hay copy nuevo ni forma de que diverjan.
   Asumido: cubre también las tres salidas del CLAIM (`stalled`/`sessionExpired`/`accountUnavailable`), no solo las
   dos del efecto: la decisión dice «mismos textos por motivo que Almacenamiento» y el claim tenía el mismo genérico.
   `claimBlocker` sigue ganando antes (sin cambio). Icono de aviso en vez del wifi; «Reintentar» y la flecha, como `.error`.
2. **Salida.** Botón «Cancelar la activación» bajo la barra en `.adopting`, con el MISMO predicado
   (`canCancelMigration`: efecto pendiente o claim del adopt), el mismo diálogo, el mismo cuerpo por fase y el mismo
   `controller.cancelMigration()` que Almacenamiento. Deshabilitado con trabajo en vuelo, como allí.
3. **A dónde lleva.** Al chooser (a donde lleva la flecha desde `.error`) solo cuando la cancelación ATERRIZÓ: `notStarted`
   + sin el pendiente del efecto + marca `.cancelled`. Corregido tras la review: la primera versión miraba solo
   `notStarted`, que también es el efecto antes de cancelar y el adopt terminado. El poll lo mira en cada vuelta y
   «Retomar» con la cancelación pedida reanuda, nunca re-reclama.
4. **Fuera:** cerrar la sesión al salir (`adopt-exit-keeps-the-session-it-opened`); la espera del seguidor en el Welcome.
5. Device-QA: no se monta en iPhone (hace falta un reconcile que falle 15 min); unit + mutantes. Ticket a `done`.
