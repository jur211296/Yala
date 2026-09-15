# Teléfono sin App Attest: veredicto terminal + salida con pérdida confirmada

## Contexto
Ticket: `tickets/backlog/groups-phone-that-never-attests-is-told-to-retry-forever.md` (medium).
Sale del review de `groups-sync-reads-a-missing-attest-401-as-a-session-expiry` (PR #172 en 2.1).
Hoy ese 401 es pasajero: si el teléfono NUNCA consigue attest, la persona oye «inténtalo en un rato» para siempre y no puede cerrar sesión si hay cambios de grupos sin subir.

## Decisión Jürgen (2026-09-15) — YA TOMADA, no repreguntar
**Opción 2:** además del veredicto terminal del canal personal (este teléfono no puede sincronizar grupos), una salida de cierre con **texto honesto** que avise de que los cambios de grupos sin subir **se pierden**, y pida **confirmación explícita**. Excepción acotada a la regla de no descartarlos nunca.

## Que se pide
Implementar esa decisión. Gate, commit, board (`tickets/` + `docs/TICKETS.md`), PR, merge a 2.1, `/cerrar-total`.

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board, actualizar `docs/TICKETS.md`, merge y `/cerrar-total` sin preguntar si corre el gate o el commit. Bugs/decisiones nuevas → ticket propio antes de cerrar. Solo parar ante decisión/acceso real no cubierta arriba.

## Día / AskUserQuestion (6:00–21:00 Lima)
Sesión DIURNA. Si aparece decisión de producto/acceso nueva, usa AskUserQuestion. No inventes.

## Que NO hay que tocar
marketing/. No mezclar el copy genérico offline (`signout-pending-copy-…`) ni el wake-on-foreground salvo colateral mínimo.

## Como se sabe que esta bien
Tras fallos de attest reiterados: aviso terminal claro; cierre ofrece salida con pérdida confirmada; no «inténtalo en un rato» eterno; tests; ticket cerrado; PR mergeado; `/cerrar-total`.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL/key en fichero local, no en git) cuando:
(1) decisión de producto/acceso; (2) PR/preview listo; (3) /cerrar-total con resumen usuario; (4) idle sin paso claro — una vez.
NO por test rojo a reclasificar, build a reintentar, CI advisory.

## Paso 0 — decisiones

> Las cuatro de producto las contestó Jürgen en la sesión (AskUserQuestion, 2026-09-15, 13:00 Lima), las cuatro con la
> recomendada. Las técnicas son recomendaciones de Frank, medidas en este árbol, y se discuten en el PR.

**Hechos medidos antes de decidir.**

- **El ticket tenía una premisa falsa: el canal personal no tiene banner.** `CloudSyncRuntime.performCycle` (paso 2)
  solo emite `cloudSyncBlockedByAttestUnavailable` y para con `.accountUnavailable`; `SyncStatusBanner` es el de iCloud.
  Y su veredicto solo salta con `AppAttestError.unavailable` tres veces (`AttestSyncGate.classify`), o sea con
  `DCAppAttestService.isSupported == false`: un `DCError` del assert o del register cae en el `catch` genérico de
  `resolveAttest` y es pasajero para siempre.
- Grupos no ve el `AppAttestError`: `AttestSessionProvider.live` lo convierte en `nil`, y lo único que le llega es el
  401 `yala_attest_required` (`GroupsSyncClient` en push y pull, `GroupsMembershipClient.call`).
- Los cierres: D y F suben grupos por `pushGroupsForSignOut` (45 s); E llama al push-all directo y traduce con
  `cloudSignOutGroupsBlockReason`; la hoja del Apple ID solo corre C y D; la puerta del Welcome, C, D y F. El desasociar
  comparte `pushGroupsForSignOut`, y sus bloqueos también encienden el aviso de Ajustes
  (`signout-alert-fires-on-detach-blocks-it-did-not-cause`).
- El molde de «salir perdiendo lo que no subió» ya existe: `.exportUnconfirmed` (`blockedExit`,
  `exitDiscardingUnconfirmed`, `ExportPolicy.acceptLoss(upTo:)`, canarios `privateSignOutExport*`).
- En `.cloud` Grupos cicla dentro del runtime personal, que corta antes en su propia puerta de attest: ahí Grupos solo
  pide al guardar (`GroupsSaveSyncTrigger`), al cerrar sesión y en las RPC de membresía.
- `removeUserPreferenceKeys` es una lista explícita, y `PendingJoinStore.defaults` es el molde de `UserDefaults`
  inyectable en tests.

**Producto (Jürgen).**

**P1 · Cuándo es terminal** → tras 24 h y al menos 3 rechazos sin un solo acierto, recordado entre arranques. Hasta
entonces, el aviso pasajero de hoy.

**P2 · Qué gestos ofrecen salir perdiendo los cambios** → los cierres de sesión: Ajustes, la hoja del cambio de Apple ID
y la puerta de Grupos del Welcome, salvo a quien entra por una invitación. Desasociar y salir de un grupo enseñan el
aviso terminal, sin salida. En la nube con cambios personales pendientes no cambia nada: ticket.

**P3 · Texto** → un aviso cuyo botón destructivo nombra la pérdida: «Cerrar sesión y perderlos» / «Ahora no».

**P4 · Aviso fijo en la pestaña Grupos** → fuera de este PR, a ticket propio.

**Técnicas (Frank).**

**D1 · Qué cuenta como rechazo** → el 401 `yala_attest_required` de cualquier ruta de Grupos: push, pull y RPC, y como
mucho uno por hora (corregido tras la review: un solo gesto dispara ráfagas y cumplía el mínimo de 3 en segundos).
Por qué: es el servidor diciendo «red bien, sesión bien, falta attest», sin decidir qué `DCError` son permanentes, que
nadie ha medido; sin red o con un 5xx no se produce. Alternativa descartada: los fallos de `AppAttestClient`, que obligan
a esa clasificación y confunden «sin red» con «sin attest».

**D2 · Qué reinicia la racha** → un 200 de esas mismas rutas.
Por qué: es la única respuesta que prueba sin ambigüedad que el attest pasó la guard. Alternativa descartada: cualquier
respuesta que no sea 401, porque un 403 del borde o un 5xx no prueban nada.

**D3 · Dónde vive** → una clave de `UserDefaults.standard` detrás de `GroupsAttestStreakStore` (`defaults` inyectable,
molde `PendingJoinStore`), con la decisión pura en `GroupsAttestVerdictLogic`. Fuera de `removeUserPreferenceKeys` y de
`PrefSyncKey`.
Por qué: describe al teléfono y no a la persona, y App Attest va con la instalación. Un reloj que retrocede reinicia la
racha: nunca adelanta el veredicto. Alternativa descartada: memoria del proceso, que nunca llega a 24 h.

**D4 · La membresía también apunta** → sí, en `call`, por la misma tienda y sin tocar sus ocho construcciones.
Por qué: en la nube Grupos casi no pide en segundo plano, y sin la membresía quien solo intenta salir de un grupo oiría
«en un momento» para siempre. Alternativa descartada: inyectarlo en cada construcción, que toca ocho ficheros ajenos.

**D5 · El veredicto exige un rechazo de AHORA** → además de la racha, el ciclo que se lee tiene que haber chocado con
ese 401 (testigo por ciclo, molde `lastStopWasChannelKill`).
Por qué: una racha vieja no puede disfrazar un fallo de hoy que es otra cosa: sin red, el kill o una sesión caducada.

**D6 · El motivo** → `BlockReason.attestUnavailable`, al final del enum, slug `attest-unavailable`. `classify` gana
`attestUnavailable:` sin valor por defecto; `GroupsSignOutRetryDecision` lo muestra al momento;
`cloudSignOutGroupsBlockReason` lo deja pasar.
Por qué: reintentar 45 s contra un teléfono que lleva un día sin attest son ~23 subidas que no aciertan. Alternativa
descartada: `.permanent`, cuyo texto manda a revisar la conexión.

**D7 · La salida** → `CloudSessionSignOut.exitDiscardingUnsyncedGroups(context:)` retoma el cierre donde paró (inicio o
tramo final de D y F, o el paso 2 de la nube) con las FILAS que contó el aviso (por `clientMutationID`) como lo aceptado.
Antes de seguir intenta subir una vez; si aparece una fila que no estaba en el aviso, vuelve el aviso con la cifra nueva.
Nada se borra en sesión: los cambios mueren con el boot-wipe de siempre. (Corregido tras la review: la primera versión
comparaba por cifra, y aceptar 2 cambios cubría cualquier par.)
Por qué: es el molde de `acceptLoss(upTo:)`. Alternativa descartada: purgar el outbox y relanzar el cierre, que borraría
en sesión y perdería los cambios aunque el cierre se bloqueara después por otra cosa.

**D8 · Quién ofrece la salida** → solo un bloqueo que puso un CIERRE. Los tres caminos de cierre anotan desde dónde
retomar, con un parámetro sin valor por defecto; el desasociar no anota nada, y las vistas preguntan
`offersGroupsLossExit`.
Por qué: el desasociar comparte motivo, y el aviso de Ajustes también se enciende con sus bloqueos; sin esto ofrecería
cerrar sesión a quien solo quería soltar la cuenta.

**D9 · Texto por pantalla** → una tabla en `SignOutBlockedCopy`. La puerta del Welcome dice «si continúas ahora» y
«Continuar y perderlos», como ya adapta el aviso de iCloud. La cifra va tras dos puntos («Cambios de tus grupos que no
llegaron: 3.») y no en `.stringsdict`. «Ahora no» es clave genérica nueva (`action.notNow`).
Por qué: es el molde del aviso hermano (`settings.signOutExportPendingMessage`), y el motivo está escrito en `L10n.swift`:
las variantes `es-ES`, `es-AR`, `en-GB` y `pt-PT` no llevan `.stringsdict`, así que un plural diría «1 cambios» allí.
Cambia la forma de la frase aprobada («Hay 3 cambios…»), no lo que dice. Alternativa descartada: `.stringsdict`, que
era la primera versión de esta decisión y en las variantes rompe la concordancia.

**D10 · Salir de un grupo** → `GroupLeaveErrorLogic.classify(_:attestUnavailable:)`, pura y sin valor por defecto, con
un `Kind` nuevo solo para `.transient(status: 401)`; las cinco llamadas leen la tienda.
Por qué: ese estado solo sale del attest ausente, y las acciones locales que reutilizan la tabla no pueden recibirlo.

**D11 · Canarios** → `groupsAttestTerminal` (la racha cruza el umbral: la medición que el ticket no tenía),
`groupsSignOutAttestUnavailable` (un cierre deja ofrecida la salida; cuenta ofertas, no personas) y
`groupsSignOutAttestDiscarded` (el cierre siguió sin subirlos).

**D12 · Verificación** → unit, source-scan y mutantes; los XCUITest de las áreas tocadas, como regresión. Sin XCUITest
nuevo ni device-QA simulable: llegar al 401 de verdad exige fingir el token y el transporte (un seam que deja ciego al
test), confirmar arma un boot-wipe real, y sin App Attest no baja ningún grupo, así que no hay cambios que perder.

**D13 · Review adversarial** → sí, con tres lentes: el coordinador y los datos, el canal y la racha, y las pantallas con
su texto y sus tests.

**D14 · Dónde queda lo durable** → `.claude/rules/gateway-attest.md` (la racha, el umbral y dónde se lee) y el ticket.
Los docblocks que dicen «nunca descarta» se matizan donde la excepción los alcanza.

## Review adversarial — tres lentes (2026-09-15)

Coordinador y datos, canal y racha, pantallas con textos y tests. Ningún hallazgo contradice una decisión de producto;
todos se arreglaron o quedaron escritos:

| Hallazgo | Lente | Qué se hizo |
|---|---|---|
| Aceptar «2 cambios» cubría cualquier par: un cambio nuevo se perdía sin aviso | coordinador (alta) | lo aceptado son las filas del aviso (D7) |
| `acknowledgeBlocked()` borraba la aceptación con el cierre trabajando, disparado por el doble cierre del alert del desasociar | coordinador (media) | solo con la fase bloqueada, y `dismissBlocked()` una sola vez |
| El mínimo de 3 rechazos lo cumplía un solo gesto | canal (media) | uno por hora como mucho (D1) |
| El pull no tenía tests, y una aserción de `.coalesced` no mordía | canal (media) | test gemelo del pull; aserciones con el testigo encendido |
| El test del invitado y el cuerpo de la hoja no detectaban sus mutantes | pantallas (media) | las dos ramas fijadas enteras |
| Inglés sin sujeto, identificador duplicado en la hoja, cifra de Ajustes y llamadas de salir de un grupo sin vigilar | pantallas (baja) | arreglados |
| El canario de la oferta cuenta ofertas, no personas | coordinador (baja) | documentado (D11) |
| Filas aceptadas en un cierre que no llega a armar el borrado; racha en la copia de iCloud; reloj atrasado 24 h | coordinador y canal (baja) | residuales en `gateway-attest.md` y en sus tickets |
| El invitado lee «tus grupos» sobre cambios ajenos | pantallas (baja) | aceptado: el precedente de esa pantalla ya se lo dice (`neutralBlockedTitle`, `channelPaused`) |

