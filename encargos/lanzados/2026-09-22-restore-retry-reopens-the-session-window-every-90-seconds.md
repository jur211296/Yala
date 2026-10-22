# Cerrar el ciclo «Reintentar» cada ~91 s que reabre la ventana de sesión sin descarga

## Contexto
Cierre limpio de PR #205 (`restore-session-window-has-no-reachable-ceiling`) mergeado a `2.1`. Ese PR cerró el recorrido de tres toques por la puerta de descarte; la review midió una vía **más barata** que queda abierta: en un teléfono cuyo corpus ajeno **ya se importó** (sin ningún `.importEvent` en el proceso), «Volver a buscar» tras el tope de 90 s estrena otros 60 s de gracia — un toque cada ~91 s, indefinidamente.

Ticket: `tickets/backlog/restore-retry-reopens-the-session-window-every-90-seconds.md` (medium). Residual hermano menor (no este turno salvo que salga de camino): `wiped-state-reaches-the-discard-gate-with-the-window-open`.

Rama base: `2.1`. Cola A seriada: este ticket solo; el siguiente lo lanza Frank tras `/cerrar-total` + merge.

## Decisión de producto (NOCHE · ya tomada por Frank — no AskUserQuestion)
Horario Lima ~00:35: modo nocturno. Opción recomendada del propio ticket, asumida:

**Un estreno que sigue a un `noteRestoreFinished` sin un solo import observado hereda/consume la gracia del proceso en vez de estrenarla de cero** — la gracia se cuenta **una vez por proceso**, no una por entrada. Así el ciclo reintentar-reintentar deja de mantener el guard abierto de forma continua.

Medir y cubrir con tests a quién deja fuera (quien enciende iCloud y reintenta con razón debe seguir teniendo ventana completa). Si al medir resulta que esa vía castiga al dueño legítimo de forma inaceptable, **no inventes otra política**: documenta la medición, aparca el ticket con la evidencia y cierra con residual propio — no despiertes a Jürgen de madrugada.

Anota la decisión en el ticket al arrancar.

## Qué se pide
1. Lee el ticket entero y el cierre de #205 / ESTADO (NOW 2026-09-22) para no reabrir el techo de cadena ni romper #204/#205.
2. Implementa la decisión de arriba con tests que midan el **veredicto del guard** (reloj), no solo el campo; recorre el ciclo reintentar→reintentar.
3. Criterios del ticket: (a) el ciclo deja de mantener el guard abierto de forma continua **o** queda escrito por qué se acepta; (b) el dueño legítimo que reintenta con razón sigue con ventana completa; (c) test con reloj.
4. Review adversarial + mutantes como en la serie restore.
5. Mueve el ticket backlog → in-progress → qa (con guion device-QA si aplica) y actualiza `docs/TICKETS.md`. Bugs/decisiones nuevas → ticket propio (`--solo-crear`) antes de cerrar.
6. PR a `2.1`, merge cuando el gate lo permita, docs/ESTADO al día, `/cerrar-total`.

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board del repo, actualizar `docs/TICKETS.md` (índice al día), merge y `/cerrar-total` **sin preguntar** si corre el gate o el commit. Solo parar ante decisión/acceso real que no puedas asumir (esta decisión de gracia ya está tomada). Board de proyectos Yala = `tickets/` + `docs/TICKETS.md` (create/move en disco). UI tests del CI en Yala son advisory; no bloquear merge por el patrón flaky documentado.

## Qué NO hay que tocar
- `marketing/` y Web/ (Lola).
- No reintroducir el techo de cadena que la review tumbó.
- No romper el aparcado de #205 ni el testigo de descarga viva de #204.
- No secretos en git.

## Como se sabe que esta bien
- Criterios del ticket en verde con tests.
- PR mergeado a `2.1`.
- Ticket en qa (o done si no hace falta QA manual) + `docs/TICKETS.md` al día.
- `/cerrar-total` limpio.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL y key en fichero local, no en git; no las escribas en el repo) cuando:
  (1) necesitas una decisión de producto o de acceso de Jürgen;
  (2) abriste el PR o dejaste preview/artifact listo;
  (3) terminaste el ticket y vas a /cerrar-total — incluye en el aviso un resumen corto de cierre en lenguaje de usuario (qué se hizo), no solo «cerré»;
  (4) acabaste un tramo y no tienes siguiente paso claro (aunque no haya pregunta formal) — una vez, no en bucle.
NO avises por: un test rojo que vas a reclasificar, un build que vas a reintentar, ni ruido de CI advisory. URL/key solo en la Mini.

## Paso 0 — decisiones (resueltas en autónomo (bypass), 2026-09-22)

El encargo ya trae la decisión de producto tomada («la gracia se cuenta una vez por proceso»). Lo
que queda son decisiones de diseño, y las contesto yo:

1. **¿Ancla de gracia propia, o heredar el reloj entero como hace el aparcado del descarte?**
   → **Ancla propia.** Heredar el reloj recorta también el tope duro, y el criterio (b) del ticket
   exige que el dueño legítimo que reintenta con razón conserve su **ventana completa** de 600 s.
   Con ancla separada lo único que no se renueva es la gracia.
2. **¿Fecha o `Bool` «la gracia ya se usó»?** → **Fecha.** Una búsqueda que se rinde a los 3 s sin
   eventos apaga la ventana en el acto, así que con un `Bool` su reintento perdería los 57 s que
   nadie gastó. Con la fecha la gracia es un presupuesto de 60 s repartido entre las entradas.
3. **¿`noteRestoreUnavailable()` tira también el ancla?** → **Sí**, por la misma razón por la que ya
   tira el aparcado: esa entrada declara que no puede restaurar nada, así que lo de antes no
   describe la descarga que venga. Es lo que le devuelve gracia completa a quien enciende iCloud y
   reintenta. No añade exposición: apagar/encender iCloud es más caro que matar la app, que ya es el
   baseline declarado de esta señal.
4. **¿`graceStartedAt` con valor por defecto en la lógica pura?** → **Sin default**, misma familia
   que `hasLiveImportActivity` y que el `restoreInProgress` de `CrossAccountEntryGuardLogic`: quien
   añada un call-site tiene que decidir de dónde sale, y lo comprueba el compilador.
5. **¿Ancla o reloj cuando los dos existen?** → **El más viejo (`min`)**, que es el sesgo
   fail-closed: la gracia se agota antes, nunca después.
6. **¿Device-QA?** → **Sí, a `qa`**: el efecto solo se ve con el reloj corriendo en un teléfono, y
   la serie restore lleva guion de pasos desde #203.

Detalle, medición de a quién deja fuera y la tabla de recorridos: en el `## Paso 0` del propio
ticket, que es de donde viaja al PR.
