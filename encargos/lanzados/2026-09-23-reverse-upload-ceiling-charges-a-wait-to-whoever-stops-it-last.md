# En la espera de subida a iCloud, un fallo pasajero no debe cobrar las horas que llevabas esperando por otra causa

## Contexto
Cola A autónoma (Yala / Frank). Acaba de mergear a `2.1` el PR #226 (`adopt-effect-retries-forever-with-no-ceiling`): el efecto del adopt ya tiene techo, texto y Cancelar. Ticket a done sin device-QA.

Este ticket es el **gemelo medido** de `reverse-pre-mount-ceiling-charges-a-stall-to-whoever-stops-it-last` (ya cerrado): en la espera de SUBIDA de la vuelta a iCloud, `observeReverseUploadWait` aplica el presupuesto de la causa ACTUAL al tiempo acumulado de cualquier causa. Un `.icloudUnusable` aislado tras horas sin cuenta iCloud cancela al instante. El mecanismo del gemelo (reloj por causa + techo largo por encima) ya está escrito y Jürgen ya decidió «un solo mecanismo para todos los motivos».

Arrancas en contexto limpio. Lee el ticket `tickets/backlog/reverse-upload-ceiling-charges-a-wait-to-whoever-stops-it-last.md`, el gemelo cerrado y la regla en `.claude/rules/swiftdata-cloudkit.md`.

## Que se pide
1. Reloj por causa en la espera de subida: el techo corto solo acumula bajo ESA causa (racha consecutiva), conviviendo con el re-sellado por avance real (la cifra de pendientes que baja reinicia los dos relojes).
2. El techo largo sigue por encima con cualquier causa (`fase >= 72 h OR causa >= 15 min`), para que dos causas definitivas que se alternen no re-sellen el corto indefinidamente.
3. Un `.icloudUnusable` aislado tras una espera larga por otra causa **reintenta al menos una vez** antes de cancelar.
4. Tests que fijen el reloj que decide (no solo el breadcrumb) + mutantes de la familia del techo.
5. Board del repo: ticket a in progress al empezar; al cerrar → done si no hace falta device-QA (este escenario no se monta a voluntad), o in qa si sí; actualizar `docs/TICKETS.md` e índice. Bugs/decisiones nuevas → ticket propio (`--solo-crear`) antes de `/cerrar-total`.

## Que NO hay que tocar
- marketing/, Web/.
- No relances tickets de producto que esperan a Jürgen: `welcome-adopt-effect-failure-has-no-reason-and-no-cancel`, `adopt-exit-keeps-the-session-it-opened`, `adopt-follower-waits-for-the-leader-with-no-ceiling`.
- No cambies el techo previo al montaje ya cerrado salvo que midas un acoplamiento real; si lo hay, ticket residual.

## Como se sabe que esta bien
- Criterios del ticket cumplidos con test que falle si el corto cobra tiempo de otra causa.
- Gate verde; review adversarial; PR mergeado a `2.1`; `/cerrar-total` con board y `docs/TICKETS.md` al día.

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board del repo, actualizar `docs/TICKETS.md`, merge y `/cerrar-total` sin preguntar si corre el gate o el commit. Bugs/decisiones nuevas → ticket propio antes de cerrar. Solo parar ante decisión/acceso real. Board de proyectos: create/move directo (sin inbox Tim).

OVERRIDE (Jürgen 2026-09-22): la regla del repo «espera aprobación si >3 ficheros» / «¿Sigo?» tras el plan queda **suspendida** en esta cola. Implementa hasta gate/PR/merge/`/cerrar-total` sin pedir continuar. Solo AskUserQuestion de producto/acceso real.

DÍA (ahora ~17:41 Lima, ventana 6:00–21:00): si hace falta una decisión de producto o de acceso de Jürgen, usa AskUserQuestion. Para técnica, elige la opción más robusta / good-practice (nunca la más simple).

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL y key en fichero local, no en git; no las escribas en el repo) cuando:
  (1) necesitas una decisión de producto o de acceso de Jürgen;
  (2) abriste el PR o dejaste preview/artifact listo;
  (3) terminaste el ticket y vas a /cerrar-total — incluye en el aviso un resumen corto de cierre en lenguaje de usuario (qué se hizo), no solo «cerré»;
  (4) acabaste un tramo y no tienes siguiente paso claro (aunque no haya pregunta formal) — una vez, no en bucle.
NO avises por: un test rojo que vas a reclasificar, un build que vas a reintentar, ni ruido de CI advisory.

## Paso 0 (2026-09-23, auto-contestado: modo autónomo, nada es de producto)

**D1 · ¿Dos relojes o tres?** → **Tres**, el molde VIGENTE de la familia, no el del día que se escribió este ticket.
Avance (72 h, cualquier motivo) · «cualquier motivo definitivo» (15 min) · causa (solo elige el texto). Por qué: el
encargo pide «reloj por causa + techo largo», pero dos tickets posteriores midieron que con el reloj de causa dos
motivos definitivos turnándose no vencen nunca el corto y la salida se va a 72 h
(`alternating-definitive-causes-never-reach-the-short-ceiling`, `snapshot-upload-alternating-…`). «Un solo mecanismo
para todos los motivos» es hoy ése, y los dos gemelos llaman a `CauseStallClock.observeAnyDefinitive`.

**D2 · ¿Racha consecutiva o acumulado?** → **Acumulado con pausa**. Por qué: la review del gemelo midió que el re-kick de
30 s vuelve inalcanzable una racha (900 / 30 = 30 observaciones sin un solo hueco). Lo que dice el encargo («racha») es
la versión que esa review tumbó.

**D3 · ¿Qué pausa?** → `icloudOff` y `unknown` pausan los dos acumulados; solo `icloudFull` e `icloudUnusable` suman. El
filtro es `stallCause`, el mismo que elige el presupuesto. Por qué: son la «red» de esta espera —no son un motivo que
esperar no arregla—, y es lo que hace que tres horas sin cuenta no las cobre el primer `icloudUnusable`.

**D4 · El avance.** → Una cifra que baja re-sella el reloj de avance y reinicia los otros dos; la misma observación abre
el tramo nuevo desde cero si trae motivo definitivo.

**D5 · Schema.** → `MigrationState` 14 → 15 con cinco campos aditivos y opcionales (`reverseUploadCause{Raw,At,AccruedSeconds}`,
`reverseUploadDefinitive{At,AccruedSeconds}`) y `clearReverseUploadCeiling()` para los siete `reverseUpload*`, en los
cinco sitios que hoy limpian el par a mano. Una fila v14 a mitad de espera empieza el corto desde que este build la mira.

**D6 · El texto de la salida.** → Lo elige el techo que venció: el específico solo si UN motivo agotó solo los 900 s; si
no, `stalled`. Sin texto nuevo: medido, `storage.reverseAbort.stalled` no afirma días ni motivo («iCloud no recibió todos
tus datos…»), así que es verdad también para motivos mezclados. No hay decisión de producto.

**D7 · Nombres.** → `reverseUploadUnknownBudgetSeconds` → `reverseUploadProgressBudgetSeconds` (ya aplica con cualquier
motivo). `reverseUploadDefinitiveBudgetSeconds` se queda: ahora se mide contra el reloj de lo definitivo y el nombre dice
la verdad. El predicado del corto, en la policy y en un solo sitio.

**D8 · Canario y rastro.** → `cloudReverseUploadWaiting` pasa a `stalled|<tramo de avance>|<tramo de causa>|<motivo>`
(`-` sin motivo definitivo); `advancing|<motivo>` no cambia. El rastro lleva los tres relojes. La serie cambia de valores.

**D9 · Techo previo al montaje.** → No se toca: comparten `CauseStallClock` y no lo cambio.

**D10 · Board.** → Sin device-QA: el escenario (horas sin iCloud y un `notAuthenticated` justo al entrar) no se monta a
voluntad en un iPhone. `done` al cerrar, con los tests como cobertura.

### Paso 0 revisado tras la review adversarial (2026-09-23)

**D8 (ampliada) · El canario de SALIDA.** → Una salida journaleada como `stalled` por el techo corto, con motivos
turnándose, publica `mixedCauses`; `stalled` sigue siendo solo las 72 h. Por qué: con un solo valor, un pico de `stalled`
no decía si era un mirror parado días o dos motivos que se turnan (lente de telemetría). El journal no cambia.

**D11 (nueva) · El hueco sin observar.** → No se toca aquí: ticket `stall-clock-charges-a-closed-app-gap-to-a-one-off-cause`.
Por qué: un tramo abierto sigue contando con la app cerrada en las cinco etapas que usan `CauseStallClock`, y cambiarlo
en una sola rompería «un solo mecanismo». Queda fijado con test también en esta espera.
