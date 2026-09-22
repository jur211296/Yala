# Reloj por causa en el techo pre-mount de la vuelta a iCloud

## Contexto
Ticket: `tickets/backlog/reverse-pre-mount-ceiling-charges-a-stall-to-whoever-stops-it-last.md`
Hermano de `reverse-verify-network-bucket-hides-a-definitive-server-no` (PR #209 mergeado a 2.1).
Hoy `observeReversePreMountStall` junta tiempo de FASE con causa de ESTA observación: un `.localFailure` aislado tras horas de red aplica el techo corto (900 s) a las horas acumuladas y saca de la vuelta sin reintento.

### Decisiones YA TOMADAS (Jürgen 2026-09-22) — no reabrir en Paso 0
1. **Reloj por causa** (no histéresis): el techo corto solo cuenta tiempo acumulado bajo ESA causa. Toca schema/journal.
2. **Un solo mecanismo para los cinco motivos** (no reglas distintas servidor vs local): reloj por causa para todos. Norma Jürgen: siempre la opción más robusta / buena práctica, nunca la más simple.
3. El residual hermano `verify-reads-a-failed-local-fetch-as-an-empty-outbox` (ambos: no improvisar con outbox ilegible + cortar verify) **NO va en este encargo**; se lanza en serie después del merge de este.

## Que se pide
1. Implementar reloj por causa en el techo reverse pre-mount (schema según haga falta).
2. Cumplir los criterios de aceptación del ticket (localFailure aislado reintenta; 403 repetido sale a 900 s de parada REAL con esa causa; red pura conserva techo largo; cambio de fase reinicia; test de siembra larga + observación con otra causa).
3. Gate completo → commit → PR a `2.1` → merge → `/cerrar-total`.
4. Actualizar ticket + `docs/TICKETS.md` en el cierre.

## Que NO hay que tocar
- marketing/
- El residual del outbox (`verify-reads-a-failed-local-fetch-as-an-empty-outbox`) — otro encargo
- No relajar el techo largo de red pura ni el 401 (salvo lo que el ticket ya acota)

## Como se sabe que esta bien
Criterios del ticket en verde + gate + PR mergeado a 2.1 + `/cerrar-total` limpio.

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board del repo, `docs/TICKETS.md`, merge y `/cerrar-total` sin preguntar si corre el gate o el commit. Bugs/decisiones nuevas → ticket propio antes de cerrar. Solo parar ante decisión/acceso real que no cubra la norma «siempre lo más robusto». De día (06:00–21:00 Lima) puedes AskUserQuestion a Jürgen solo si aparece decisión de producto/acceso NUEVA no cubierta arriba.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL y key en fichero local, no en git; no las escribas en el repo) cuando:
  (1) necesitas una decisión de producto o de acceso de Jürgen;
  (2) abriste el PR o dejaste preview/artifact listo;
  (3) terminaste el ticket y vas a /cerrar-total — incluye resumen corto de cierre en lenguaje de usuario;
  (4) acabaste un tramo y no tienes siguiente paso claro — una vez, no en bucle.
NO avises por: test rojo que vas a reclasificar, build a reintentar, ni ruido de CI advisory.
