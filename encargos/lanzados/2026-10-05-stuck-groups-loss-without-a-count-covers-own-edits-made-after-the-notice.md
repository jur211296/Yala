# Con el drain de Grupos atascado y el History ilegible, no se ofrece perder «sin cifra» hasta poder contar (decisión A de Jürgen)

## Contexto
Ticket: `tickets/backlog/stuck-groups-loss-without-a-count-covers-own-edits-made-after-the-notice.md` (léelo entero; las coordenadas son del 2026-10-05, re-mídelas).
Caso rarísimo: el teléfono no consigue preparar algunos cambios de grupos (`GroupsExitCapture.stuck`) y además, justo al enseñar el aviso, no puede leer el History (`CloudSessionSignOut.groupsLossUncaptured` da `nil`). Si el ciclo paró por App Attest o por sesión caducada, el aviso «Cerrar sesión y perderlos» sale sin cifra; lo aceptado guarda `uncaptured: nil` y `CloudSignOutFlowLogic.lossHalfCovers(accepted: nil, now:)` cubre cualquier cosa, así que un gasto de grupo apuntado después del aviso y que tampoco se prepara se va con el cierre sin que nadie lo haya contado.

Decisión de Jürgen (2026-10-05, tarjeta `tablero-decidir-con-el-drain-de-grupos-atascado-mc0q`): **A.** Con la captura atascada y el History ilegible, no ofrecer la salida de perder: sale el aviso del atasco, sin salida, hasta que se pueda contar. Principio: la persona no puede aceptar perder lo que el aviso no le enseñó. Jürgen quiere siempre lo más robusto y la mejor práctica, aunque tarde más.

Antecedentes en `2.1` o entrando:
- PR #366 (mergeado): en el caso de otra cuenta, un History ilegible ya no abre la salida. Esta sesión extiende ese mismo criterio a los motivos del ciclo (App Attest, sesión caducada). Construye encima, no lo deshagas.
- PR #367 (en cola de auto-merge): aviso del Inbox cuando cambia el importe de una liquidación ya aprobada. Otra área (bridge de liquidaciones, `DraftService`), no debería chocar.

Relacionado y SIN decidir o fuera de esta sesión (no lo implementes, solo no lo rompas): `fresh-start-copy-for-another-accounts-group-changes-borrows-the-own-reason` (va en otra sesión de la cola), `stuck-groups-drain-with-another-account-and-a-cycle-reason-names-two-of-three-causes` (Jürgen decidió dejarlo como está).

## Qué se pide
1. Medir en el código de hoy el caso: captura atascada + History ilegible en la oferta + ciclo parado por App Attest o por sesión caducada, en los gestos que ofrecen perder (cerrar sesión en Ajustes, hoja del Apple ID, puerta de Grupos del Welcome, «Empezar de cero», y el desasociar si aplica).
2. Implementar la A: en ese caso no se ofrece la salida; sale el aviso del atasco, sin salida. Cuando el History vuelva a leerse, la salida vuelve con su cifra. Lo aceptado sin cifra no debe poder existir; si queda alguna aceptación vieja persistida con `uncaptured: nil`, que no cubra cambios nuevos.
3. Si el texto del atasco no dice la verdad en este caso, ajústalo en los 16 locales (es-AR voseo, es-ES pretérito perfecto, español neutro en el resto), sin inventar plazos; preferible reusar textos existentes si dicen la verdad.
4. Tests: rojo medido antes del fix, verde después, mutantes que importen, controles (History legible con cifra, sin atasco, attest/sesión con History legible).
5. Review adversarial con lente de datos y lente de verdad del copy.
6. Hallazgos nuevos → tickets en `tickets/backlog/`; device-QA si aplica → guion en `tickets/qa/` y tarjeta del tablero a `in qa`; si no aplica, tarjeta a `done`. La tarjeta es `tablero-decidir-con-el-drain-de-grupos-atascado-mc0q`.
7. Si el cambio se ve en pantalla, deja `capturas/antes.png` y `capturas/despues.png` en el worktree y lista las rutas en el resumen.

## Qué NO hay que tocar
- No cambies la decisión B2 del cierre de sesión ni del desasociar más allá de este caso.
- No cambies el orden de causas: un ciclo parado por attest o sesión con History legible sigue ofreciendo su salida con cifra.
- Nada de marketing/, nada de servidor ni migraciones de Supabase.
- No implementes los tickets relacionados de arriba.

## Pipeline en la Mini (serial, obligatorio)
1. Limpiar: sims muertos, DerivedData de sesiones ya cerradas, cachés de XcodeBuildMCP de worktrees que ya no existen. Sin preguntar.
2. Build con `xcodebuild -jobs 2` sin simulador booteado.
3. Boot de 1 solo simulador.
4. Tests.
5. Apagar y borrar ese simulador.
Prohibido solapar swift-frontend + SpringBoard + app + UITests.

DerivedData y cachés de XcodeBuildMCP: al lanzar y al cerrar, borra el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees retirados o con PR ya mergeado. No preguntes. No toques los de un worktree vivo. Si el borrado falla, dilo en el cierre.

Gate después del CI del PR anterior: la sesión arranca ya, sobre `origin/2.1`. Justo antes del gate, mira si el PR #367 sigue en CI. Si sigue, espera a que entre y rebasa una sola vez, con el simulador apagado. Si `2.1` no se movió, sigue de frente. Si ese CI falla, no esperes: rebasa con lo que haya y sigue. El build y el simulador van después de ese rebase, una sola vez.

## Cómo se sabe que está bien
- Con la captura atascada y el History ilegible, ningún gesto ofrece perder; sale el atasco sin salida. Con el History legible otra vez, la salida vuelve con la cifra exacta, y lo aceptado cubre exactamente eso.
- Un cambio apuntado después del aviso nunca se pierde sin haber sido contado.
- Sin atasco, o con History legible, el comportamiento no cambia.
- Gate verde (builds sin warnings nuevos, unit completa, XCUITest de las áreas tocadas, centinela 0), salvo rojos conocidos con ticket.
- PR abierto contra `2.1` y cierre con `/cerrar-total` en modo cola (autónomo, auto-merge, sin esperar CI). Al cerrar, la Mini queda limpia: sim apagado y borrado, DerivedData y cachés de esta sesión fuera, worktree retirado, tmux muerta.

## Paso 0 (2026-10-05, autoresuelto — sesión autónoma de noche)

**Medido en `df8468f55`.** El hueco no es solo de los motivos del ciclo: lo abre cualquier oferta que relee el History
(`groupsLossUncaptured` / `freshStartGroupsLoss(readsUncaptured:)`) después de que la captura lo leyera bien. Cuatro
sitios construyen la oferta y ninguno mira si esa relectura dio `nil`:

| Gesto | Sitio | Causas que llegan |
|---|---|---|
| Ajustes, cierre en la nube | paso 2 de `performCloudSecureSignOut` | attest, sesión, otra cuenta |
| Celda privada C | `blockIfGroupsCannotUpload` | sin sesión |
| Hoja del Apple ID, puerta de Grupos del Welcome, celdas D/F | `pushGroupsForSignOut` → `.surfacePermanent` | attest, sesión, otra cuenta |
| «Empezar de cero» | `settleFreshStartBlock` | attest, sesión, `.permanent`, otra cuenta |

El desasociar **no aplica**: no ofrece salida (`lossExit: nil`) y su aviso no lee el History. El PR #366 cerró el
`nil` de la lectura del VEREDICTO (`stuckCaptureVerdict`) solo para otra cuenta; el de la OFERTA seguía abierto para
las cuatro causas.

**Decisiones.**
1. **Una función pura decide en la oferta** (`CloudSignOutFlowLogic.groupsLossShownReason`): motivo que abre la salida
   + mitad del History sin leer (`nil`) ⇒ `.groupsCaptureUnfinished`, sin salida y sin oferta anotada. Para todas las
   causas, no solo attest/sesión: es el mismo hueco y la regla de Jürgen («no se acepta perder lo que el aviso no
   enseñó») no distingue causa. Construye sobre #366, no lo toca.
2. **El texto se reusa**: `groups.errors.captureUnfinished` dice la verdad en este caso (no se pudieron preparar, no se
   pierden, cerrar y abrir Yala). Cerrar y abrir vuelve a leer el History, y con él vuelve la salida con su cifra.
   Sin textos nuevos ⇒ sin cambios de l10n. «Empezar de cero» antepone su `leadUnknown` («no borramos nada»), cierto.
3. **Cinturón en lo aceptado**: `CausedLossAcceptance.coversUncaptured` y la mitad del History de
   `FreshStartGroupsLoss.covers` ya no cubren cualquier cosa con lo aceptado sin leer: solo «nada ahora». Las filas y
   el espejo (`LossAcceptance.uncounted`, decisión B2) no se tocan, ni la mitad personal.
4. **La celda C sigue contando la oferta con lo aceptado puesto** (se decidió lo contrario y la review lo tumbó: recontar
   sin lo aceptado dejaba de leer el History en la comprobación pegada al arm, que no captura, y un cambio apuntado tras
   el aviso se iba con el borrado). Precio aceptado: con lo aceptado, la captura curada y el History ilegible, sale «no
   se pudieron preparar» aunque la captura de ese paso terminara. No pierde nada y volver a intentarlo lo resuelve.
5. **La puerta de volver a entrar** (`leaveSignInDoorOpen`) se decide con el motivo que se ENSEÑA, como fija
   `SyncSignInBannerLogicTests` («el que decide si se para el motor es el que la persona va a leer»). Con el History
   ilegible sale el atasco y la puerta no se abre; la cadencia para el motor sola al chocar con el 401, y al volver a
   intentarlo con el History legible sale la sesión caducada con su puerta. (Primero se decidió lo contrario; el scan
   de esa regla lo corrigió.)
6. **El hermano personal** (`PersonalLoss.uncaptured == nil` en la oferta de tus datos) tiene el mismo hueco: ticket a
   backlog, fuera de esta sesión.
7. **Sin capturas**: el aviso que sale es uno que ya existe; para fabricar el caso hace falta un History que falle a
   demanda, que solo dan los seams de test. Device-QA no aplica (no hay forma de provocarlo en un iPhone) ⇒ tarjeta a
   `done`.
