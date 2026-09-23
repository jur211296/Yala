# Con dos motivos definitivos alternándose, la vuelta a iCloud sale en el techo corto, no a las 72 h

## Contexto
Cola A autónoma Yala, tras merge #221 (`adopt-claim-stays-parked-with-no-ceiling` → qa). Ticket `alternating-definitive-causes-never-reach-the-short-ceiling` (high, backlog). Quién arranca ARRANCA EN CONTEXTO LIMPIO.

Tras `verify-reads-a-failed-local-fetch-as-an-empty-outbox`, `reverseDrainAll` puede bloquear por `.localFailure` además del 403; con el reloj por causa, dos motivos definitivos que se turnan reinician el techo corto en cada observación y la persona acaba en el techo largo (72 h) en vez de los 15 min prometidos. El docblock de la máquina ya lo admite; el techo corto existe precisamente porque 72 h delante de algo definitivo es demasiado.

## Decisión (Frank, robusta — no preguntar)
Cerrar el agujero (opción 2 del ticket): un tercer reloj de «tiempo parado bajo CUALQUIER motivo definitivo» que no se reinicia al cambiar de causa definitiva. Debe preservar el criterio del reloj por causa: un `localFailure` aislado tras horas de espera por RED no cobra esas horas. Dejar escrito el porqué en el ticket / ESTADO.

## Que se pide
1. Leer el ticket y el código del reloj por causa / fase en la vuelta pre-mount (`MigrationRunner.reversePreMountCauseClock` y alrededores).
2. Implementar el tercer reloj (cualquier motivo definitivo) sin romper el caso «localFailure de una vez tras horas de red».
3. Tests que demuestren: dos definitivos alternándose alcanzan salida antes de 72 h; el caso de red→localFailure aislado no cobra las horas de red.
4. Gate, review, PR a `2.1`, merge, actualizar ticket + `docs/TICKETS.md` + ESTADO, `/cerrar-total`.
5. Bugs/decisiones nuevas → ticket propio antes de cerrar.

## Que NO hay que tocar
- marketing/, Web/
- Relojes de la ida / adopt salvo que el mismo agujero esté medido ahí (entonces ticket hermano, no ampliar alcance a ciegas)
- Device-QA de otros tickets en qa

## Como se sabe que esta bien
- Criterios del ticket cumplidos y documentada la decisión.
- Gate verde; mutantes del cambio muertos.
- PR mergeado a 2.1; ticket a done (o qa solo si hace falta device-QA real); `docs/TICKETS.md` al día; `/cerrar-total`.

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board del repo, actualizar `docs/TICKETS.md`, merge y `/cerrar-total` sin preguntar si corre el gate o el commit. Bugs/decisiones nuevas → ticket propio antes de cerrar. Solo parar ante decisión/acceso real de Jürgen.

OVERRIDE (Jürgen 2026-09-22): la regla del repo «espera aprobación si >3 ficheros» / «¿Sigo?» tras el plan queda SUSPENDIDA en este encargo. Implementa de cabo a rabo sin preguntar si sigues. AskUserQuestion solo para producto/acceso real (horario diurno Lima 6:00–21:00); esta decisión de techo ya está tomada arriba.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL y key en fichero local, no en git; no las escribas en el repo) cuando:
  (1) necesitas una decisión de producto o de acceso de Jürgen;
  (2) abriste el PR o dejaste preview/artifact listo;
  (3) terminaste el ticket y vas a /cerrar-total — incluye en el aviso un resumen corto de cierre en lenguaje de usuario (qué se hizo), no solo «cerré»;
  (4) acabaste un tramo y no tienes siguiente paso claro (aunque no haya pregunta formal) — una vez, no en bucle.
NO avises por: un test rojo que vas a reclasificar, un build que vas a reintentar, ni ruido de CI advisory. URL/key solo en la Mini.

## Paso 0 (Frank, 2026-09-23)

Decisiones, auto-contestadas (modo autónomo):

1. **Se cierra** (opción 2 del ticket), con un reloj de «tiempo parado bajo CUALQUIER motivo definitivo». Es
   `CauseStallClock` con una clave única para todo lo definitivo: suma entre motivos definitivos distintos, se PAUSA
   con una observación sin motivo (red, sesión) y se reinicia con el cambio de fase. La pausa es lo que conserva el
   criterio del reloj por causa: las horas de red no se le cobran a nadie.
2. **La máquina decide el techo corto con ese reloj, no con el de causa.** El de causa lo acota por debajo (todo lo
   que acumula un motivo lo acumula también «cualquier definitivo»), así que como término de salida sobraba. El
   evento `reversePreMountStalled` pasa su segundo reloj a llamarse `definitiveStalledSeconds`.
3. **El reloj por causa se queda, con un papel más estrecho: elige el COPY.** Si un solo motivo acumuló los 900 s, la
   salida lleva su texto (`preMountRefused` con el correo de soporte, `preMountOtherDevice`); si los 900 s salieron de
   motivos mezclados, `preMountStalled`. Es la regla «el motivo lo elige el techo que venció» aplicada al reloj nuevo:
   con causas mezcladas no hay un motivo único del que sea verdad el texto específico.
4. **Persistencia:** dos campos aditivos en `MigrationState` (`reversePreMountDefinitiveAt`,
   `reversePreMountDefinitiveAccruedSeconds`), schema 11 → 12. Sin clave cruda: solo hay una. Una fila vieja los lee
   `nil` y el reloj empieza cuando este build la mira (como mucho, un techo corto más en quien esté parado al
   actualizar).
5. **Canario sin cambios** (`cloudReversePreMountWaiting` es wire): sigue publicando el tramo por causa.
6. **Ida y subida del snapshot**: no se tocan. Si el mismo agujero se mide alcanzable allí, ticket hermano.
