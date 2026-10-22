# Si el adopt de Ajustes se queda esperando a iCloud antes del claim, cierra la sesión que abrió

## Contexto
Acaba de mergear a `2.1` el PR #230 (`adopt-exit-keeps-the-session-it-opened`): si cancelas o se rinde la entrada en tu cuenta de la nube, la sesión que se abrió para eso se cierra. Residual de esa review (lente de tiempos): en Almacenamiento, si «Activar la nube en este dispositivo» vence la espera de quiescencia de iCloud *antes* de llegar al claim, la tarjeta vuelve al idle pero la sesión firmada se queda. En «Migrar» ese mismo caso sí cierra (`closeSessionIfOpened`). En la bienvenida ese caso se deja vivo a propósito porque «Retomar» lo reusa. Ticket: `tickets/backlog/settings-adopt-stalled-before-the-claim-keeps-the-session.md` (low).

## Que se pide
1. Medir el camino (rama adopt de `continueToClaim` cuando `submit(.signInSucceeded)` vence quiescencia): confirmar que la sesión queda abierta y que la marca de ownership se retira (`withdrawAdoptSessionOwnershipIfNotStarted`).
2. **Decisión ya tomada (Frank, noche, opción robusta):** alinearse con «Migrar» **solo en Ajustes / Almacenamiento** — si la llamada del adopt no llegó al claim por esa parada, cerrar la sesión que se abrió y dejar un mensaje claro en la tarjeta (no dejar al usuario con una sesión “fantasma” de Grupos). **No** cambiar el comportamiento de la bienvenida (ahí «Retomar» necesita la sesión).
3. Implementar, tests + mutantes del camino tocado, gate, PR a `2.1`, merge, actualizar ticket → done (o qa solo si de verdad hace falta device-QA; este camino no se monta a voluntad → done sin device-QA está bien), `docs/TICKETS.md` al día, `/cerrar-total`.
4. Bugs/decisiones nuevas de camino → ticket propio antes de cerrar (`--solo-crear` / fichero en `tickets/`).

## Que NO hay que tocar
- marketing/, Web/
- El camino de bienvenida / «Retomar» que reusa la sesión tras un stall pre-claim
- Schema de sync / migraciones de modelo salvo que el ticket lo pida de verdad (la marca de ownership ya vive en UserDefaults)
- Relanzar tickets ya en `qa` o `done`

## Como se sabe que esta bien
- En Almacenamiento, si el adopt se para antes del claim por iCloud que no asienta, la sesión que se abrió se cierra; al siguiente arranque esa cuenta no queda registrada como Grupos por ese intento.
- La bienvenida sigue pudiendo «Retomar» con la sesión viva en el mismo caso.
- Tests cubren el desvío Ajustes vs bienvenida; mutantes del camino muerto; gate verde; PR mergeado a `2.1`; ticket y `docs/TICKETS.md` al día; `/cerrar-total`.

## MODO AUTÓNOMO HASTA TERMINAR
Bypass. Implementa de punta a punta: gate, commit, docs/board del repo, actualizar `docs/TICKETS.md`, merge y `/cerrar-total` sin preguntar si corre el gate o el commit. La regla del repo «espera aprobación si >3 ficheros» / «¿Sigo?» tras el plan queda **suspendida** en este encargo: sigue sin pedir OK para continuar. Bugs/decisiones nuevas → ticket propio antes de cerrar. Solo parar ante decisión/acceso real que no puedas asumir. Board de proyectos: create/move directo (sin inbox Tim). Noche Lima (01:xx): elige la opción robusta anotada arriba; no despiertes a Jürgen por preferencias reversibles.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL y key en fichero local, no en git; no las escribas en el repo) cuando:
  (1) necesitas una decisión de producto o de acceso de Jürgen;
  (2) abriste el PR o dejaste preview/artifact listo;
  (3) terminaste el ticket y vas a /cerrar-total — incluye en el aviso un resumen corto de cierre en lenguaje de usuario (qué se hizo), no solo «cerré»;
  (4) acabaste un tramo y no tienes siguiente paso claro (aunque no haya pregunta formal) — una vez, no en bucle.
NO avises por: un test rojo que vas a reclasificar, un build que vas a reintentar, ni ruido de CI advisory. URL/key solo en la Mini.

## Paso 0

Medido (2026-09-24, leído en el árbol de la rama):
- La rama adopt de `continueToClaim` solo la alcanza Ajustes (`StorageSettingsView` → `startMigration`). La bienvenida entra por
  `startAdoptWithExistingSession`, que no pasa por `continueToClaim`: el desvío Ajustes/bienvenida es estructural, no un flag.
- `MigrationRunner.submit` sale con `return` si `awaitQuiescence()` vence: journal en `authenticating`, sin claim.
  `withdrawAdoptSessionOwnershipIfNotStarted` retira la marca (`stoppedBeforeTheClaim`) y la sesión firmada se queda.

Decisiones (autocontestadas, noche):
1. **Cerrar solo la sesión que abrió el intento** (`closeSessionIfOpened(openedSession)`), igual que «Migrar». La sesión de Grupos
   reusada (`.useLiveSession`) no se toca.
2. **El predicado es el mismo que retira la marca** (`withdraw…` devuelve si paró antes del claim): una sola definición de «no
   llegó al claim». Con el journal ilegible no decide, como hoy.
3. **Aviso siempre que para**, abriera o no la sesión (como «Migrar»), así que el texto no habla de la sesión.
4. **Texto por motivo, elegido por la señal que produjo la parada**: con el import de iCloud aún sin asentar, frase nueva
   (`storage.errors.adoptICloudNotSettled`); si no, el genérico. No se reusa `groups.errors.syncPreparing` («unos segundos»: la
   espera vencida son 120 s).
5. El runner se queda en `authenticating`, como en «Migrar»: sin `submit(.signInFailed)`, que esperaría otros 120 s.
6. Device-QA no: el camino no se monta a voluntad. Ticket a `done`.
