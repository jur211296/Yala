---
id: fresh-start-drops-mirror-entries-of-another-identity-without-counting-them
status: done
updated: 2026-10-05
priority: low
area: "groups, modo-nube"
created: 2026-09-26
source: "review adversarial de `fresh-start-has-no-way-out-when-group-writes-can-never-upload` (2026-09-26, lente de datos)"
---

# «Empezar de cero» se lleva entradas del espejo de otra cuenta sin contarlas

## El síntoma

En un teléfono con la sesión de grupos de una persona, el espejo del App Group guarda cambios de grupos de OTRA cuenta
que nunca llegaron a su fila. «Empezar de cero» los borra y ni el aviso ni la cifra de «perderlos» los cuentan.

## Lo medido (2026-09-26, leído en el código, sin ejecutar)

- El recuento y lo aceptado de «Empezar de cero» miran el espejo con
  `GroupsSyncClient.MirrorPendingScope.sessionOwnerOrEveryoneWhenSignedOut`: con sesión, solo las entradas de su dueño.
- El borrado purga el espejo ENTERO (`DataWipeService.wipeLocalGroupsDomain` → `GroupsOutboxMirror()?.purgeAll()`).
- Es la decisión B2 de siempre (el cierre y el desasociar purgan igual) y no la introdujo la salida «perderlos». Lo que
  cambia es que ahora el docblock de `FreshStartGroupsBlock.pendingCount` dice «lo que el borrado se llevaría», y con
  sesión y entradas ajenas no es exacto.

## Por dónde va

O el recuento de «Empezar de cero» cuenta todas las entradas cuando va a purgar todas (y entonces esa sesión no puede
subirlas: bloquearía con `.sessionExpired`, que ofrece perderlas), o se acota el docblock y se deja escrito que las ajenas
se van por la decisión B2. Lo primero puede bloquear a quien tiene restos de otra cuenta, así que es decisión de producto.

## Resuelto (2026-10-05) — decisión A de Jürgen

Decisión de Jürgen (2026-10-04, tarjeta del tablero): **contar los datos de la otra identidad, aunque pueda bloquear.**

**Qué cambia para quien usa la app.** En un teléfono con la sesión de grupos de una persona y cambios de grupos de OTRA cuenta
guardados en el espejo, «Empezar de cero» ya no los borra sin decirlo. Se para, dice cuántos cambios se llevaría (todos, propios
y ajenos) y que solo pueden subir con la cuenta que los apuntó («la sesión abierta en este teléfono es de otra»), y ofrece
«Empezar de cero y perderlos» con esa cifra exacta. Sin entradas ajenas nada cambia. Sin sesión, como antes.

**Medido en el código.** Las tres pantallas del gesto (la puerta privada de la bienvenida, el aviso tardío de iCloud y el
alert del shell) cuentan con `CloudSessionSignOut`; no hay camino propio en Ajustes. Los cuatro sitios que contaban
(`groupsOutboxIsSettledEmpty`, `freshStartGroupsPendingCount`, `freshStartGroupsLoss` y el cinturón
`DataWipeService.requireNoUnsentGroupWrites`, que usa los dos anteriores) miraban `.sessionOwnerOrEveryoneWhenSignedOut`.

**Cómo.**
- Dos alcances nuevos en `GroupsSyncClient.MirrorPendingScope`: `.wholeMirror` (todas, con sesión o sin ella) y
  `.anotherAccount` (las de otra cuenta que la de la sesión; sin sesión, ninguna). «Empezar de cero» usa `.wholeMirror` en sus
  cuatro sitios. El cierre de sesión y el desasociar (B2) siguen con `.sessionOwnerOrEveryoneWhenSignedOut`.
- `freshStartResidualReason` recibe las ajenas: con la sesión de otra cuenta abierta el motivo es
  `.groupsChangesFromAnotherAccount` (texto existente, 16 locales); sin sesión, `.sessionExpired` como antes. Sin copy nuevo.
- Un bloqueo que no ofrece perderlos (lo pasajero) suma las ajenas a su cifra (`freshStartBlockCountingAnotherAccount`), porque
  su texto dice «empezar de cero se los llevaría». Sin ajenas, la cifra de siempre.
- Testigo nuevo `GroupsExitWitness.mirrorPendingOfAnotherAccount`, con default 0 para los testigos de tests que no lo siembran.

**Tests.** `YalaTests/CloudSync/FreshStartForeignMirrorEntriesTests` (12 casos, espejo REAL en disco y filtro real): rojo medido
antes del fix (6 de 9 fallaban, los 3 controles en verde), verde después. Más los alcances nuevos en
`GroupsDrainCaptureTests.mirrorCount_respectsItsScope` y la tabla del motivo en `GroupsCaptureVerdictTests`. 10 mutantes, los 10
muertos; un undécimo sobrevivía porque su término sobraba (comprobar `Int.max` a mano cuando el desbordamiento ya lo cubre) y
se retiró el término.

**Review adversarial (lente de datos y lente de verdad del copy).** Las dos cazaron el mismo bug en la primera versión: si la
subida terminaba pero después aparecía algo propio, el residuo ya contaba el espejo entero y el bloqueo volvía a sumar las
ajenas (1 propia + 2 ajenas salía «5»). Arreglado: las ajenas se suman solo a la cifra que viene de la subida
(`residualBlock_countsForeignEntriesOnce`). Ninguna lente encontró un camino que pierda datos ni un bloqueo sin salida. Los
matices de texto que encontró la de copy son decisión de producto: `fresh-start-copy-for-another-accounts-group-changes-borrows-the-own-reason`.

**Sin device-QA:** reproducirlo exige un cambio de grupo atrapado en el espejo de otra cuenta (un kill a mitad del drain y un
cambio de cuenta), y no hay seam para sembrar el espejo. La pantalla y el texto son los que ya existían.
