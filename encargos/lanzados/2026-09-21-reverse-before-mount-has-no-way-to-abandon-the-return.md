# reverse-before-mount-has-no-way-to-abandon-the-return — techo + cancelar + rollback + copy ReverseAbort

## Contexto
Cola A autónoma (serie). Acaba de mergear a 2.1 el PR #198 (force-fetch-and-wait-ignores-cancellation). Ticket en `tickets/backlog/reverse-before-mount-has-no-way-to-abandon-the-return.md`. Decisión Jürgen 2026-09-21 ya anotada en el ticket: **no repreguntar**.

## Qué se pide
Implementar la salida completa de las cuatro fases previas al montaje de «Volver a iCloud»:
1. **Techo automático y botón de cancelar** (las dos).
2. La salida hace **rollback al origen en modo nube**, molde de la salida de espera de `reverseUpload` / rechazo de claim — **sin** dejar `reverse_abort` pendiente que dispare en cada resume si no hay sesión.
3. **Copy** con molde `ReverseAbortReason` + `L10n.Storage.ReverseAbort.note(for:)`.
4. Criterios del ticket: ninguna de las cuatro fases sin salida indefinida con el motor parado; tests por motivo con mutante.

Mover el ticket a in-progress al arrancar; al cerrar actualizar `tickets/` + `docs/TICKETS.md`. Bugs/decisiones nuevas → ticket propio antes de cerrar.

## Qué NO hay que tocar
marketing/, Web/, otros tickets de cola salvo residuales reales de camino. No relanzar reverse-before-mount-stays-stuck (ya en qa).

## Como se sabe que esta bien
Criterios del ticket cumplidos; PR abierto; merge a 2.1; board/`docs/TICKETS.md` al día; `/cerrar-total`.

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board del repo, actualizar `docs/TICKETS.md`, merge a 2.1 y `/cerrar-total` **sin preguntar** si corre el gate, el commit, el merge o el cierre. **Nunca** preguntes «¿Mergeo?» ni esperes OK de Jürgen para merge/`/cerrar-total` tras abrir el PR. Device-QA pendiente no frena el cierre de sesión. Solo parar ante decisión/acceso real nuevo (no la decisión 2026-09-21 ya anotada).

## Día (6:00–21:00 Lima)
Puedes usar AskUserQuestion a Jürgen solo si surge una decisión de producto/acceso **nueva** no cubierta por el ticket. La salida techo+botón+rollback+ReverseAbort ya está decidida.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL y key en fichero local, no en git; no las escribas en el repo) cuando:
  (1) necesitas una decisión de producto o de acceso de Jürgen;
  (2) abriste el PR o dejaste preview/artifact listo;
  (3) terminaste el ticket y vas a /cerrar-total — incluye en el aviso un resumen corto de cierre en lenguaje de usuario (qué se hizo), no solo «cerré»;
  (4) acabaste un tramo y no tienes siguiente paso claro (aunque no haya pregunta formal) — una vez, no en bucle.
NO avises por: un test rojo que vas a reclasificar, un build que vas a reintentar, ni ruido de CI advisory.

## Paso 0 — decisiones (resueltas en autónomo, bypass; 2026-09-21)

Jürgen ya decidió el QUÉ en el ticket (techo automático **y** botón, rollback al origen en modo nube sin
dejar `reverse_abort` pendiente, copy con el molde de `ReverseAbortReason`). Lo que sigue es el CÓMO,
resuelto contra el árbol medido. **El árbol completo, con las mediciones que corrigieron cinco cifras del
propio ticket, vive en `## Paso 0` de
`tickets/in-progress/reverse-before-mount-has-no-way-to-abandon-the-return.md`** y viaja al PR desde ahí;
aquí va el resumen de una línea por nodo.

- **D1 · Fases:** las cuatro previas al montaje (`reverseClaimLeader`, `reverseDrainAll`, `reverseVerify`,
  `reverseFreezeBackend`). Ninguna es estable, así que con cualquiera journaleada el teléfono no sincroniza.
- **D2 · El reloj:** tiempo journaleado SIN AVANZAR, y avanzar es cambiar de fase pre-montaje. Dos campos
  nuevos (`reversePreMountProgressAt`, `reversePreMountPhaseRaw`), schema 6 → 7. Un sello futuro se re-sella.
- **D3 · Presupuestos:** los mismos dos que Jürgen ratificó el 2026-09-16 — 900 s si el servidor ya dijo que
  no, 259 200 s si no se sabe.
- **D4 · Hay que separar tres outcomes que hoy se colapsan en `.transient`**: el `other_leader` y el
  `rejected` del congelado y el 403 del drenaje y la verificación. Sin eso el techo corto es inalcanzable.
  `ReverseStepOutcome` y `VerifyProbe` ganan `.blocked(ReversePreMountBlocker)`; **la ida no cambia**.
- **D5 · La sesión caducada también tiene techo**, el largo: cubre la cuenta a la que ya no se puede entrar.
- **D6 · La salida va al origen SIN efectos de máquina**, y el `reverse_abort` se intenta DESPUÉS de
  journalear, una vez, best-effort. Es lo que pide el criterio 3: hoy ese efecto LANZA sin sesión, no se
  consume, y `hasPendingEffects` fuerza un resume que lo relanza en cada arranque.
- **D7 · El botón es el mismo**, con cuerpo de confirmación propio: pre-montaje no hay espejo que apagar, así
  que pedir cerrar y reabrir Yala sería falso.
- **D8 · Copy:** dos motivos nuevos (`preMountRefused` con el correo de soporte, `preMountStalled` sin él) y
  dos reusados (`otherDeviceReverting`, `cancelled`).
- **D9 · Canario** `cloudReversePreMountAborted`, detalle `<fase>|<motivo>`; el abort que no sale deja
  breadcrumb, no serie.
- **D10 · No se toca** el presupuesto S9 del verify, ni `execute(.reverseRollback)`, ni el `default:
  .transient` de `CloudAccountClient` — los tres los comparte la ida.
