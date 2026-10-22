# Con el drain de Grupos atascado y filas de otra cuenta esperando en el outbox, el aviso nombra las dos causas y los cierres ofrecen perderlas (decisión A de Jürgen)

## Contexto
Ticket: `tickets/backlog/stuck-groups-drain-hides-held-rows-of-another-account.md` (léelo entero; las coordenadas son del 2026-10-05, re-mídelas).
Caso raro, dos fallos a la vez: en el teléfono hay cambios de grupos apuntados con OTRA cuenta ya preparados en el outbox (`held`) y además el drain no consigue capturar algún cambio propio (`captured == .stuck`). Al cerrar sesión, desasociar o «Empezar de cero», `CloudSignOutFlowLogic.stuckCaptureVerdict` no recibe `held` y sale solo `.groupsCaptureUnfinished`; la persona lo arregla, reintenta y recién ahí le sale «otra cuenta». No se pierde nada, pero las causas salen de una en una.

Decisión de Jürgen (2026-10-05, tarjeta `tablero-decidir-con-el-drain-de-grupos-atascado-7jg7`): **A.** `stuckCaptureVerdict` recibe también `held` y, con filas ajenas, devuelve `.groupsChangesFromAnotherAccount`. En el desasociar sale el aviso de dos causas que ya existe (`DetachBlockedNotice.alsoCaptureUnfinished(.otherAccount)` o su gemelo correcto); en los cierres de sesión y en «Empezar de cero» se ofrece perder (filas ajenas + lo atascado) con la cifra exacta. Jürgen quiere siempre lo más robusto y la mejor práctica, aunque tarde más.

Antecedentes que ya están o están entrando en `2.1`:
- PR #364 (mergeado): desasociar con el drain atascado y otra causa dice las dos en un solo aviso.
- PR #365 (en cola de auto-merge): «Empezar de cero» cuenta también las entradas del espejo de grupos de otra cuenta (`MirrorPendingScope.wholeMirror` / `.anotherAccount`, `freshStartResidualReason`). Toca los mismos ficheros (`CloudSessionSignOut`, `CloudSignOutFlowLogic`, `GroupsSyncClient`): construye encima, no lo deshagas.

Relacionado y SIN decidir (no lo implementes, solo no lo rompas): `fresh-start-copy-for-another-accounts-group-changes-borrows-the-own-reason` (matices de copy de #365) y `groups-kept-by-the-late-notice-are-purged-by-the-welcome-fresh-start`.

## Qué se pide
1. Medir en el código de hoy (tras el rebase sobre #365) el caso: filas ajenas en el outbox + captura atascada + ciclo sano, en los tres gestos (cerrar sesión, desasociar, «Empezar de cero»).
2. Implementar la decisión A en los tres gestos. Cifra exacta de lo que se perdería (filas ajenas + lo atascado), y lo aceptado cubre exactamente eso; algo que llegue después vuelve a parar. Si hace falta texto nuevo, en los 16 locales (es-AR voseo, es-ES pretérito perfecto, español neutro en el resto), sin inventar plazos; preferible reusar textos existentes si dicen la verdad.
3. Tests: rojo medido antes del fix, verde después, mutantes que importen, controles (sin filas ajenas, sin atasco, sin sesión).
4. Review adversarial con lente de datos y lente de verdad del copy.
5. Hallazgos nuevos → tickets en `tickets/backlog/`; device-QA si aplica → guion en `tickets/qa/` y tarjeta del tablero a `in qa`; si no aplica, tarjeta a `done`. La tarjeta es `tablero-decidir-con-el-drain-de-grupos-atascado-7jg7`.
6. Si el cambio se ve en pantalla, deja `capturas/antes.png` y `capturas/despues.png` en el worktree y lista las rutas en el resumen.

## Qué NO hay que tocar
- No cambies la decisión B2 del cierre de sesión ni del desasociar más allá de este caso.
- Nada de marketing/, nada de servidor ni migraciones de Supabase.
- No implementes los dos tickets relacionados sin decidir.

## Pipeline en la Mini (serial, obligatorio)
1. Limpiar: sims muertos, DerivedData de sesiones ya cerradas, cachés de XcodeBuildMCP de worktrees que ya no existen. Sin preguntar.
2. Build con `xcodebuild -jobs 2` sin simulador booteado.
3. Boot de 1 solo simulador.
4. Tests.
5. Apagar y borrar ese simulador.
Prohibido solapar swift-frontend + SpringBoard + app + UITests.

DerivedData y cachés de XcodeBuildMCP: al lanzar y al cerrar, borra el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees retirados o con PR ya mergeado. No preguntes. No toques los de un worktree vivo. Si el borrado falla, dilo en el cierre.

Gate después del CI del PR anterior: la sesión arranca ya, sobre `origin/2.1`. Justo antes del gate, mira si el PR #365 sigue en CI. Si sigue, espera a que entre y rebasa una sola vez, con el simulador apagado. Si `2.1` no se movió, sigue de frente. Si ese CI falla, no esperes: rebasa con lo que haya y sigue. El build y el simulador van después de ese rebase, una sola vez.

## Cómo se sabe que está bien
- Con filas ajenas en el outbox y la captura atascada, el aviso nombra las dos causas; en cierres y «Empezar de cero» se ofrece perder con la cifra exacta; en desasociar sale el aviso de dos causas sin salida.
- Sin filas ajenas, o sin atasco, el comportamiento no cambia.
- Gate verde (builds sin warnings nuevos, unit completa, XCUITest de las áreas tocadas, centinela 0), salvo rojos conocidos con ticket.
- PR abierto contra `2.1` y cierre con `/cerrar-total` en modo cola (autónomo, auto-merge, sin esperar CI). Al cerrar, la Mini queda limpia: sim apagado y borrado, DerivedData y cachés de esta sesión fuera, worktree retirado, tmux muerta.

## Paso 0

Medido el 2026-10-05 sobre la rama del PR #365 (`2a6130c3a`): con filas de otra cuenta en el outbox, la captura atascada y un
ciclo sano, `pushAllPendingGroupsForSignOut` lee `held` (línea 2528) pero `stuckCaptureVerdict` no lo recibe, y sale
`.groupsCaptureUnfinished` en los tres gestos (comparten ese push-all).

Decisiones (autónomo; ninguna es de producto más allá de la A de Jürgen):

1. **Qué cuenta como «cambios de otra cuenta»**: filas retenidas en el outbox (`held > 0`), o un History que apunta a otra
   cuenta: todo lo de fuera ajeno o sin dueño (el criterio de siempre), o algo de otra cuenta CONCRETA según el registro de
   sesiones. Asumido: es el mismo caso que la decisión A nombra. *Corregido tras la review (lente de datos)*: la primera
   versión aceptaba un solo cambio «sin dueño» mezclado con propios, y ese ruido de la sonda abría la salida a un teléfono sano.
2. **El orden no cambia**: un ciclo que paró sin App Attest o sin sesión sigue mandando (su salida ya cubre todo).
3. **History ilegible o recuento de filas ajenas fallido**: no abren la salida; sale el atasco, sin salida. *Corregido tras la
   review*: la primera versión ofrecía la pérdida sin cifra, y lo aceptado sin cifra cubría también lo propio apuntado después.
4. **El texto**: el aviso nombra las dos causas cuando lo que se ofrece perder incluye cambios que el drain no capturó
   (`uncaptured != []`) y la causa es otra cuenta. Textos nuevos en cierres (Ajustes y hoja del Apple ID), puerta de Grupos
   del Welcome (al invitado, sin salida, el texto de dos causas del desasociar) y «Empezar de cero». Cada uno dice qué sube
   cada parte: lo tuyo, reabriendo Yala y volviendo a intentarlo; lo de la otra cuenta, solo entrando con ella. En el desasociar se reescribe el gemelo de #364: decía «algunos **de ellos**» (los de la
   otra cuenta), falso cuando lo atascado es tuyo; el nuevo es verdad en los dos casos. Sesión caducada y attest no cambian.
5. **Capturas**: no se pueden sacar. El estado exige el drain atascado y filas de otra cuenta, y no hay seam de XCUITest que
   lo monte. Va a device-QA con guion.
