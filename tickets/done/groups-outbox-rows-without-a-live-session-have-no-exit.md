---
id: groups-outbox-rows-without-a-live-session-have-no-exit
status: done
priority: medium
area: "settings, groups, modo-nube"
created: 2026-09-11
updated: 2026-09-28
source: "review adversarial del paso 9 (`session-exits-one-verb-per-session`), lente de celdas"
---

# Si mi sesión de grupos caducó con cambios sin subir, no puedo cerrar sesión hasta volver a entrar

## El síntoma, en lenguaje de usuario

Anoté gastos de grupo sin conexión y mi sesión caducó. Toco «Cerrar sesión» y Yala me dice que mi sesión
caducó y que vuelva a entrar. Si puedo entrar, bien: se suben y ya puedo cerrar. Si no puedo —borré la cuenta
desde otro sitio, perdí el acceso a ese correo—, no hay forma de cerrar sesión en este teléfono.

## Lo que hace el código desde el paso 9

- El cierre de la privada (C) y el de solo grupos (F) no descartan filas vivas de `GroupSyncOutbox`: sin
  sesión no se pueden subir, y el boot-wipe borra sync-meta, que es donde viven. Se bloquea con
  `BlockReason.sessionExpired` y el aviso `groups.errors.sessionExpired`.
- Es el criterio del ticket («nunca descarta») y la D15 del paso 9: los grupos no tienen salida de emergencia.
- Antes del paso 9, la fila «Salir de Yala en este dispositivo» purgaba el outbox en silencio.

## Lo que falta decidir (Jürgen)

1. ¿Hay una salida para quien no puede volver a entrar? Por ejemplo, un descarte avisado que cuente las
   filas, como la salida de emergencia del export.
2. El outbox no tiene dueño: si la persona entra con OTRA cuenta, las filas se suben firmadas por esa cuenta.
   ¿Se sellan con el `userID` que las escribió?

## Criterios de aceptación

- [x] Decisión escrita sobre las dos preguntas (encargo del 2026-09-28, abajo).
- [x] Si hay descarte: aviso con el número, segundo gesto, canario.
- [x] Si hay sello: una fila de otra cuenta no se sube nunca (test en las dos direcciones).

## 2026-09-15 · la celda de la nube entra en esta población

Desde `cloud-signout-collapses-a-groups-session-expiry-into-permanent` (decisión 3A de Jürgen), el cierre de
una cuenta **en la nube** también enseña `groups.errors.sessionExpired` cuando el push de grupos no tiene
sesión. Antes decía «revisa tu conexión». El bloqueo ya existía y sigue igual: lo que cambia es que ahora dice
por qué. Con esto, la pregunta 1 de arriba aplica a las cuatro celdas del cierre (C, D, E y F), no solo a C y F.

**Y la pregunta 2 gana urgencia.** El aviso empuja a volver a entrar, y en la nube, con la sesión borrada por el
SDK, la única puerta es «Nuevo grupo» en la pestaña Grupos. Ese botón lleva al inicio de sesión de Grupos, y al
firmar `CloudIdentityRoutingLogic` devuelve `.continueGroupsSetup` sin mirar qué cuenta entra. Si entra otra,
estas filas podrían subirse a su nombre. Leído en el código, sin ejecutar. Ver
`cloud-session-expiry-with-only-group-changes-has-no-sign-in-door`.

## 2026-09-25 · la puerta de la nube ya no sube a nombre de otra cuenta; las otras entradas, sí

Desde `cloud-session-expiry-with-only-group-changes-has-no-sign-in-door` la puerta de «Dónde viven tus datos» ata la firma
al dueño del motor: si entra otra cuenta, cierra esa sesión y no reanuda nada. Y el ciclo del motor personal no corre con
un `sub` distinto del suyo (`CloudSyncRuntime.performCycle`, paso 1.5), así que en la nube el piggyback de Grupos tampoco.

**La pregunta 2 sigue abierta para las demás entradas**, leído en el código: una sesión de otra cuenta que entre por «Nuevo
grupo» todavía sube el outbox de grupos por `GroupsSyncClient.syncNowFromPush` y por el paso 2 del cierre en la nube (con el
outbox personal vacío, el paso 1 drena y el 2 sube). Lo que cierra las dos es el sello por fila que propone este ticket.

Las entradas que hoy suben el outbox de grupos sin pasar por el ciclo del motor, medidas por la review del mismo día:
`syncNowAfterLocalSave`, `syncNowFromUI`, `syncNowFromPush` y `pushAllPendingGroupsForSignOut` (paso 2 del cierre).

**Y la pregunta 1 gana un caso nuevo en la nube:** si el Apple ID del teléfono cambió y la cuenta es de Apple, la puerta
firma siempre con la cuenta nueva y la rechaza. El cierre sigue bloqueado por `.cloudSessionExpired` y no hay salida que
acepte perder esos cambios. Antes de ese día subían a nombre de la cuenta nueva, que era peor.

## 2026-09-28 · Resuelto

**Decisiones** (encargo del 2026-09-28, por la norma de opción robusta): (1) quien no puede volver a entrar tiene un descarte
AVISADO; «vuelve a entrar para subirlos» sigue siendo el camino por defecto. (2) El outbox tiene dueño: una fila de otra cuenta
no se sube nunca con la sesión de ahora; se retiene para su dueño o se ofrece al descarte avisado.

**Qué cambia para quien usa la app**

- Con la sesión de grupos caducada y cambios sin subir, «Cerrar sesión» enseña cuántos cambios se perderían, dice que se suben
  volviendo a entrar con esa cuenta y ofrece «Cerrar sesión y perderlos». «Ahora no» no borra nada. En Ajustes, en la hoja del
  cambio de Apple ID y en la puerta de Grupos del Welcome (nunca al invitado). En la nube, el texto nombra «Dónde viven tus
  datos».
- Si entra otra cuenta en el teléfono, los cambios que dejó la anterior no suben a nombre de la nueva: se quedan. Al cerrar
  sesión, el aviso los cuenta y ofrece perderlos. «Empezar de cero» también lo ofrece; el desasociar no.
- Si la cuenta que los apuntó vuelve a entrar, suben como siempre.

**Cómo**: `GroupSyncOutbox.ownerUserID`, fechado por transacción contra un registro de sesiones (`SessionSignInLog`, que escriben
los dos canjes de `CloudAuthService`, su `signOut()` y el arranque); `pushPending` filtra por dueño; `lossCause` y
`GroupsLossAcceptance` generalizan la salida del attest; la cifra suma el espejo del App Group y la celda C captura el History
antes de contar. La regla durable: «El outbox de Grupos tiene DUEÑO por fila» en `.claude/rules/swiftdata-cloudkit.md`.

**Verificado**: `GroupsOutboxOwnershipTests` (cinco suites: registro de sesiones, causas, canal con drain y subida reales, el
cierre C sobre el coordinador, cableado) + los XCUITest `SessionExitsPerCellUITests#test_privateCell_C_signOutWithGroupChangesAndNoSession_offersTheLoss_andNotNowKeepsThem`
y `AppleIDCloseNoticeUITests#test_blockedClose_offersTheLoss_notNowKeepsEverything_andLeavesTheCoordinatorFree`. Review
adversarial de tres lentes: tumbó la primera versión del dueño (un libro de un solo valor) y encontró que el aviso de la celda
C no contaba lo que vivía en el History ni en el espejo; las dos cosas se arreglaron en este ticket.

**A `done` sin device-QA**: la frontera de cuenta necesita dos cuentas y una sesión caducada, que no se provoca a mano; la
pantalla la cubren los dos XCUITest.

**Residuales con ticket**: `cloud-sign-out-with-an-expired-session-and-personal-changes-has-no-exit` (medium),
`groups-outbox-rows-without-a-provable-owner-never-upload` (low), `private-sign-out-misses-group-edits-made-during-the-icloud-wait`
(low). Aceptados sin ticket: un reloj que cambia entre un inicio de sesión y lo apuntado desplaza el reparto; lo que la cuenta
nueva apunte en el instante entre el canje y su registro se fecha como de la anterior (se retiene, no se reatribuye); con la
captura a medias, la sesión caducada se enseña como «inténtalo en un rato» hasta que la captura termine; la celda C de quien
tiene grupos del canal backend espera la quiescencia del import antes de cerrar aunque no tenga nada pendiente (en uso normal
no espera nada; durante un primer import de iCloud, hasta 60 s); y las entradas del espejo de OTRA cuenta que no llegaron a su
fila no entran en la cifra cuando la sesión es de otra (decisión B2: el teardown purga el espejo entero).

Segunda ronda de la review, sobre el rediseño: tumbó dos cosas y las dos se arreglaron aquí. La adopción de dueño alcanzaba
también a filas nuevas que el drain dejó sin dueño a propósito (ahora solo a las de `schemaVersion` 1), y todo cierre de sesión
volvía a la cuenta anterior (ahora solo el de una sesión de paso). Y la guardia de «la sesión sigue siendo la del filtro» va
tras cada `await` de la subida, no solo tras el refresh.
