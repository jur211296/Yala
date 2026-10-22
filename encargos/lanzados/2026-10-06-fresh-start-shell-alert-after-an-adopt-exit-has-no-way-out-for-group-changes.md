# Tras salir de un adopt, «Borrar todo y continuar» deja de negarse en bucle con cambios de grupos: pasa por la puerta privada (decisión A de Jürgen)

## Contexto
Ticket `tickets/backlog/fresh-start-shell-alert-after-an-adopt-exit-has-no-way-out-for-group-changes.md` (high). Léelo entero: trae lo medido en el código (ContentView.startFreshPrivateOnboarding, ShellDataAlertsModifier.continueInTheGateWhileGroupsArePending → refuseWhileGroupsArePending, onAdoptStarted pone hasCompletedOnboarding=true y ningún cancel/fallo del adopt lo devuelve).

Caso de usuario: alguien empieza a entrar con su cuenta en la nube desde la bienvenida, el adopt falla o lo cancela, vuelve a la bienvenida y elige «Soy nuevo → privacidad total». Con datos locales y cambios de grupos que no pueden subir (de otra cuenta o de una cuenta sin sesión), «Borrar todo y continuar» dice «inténtalo en un rato» y no borra, para siempre. La única salida hoy es desinstalar.

Decisión de Jürgen (2026-10-06 05:29 Lima, tarjeta tablero-decidir-tras-cancelar-la-entrada-con-la-069g): **opción A**. El aviso de «Borrar todo y continuar» pasa por la puerta privada también con el onboarding completo cuando el Welcome está montado (la guarda real es «¿hay cover debajo?», no hasCompletedOnboarding). La puerta sube lo que pueda, enseña el motivo y ofrece perderlos con la cifra. No se toca la entrada con la nube.

Precedente inmediato: PR #369 (ya en 2.1) separó en ese alert la cifra tuya / de otra cuenta con su motivo. Respeta ese texto.

## Qué se pide
- Implementar A: desde el alert del shell con el Welcome montado, el botón destructivo lleva a la puerta privada en vez de refuseWhileGroupsArePending. Decide tú qué se ve al volver de la puerta (cancelar en la puerta → de vuelta al Welcome en el mismo punto, sin borrar; aceptar perderlos → borra y sigue el onboarding privado), con la opción más robusta y documentada en el PR.
- Tests: rojo antes y verde después del caso del ticket (adopt cancelado + datos locales + cambio de grupos de otra cuenta → la oferta de perderlos con su cifra; aceptarla borra). Cubre también: adopt que falla por error, .adoptExit y .lineageExit si comparten camino; y que con el onboarding completo SIN Welcome montado el comportamiento de hoy no cambia.
- Mutantes sobre la guarda nueva y review adversarial como en las sesiones anteriores.
- Si algo del texto cambia, las claves en los 16 idiomas.

## Qué NO hay que tocar
- La entrada con la nube ni la kill-safety del adopt (el true temprano de hasCompletedOnboarding se queda): eso era la opción B, descartada.
- No dupliques la salida «perderlos» en el alert (opción C, descartada).
- El CI: si pure-logic sale con un solo rojo conocido y el job se corta por tiempo, no lo arregles aquí; es el ticket ci-one-red-in-pure-logic-triples-the-step-and-the-job-ceiling-cancels-it (tarjeta 6qi7), que va después. Dilo en el cierre si te pasa.
- Nada de marketing/.

## Cómo se sabe que está bien
El criterio del ticket se cumple en tests, el resto de salidas del alert no cambian, gate verde (builds Yala y Yala Dev sin avisos nuevos, unitaria y XCUITest de las áreas tocadas), PR a 2.1 con auto-merge, ticket movido, y capturas antes/después solo si el estado se puede provocar en el simulador (si no, dilo y no inventes).

Mini: pipeline serial (limpiar → build `xcodebuild -jobs 2` sin sim → boot 1 sim → tests → apagar y borrar ese sim). Máximo 1 simulador.

Gate después del CI del PR anterior: la sesión arranca ya, sobre origin/2.1. Justo antes del gate, mira si el PR anterior (#371, solo docs) sigue en CI. Si sigue, espera a que entre y rebasa una sola vez, con el simulador apagado. Si 2.1 no se movió, sigue de frente. Si ese CI falla, no esperes: rebasa con lo que haya y sigue. El build y el simulador van después de ese rebase, una sola vez.

DerivedData y cachés de XcodeBuildMCP: al lanzar y al cerrar borra tú el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen. No toques los de un worktree vivo. No pidas aprobación. Si el borrado falla, dilo en el cierre.

Sesión autónoma: decisiones reversibles de detalle (copy, qué se ve al volver), tómalas tú con la opción más robusta y escríbelas en el PR. Al terminar, corre `/cerrar-total` tú misma sin esperar a Jürgen, dejando la Mini limpia (sims apagados y borrados, worktree retirado si el PR ya mergeó, sin DerivedData de esta sesión).

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**Hechos medidos (árbol de `5c493dedb`).** El único disparador del alert es `startFreshPrivateOnboarding`, y sus dos
llamadores (`onSelectBranch(.new)` y `onSelectPrivateAccount`) son closures del `WelcomeFlowContainer`: hoy el alert
SOLO se presenta desde el Welcome. Las cuatro salidas del adopt (`.error`, `.adoptExit`, `.lineageExit` por la flecha
`canGoBack`, y «Cancelar la activación» por `cancelLanded`) comparten `onBack` → Welcome en `.chooser`, y ninguna baja
`hasCompletedOnboarding`. La puerta `.wipeDevice` ya está pensada para el onboarding completo (dispositivo solo-grupos):
`wipeAllUserData` baja el flag y el `onChange` calla con el Welcome montado.

**D1 · ¿Cómo sabe el alert que había Welcome debajo?** → un testigo capturado AL DISPARAR
(`freshStartAlertPresentedOverWelcome = showWelcomeFlow` en `startFreshPrivateOnboarding`), no `showWelcomeFlow` al
pulsar: presentar el alert ya desmontó el cover. La decisión vive en una función pura
(`FreshStartAlertRoutingLogic`), `!hasCompletedOnboarding || presentedOverWelcome` → puerta; si no, negativa de hoy.
Por qué: es «¿hay cover debajo?» literal y medible. Alternativa descartada: quitar `hasCompletedOnboarding` del
predicado — cambiaría una celda (sin onboarding y sin Welcome) que hoy va a la puerta, sin necesidad.

**D2 · ¿Qué se ve al volver de la puerta?** → lo que la puerta ya hace, sin añadir nada: «atrás» vuelve a
`newBranchOriginStep` (la elección privado/nube, donde estaba) sin borrar; aceptar perderlos borra y sigue al
onboarding privado por `onProceed` → `startFreshPrivateOnboarding`, que ya ve el teléfono vacío.
Por qué: es el mismo camino que ya recorre quien no tiene el onboarding completo. Alternativa descartada: volver al
`.chooser` de primer nivel — le cobra un paso a quien solo dijo «no».

**D3 · «Cancelar» del alert y el «OK» del aviso de fallo, con el mismo `if !hasCompletedOnboarding`** → NO se tocan:
el encargo pide que el resto de salidas no cambien. Tras salir de un adopt, «Cancelar» no reabre el Welcome; va a
ticket aparte como hallazgo.

**D4 · Copy** → no cambia ninguna cadena. Sin l10n.

**D5 · Tests** → tabla de la función pura (las 4 celdas, la del ticket en rojo con la lógica vieja: mutante M0),
source-scan del cableado (testigo puesto antes de encender el alert; la ruta usa la lógica; las salidas del adopt
comparten `onBack` y no bajan el flag), y la mitad de la puerta con cambios de OTRA cuenta: oferta con su cifra y
aceptarla borra. Mutantes sobre la guarda y review adversarial (toca borrado de datos).

**D6 · (tras la review) La celda «onboarding completo sin Welcome» hoy no se alcanza: ¿se retira la negativa?** → no:
se queda como red y se DICE en el docblock. Tres lentes lo midieron: el único disparador vive en el Welcome, así que
con grupos pendientes el alert siempre sigue en la puerta (también desde un Welcome que reabre una sesión solo-grupos, y
ahí el borrado directo con el outbox vacío ya borraba igual). Un test cuenta los disparadores. Alternativa descartada:
quitar la rama — un disparador futuro fuera del Welcome volvería a plantar el Welcome a quien ya usa la app.

**D7 · ¿XCUITest y capturas?** → no. La salida real de un adopt exige un sign-in con Apple/Google, que el simulador no
firma; fingirlo con un seam que ponga el flag y abra el Welcome sería inventar el estado. Guion de device-QA en el
ticket, que va a `qa`.
