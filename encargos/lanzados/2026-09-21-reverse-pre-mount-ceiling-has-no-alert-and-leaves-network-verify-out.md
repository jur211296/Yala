# reverse-pre-mount-ceiling: alerta al disparar + verify/red dentro del techo

## Contexto
Residual de PR #199 (`reverse-before-mount-has-no-way-to-abandon-the-return`). Ticket:
`tickets/backlog/reverse-pre-mount-ceiling-has-no-alert-and-leaves-network-verify-out.md` (low).

Cola A en serie tras merge de #200 (`abandoned-restore-no-longer-clears-the-session-window-clock`).
No adelantar otros tickets.

## Decisión Jürgen (2026-09-21) — YA CERRADA, no repreguntar
1. **El techo avisa en el momento** (alerta al disparar; no silencio). Usar el molde `ReverseClaimExit` + `announce…` / `recordReverseClaimExit` para que NO se confunda con la nota de un intento anterior.
2. **`reverseVerify` + red pura entra al techo nuevo** — no queda fuera del techo pre-montaje. La IDA (`verify` compartido) NO debe cambiar de comportamiento; fija con test.

## Qué se pide
Implementar las dos piezas según criterios del ticket:
- Alerta al disparar el techo (toque y re-kick), sin ambigüedad con intento anterior.
- Incluir verify+red en el techo pre-montaje separando el trato de la IDA en `verify()` si hace falta.
- Tests (unit + mutantes según reglas del área), build verde, docs/board del repo al día (`tickets/` + `docs/TICKETS.md` + ESTADO si aplica).
- PR a `2.1`, merge cuando el gate pase, `/cerrar-total`.

## Qué NO hay que tocar
- marketing/, Web/
- No reabrir la decisión de producto.
- No absorber de paso los residuales nuevos de #200 (`restore-timeout-closes-the-session-window-with-the-import-still-running`, `restore-error-state-is-never-reached`) salvo que surjan bugs de camino propios — esos van a ticket propio, no a este PR.

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board del repo, actualizar `docs/TICKETS.md` (índice al día), merge y `/cerrar-total` sin preguntar si corre el gate o el commit. Bugs/decisiones nuevas → ticket propio (`--solo-crear` / fichero en tickets/) antes de cerrar. Solo parar ante decisión/acceso real de Jürgen. Board Yala = `tickets/` + `docs/TICKETS.md` (no inbox Tim).

## Día (6:00–21:00 Lima)
Puedes AskUserQuestion a Jürgen solo si aparece una decisión de producto/acceso NUEVA no cubierta arriba. Si no, sigue.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL y key en fichero local, no en git; no las escribas en el repo) cuando:
  (1) necesitas una decisión de producto o de acceso de Jürgen;
  (2) abriste el PR o dejaste preview/artifact listo;
  (3) terminaste el ticket y vas a /cerrar-total — incluye en el aviso un resumen corto de cierre en lenguaje de usuario (qué se hizo), no solo «cerré»;
  (4) acabaste un tramo y no tienes siguiente paso claro (aunque no haya pregunta formal) — una vez, no en bucle.
NO avises por: un test rojo que vas a reclasificar, un build que vas a reintentar, ni ruido de CI advisory. URL/key solo en la Mini.

## Como se sabe que esta bien
Criterios del ticket marcados; IDA sin cambio de comportamiento (test); alerta no confunde con intento anterior; PR mergeado a 2.1 y `/cerrar-total` completo con board/índice al día.

---

## Paso 0 — decisiones (resueltas en autónomo (bypass), 2026-09-21)

La decisión de PRODUCTO ya venía cerrada por Jürgen en el ticket (alerta al disparar; `reverseVerify` + red
dentro del techo). Lo que sigue son las decisiones de IMPLEMENTACIÓN que ese encargo deja abiertas, medidas
contra el árbol antes de escribir nada.

### D1 · ¿Un testigo NUEVO o se ensancha `lastReverseClaimExit`?
**Testigo nuevo, `ReversePreMountExit`, paralelo.** La regla de área describe el síntoma como «escribe
`reverseAbortReasonRaw` sin tocar `lastReverseClaimExit`», y eso invita a reusar el campo. Medido, reusarlo
obliga a renombrar el tipo, el campo y el helper (el nombre pasaría a mentir) y a reescribir los dos
source-scan que fijan sus cuerpos ENTEROS. El fichero ya tiene el precedente contrario y explícito:
`ForwardClaimRefusal` nace «molde de `ReverseClaimExit`» como struct **aparte**, con su `lastForwardClaimRefusal`
y su `announceForwardClaimRefusal`, y `resume()` ya toma DOS fotos y hace DOS avisos. Una tercera es la misma
forma. Riesgo descartado midiendo: dos salidas no pueden coincidir en una pasada, porque la primera devuelve
`false` y `drive()` corta.

### D2 · ¿Dónde se filtra `.cancelled`, que NO debe avisar?
**En el aviso, por `ReverseUploadWaitingCopyLogic.abortNote`.** `L10n.Storage.ReverseAbort.note(for:)` mapea
`.cancelled` al texto de `stalled`, así que sin filtro un «Cancelar y seguir en la nube» acabaría en una alerta
de error. El filtro ya existe y tiene nombre —es el mismo que decide si la tarjeta pone nota—, así que el
testigo se queda FACTUAL (registra toda salida, `.cancelled` incluida) y quién lo enseña lo decide un solo sitio.
La alternativa —no registrar `.cancelled`— pone la decisión de copy dentro del runner y hace que el testigo
mienta sobre cuál fue la última salida.

### D3 · ¿Qué pasa con la rama `.networkTimeout` de `reverseVerifyTransition` al mover el verify al techo?
**Pasa a `.invalid`.** Con el cambio, nada de producción emite ya `reverseVerifyOutcome(.networkTimeout)` desde
`reverseVerify` (comprobado: el único emisor era `driveReverseVerify`). Dejar la rama viva la convierte en una
rama muerta que afirma lo contrario del ticket —«la vuelta degrada a `reverseFailedRollback` por red»— y ningún
mutante la puede matar. `.invalid` es el patrón establecido del fichero para un par que deja de ser legal, se
fija con dos tests reescritos, y no toca la IDA.

### D4 · ¿Hace falta separar el trato de la IDA dentro de `verify()`?
**No, y se fija con test.** El encargo lo deja condicionado a «si hace falta». Medido: `driveVerify` y
`driveReverseVerify` son funciones distintas desde siempre, y la IDA ya agrupa
`.networkTimeout, .sessionExpired, .blocked` en su rama de red con el porqué escrito. Mover el verify de la
VUELTA no toca una línea de la IDA. Se añade el test que lo fija (`forwardVerify_networkTimeout_…`) en vez de
tocar el executor compartido.

### D5 · ¿En qué superficies sale la alerta?
**Las dos que ya usa `announceReverseClaimExit`: `startReverse` (el toque) y `resume` (Retomar + el re-kick de
30 s).** Son el criterio literal del ticket. `CloudMigrationController.cancelReverse()` NO avisa, y eso ya era
así: la salida la pidió la persona. En `startReverse` el aviso va en el MISMO `else` que el del claim: con una
salida pendiente el runner no empieza la vuelta, así que no puede haber salida nueva que anunciar y el aviso de
la pendiente manda.

### D6 · ¿Se absorbe la salida de la espera de subida, que tampoco avisa?
**No.** Está fuera del ticket y no es el mismo caso: esa salida sí deja efectos (`.rearmMirrorOff`), así que la
pantalla cambia visiblemente y la tarjeta de relanzar aparece. El silencio que este ticket cierra es el de la
salida con efectos CERO.
