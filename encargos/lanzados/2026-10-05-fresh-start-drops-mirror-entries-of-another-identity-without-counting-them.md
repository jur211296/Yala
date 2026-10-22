# «Empezar de cero» cuenta también las entradas del espejo de grupos de otra cuenta antes de borrarlas (decisión A de Jürgen)

## Contexto
Ticket: `tickets/backlog/fresh-start-drops-mirror-entries-of-another-identity-without-counting-them.md` (léelo entero; las coordenadas son del 26-sep y derivan, re-mídelas).
En un teléfono con la sesión de grupos de una persona, el espejo del App Group (`GroupsOutboxMirror`) puede guardar cambios de grupos de OTRA cuenta que nunca llegaron a su fila. «Empezar de cero» purga el espejo entero (`DataWipeService.wipeLocalGroupsDomain` → `purgeAll()`), pero el recuento y lo aceptado miran solo las entradas del dueño de la sesión (`MirrorPendingScope.sessionOwnerOrEveryoneWhenSignedOut`). Resultado: se borran cambios ajenos y ni el aviso ni la cifra de «perderlos» los cuentan.

Decisión de Jürgen (2026-10-04, tarjeta del tablero): **A. Contar los datos de la otra identidad, aunque pueda bloquear.** Es decir: cuando «Empezar de cero» va a purgar todo el espejo, el recuento y lo aceptado cuentan todas las entradas que se llevaría, y si esa sesión no puede subir las ajenas, bloquea por el camino que ya existe (el que ofrece perderlas con la cifra exacta). Jürgen quiere siempre lo más robusto y la mejor práctica, aunque tarde más.

Relacionado y SIN decidir (no lo implementes, solo no lo rompas): `stuck-groups-drain-hides-held-rows-of-another-account` (nació hoy con PR #364) y `groups-kept-by-the-late-notice-are-purged-by-the-welcome-fresh-start` (otra decisión distinta, va en otra sesión).

## Qué se pide
1. Medir en el código de hoy el desajuste entre lo que cuenta y lo que borra «Empezar de cero» (en Ajustes y, si comparte camino, en la bienvenida).
2. Implementar la decisión A: recuento = lo que el borrado se llevaría; si hay entradas ajenas que esta sesión no puede subir, bloquear con la salida de «perderlos» y la cifra exacta (todas las entradas, propias y ajenas). Texto claro para el usuario si hace falta uno nuevo, en los 16 locales (es-AR voseo, es-ES pretérito perfecto, español neutro en el resto), sin inventar plazos.
3. Tests: rojo medido antes del fix, verde después, mutantes que importen, controles (sin entradas ajenas, sin sesión).
4. Review adversarial con lente de datos y lente de verdad del copy.
5. Hallazgos nuevos → tickets en `tickets/backlog/`; device-QA si aplica → guion en `tickets/qa/` y tarjeta del tablero a `in qa`; si no aplica, tarjeta a `done`. La tarjeta es `tablero-decidir-empezar-de-cero-descarta-datos-d-ux9p`.
6. Si el cambio se ve en pantalla, deja `capturas/antes.png` y `capturas/despues.png` en el worktree y lista las rutas en el resumen.

## Qué NO hay que tocar
- No cambies la decisión B2 del cierre de sesión ni del desasociar (purgan igual): solo «Empezar de cero».
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

Gate después del CI del PR anterior: la sesión arranca ya, sobre `origin/2.1`. Justo antes del gate, mira si el PR #364 sigue en CI. Si sigue, espera a que entre y rebasa una sola vez, con el simulador apagado. Si `2.1` no se movió, sigue de frente. Si ese CI falla, no esperes: rebasa con lo que haya y sigue. El build y el simulador van después de ese rebase, una sola vez.

## Cómo se sabe que está bien
- Con entradas ajenas en el espejo, «Empezar de cero» las cuenta y no las borra sin que el usuario lo acepte con la cifra exacta.
- Sin entradas ajenas, el comportamiento no cambia.
- Gate verde (builds sin warnings nuevos, unit completa, XCUITest de las áreas tocadas, centinela 0), salvo rojos conocidos con ticket.
- PR abierto contra `2.1` y cierre con `/cerrar-total` en modo cola (autónomo, auto-merge, sin esperar CI). Al cerrar, la Mini queda limpia: sim apagado y borrado, DerivedData y cachés de esta sesión fuera, worktree retirado, tmux muerta.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**Medido (2026-10-05, árbol `c62c86dec`).** «Empezar de cero» tiene tres pantallas —la puerta privada de la bienvenida,
el aviso tardío de iCloud y el alert del shell— y **no hay un camino propio en Ajustes**: las tres cuentan con
`CloudSessionSignOut` (`groupsOutboxIsSettledEmpty`, `freshStartGroupsPendingCount`, `freshStartGroupsLoss`) y el cinturón
`DataWipeService.requireNoUnsentGroupWrites` usa los mismos dos. Los cuatro miran el espejo con
`.sessionOwnerOrEveryoneWhenSignedOut`: con sesión, solo las entradas de su dueño. El borrado
(`wipeLocalGroupsDomain` → `GroupsOutboxMirror.purgeAll()`) se lleva todas. Con sesión y solo entradas ajenas, el
pre-check del alert daba «vacío» y borraba en el mismo tap sin aviso.

**D1 · ¿Se cambia el alcance que ya existe o se crea uno?** → Uno nuevo, `.wholeMirror` (todas las entradas, con sesión o
sin ella), y «Empezar de cero» pasa a usarlo en sus cuatro sitios.
Por qué: `.sessionOwnerOrEveryoneWhenSignedOut` lo usa también la oferta de pérdida del cierre de sesión (B2), que el
encargo prohíbe tocar. Alternativa descartada: redefinir el viejo, que cambiaría el cierre.

**D2 · Con sesión y solo entradas ajenas, ¿qué motivo enseña el bloqueo?** → `.groupsChangesFromAnotherAccount`, que ya
ofrece perderlos y ya tiene su texto en los 16 locales («la sesión abierta en este teléfono es de otra»). Sin sesión,
`.sessionExpired`, como hoy.
Por qué: es literalmente el caso de ese texto, y no hace falta copy nuevo. Alternativa descartada: dejar
`.sessionExpired`, cuyo texto dice «su sesión ya no está en este teléfono» a quien tiene una sesión abierta.

**D3 · ¿Cómo sabe el bloqueo que lo que queda es de otra cuenta?** → Un segundo alcance, `.anotherAccount`: entradas cuyo
dueño no es la sesión; sin sesión, ninguna (ahí no hay «otra», hay sesión caducada).
Por qué: un recuento directo se puede probar y mutar. Alternativa descartada: restar dos alcances, que reparte el
significado entre dos números que pueden divergir.

**D4 · Un bloqueo que NO ofrece perderlos (lo pasajero), con entradas ajenas en el espejo: ¿qué cifra?** → La de la
subida más las ajenas. Sin ajenas, la de siempre.
Por qué: el texto dice «hay cambios (N) y empezar de cero se los llevaría», y se llevaría también esas. Alternativa
descartada: recalcular la cifra entera con el recuento del borrado, que cambiaría también el caso de filas vivas de otra
cuenta (`stuck-groups-drain-hides-held-rows-of-another-account`, sin decidir).

**D5 · Capturas** → No hay. El cambio no añade pantalla ni texto: enseña un aviso que ya existe en un estado que el
simulador no alcanza sin dos cuentas reales y un drain cortado a mitad. No hay seam `-uitest-*` para sembrar el espejo.

**D6 · Device-QA** → No aplica: reproducirlo exige un cambio de grupo atrapado en el espejo de otra cuenta (kill a mitad
del drain y cambio de cuenta), que no es un guion que se pueda correr a mano. La cobertura es unitaria con el espejo REAL
en disco y el filtro real. Ticket y tarjeta a `done`.

**D7 · Fuera** → El cierre y el desasociar (B2), las filas vivas de otra cuenta y el aviso tardío que conserva grupos
siguen como están.
