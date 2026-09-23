# Al entrar en tu cuenta de la nube, el claim del 22 % ya no se queda parado para siempre sin salida

## Contexto
Cola A reanudada tras pausa por cambio de cuenta Claude (Jürgen 2026-09-23 ~08:01 Lima). Último merge #220 (inventario incompleto). Este ticket es high residual de `forward-migration-steps-have-no-ceiling-and-no-exit`: el techo/Cancelar del claim del 22 % quedó solo para «Migrar»; en la intención adopt («Ya tengo una cuenta» / «Activar la nube en este dispositivo») un fallo definitivo (sesión borrada, 403) deja la barra al 22 % sin salida usable.

Ticket: `tickets/backlog/adopt-claim-stays-parked-with-no-ceiling.md`
Rama base: origin/2.1

## Que se pide
1. Leer el ticket entero y el fix hermano de forward claim (techos 15 min / 72 h, Cancelar, textos por motivo).
2. MODO AUTÓNOMO HASTA TERMINAR: gate, commit, docs/board del repo, actualizar `docs/TICKETS.md`, merge y /cerrar-total sin preguntar si corre el gate o el commit. Bugs/decisiones nuevas → ticket propio antes de cerrar. Board: create/move directo.
3. OVERRIDE DE PROCESO (Jürgen 2026-09-22, vigente hasta que CLAUDE.md/frank lo diga solo): en esta cola el «espera aprobación si >3 ficheros» y el «tras implementar resume y para; no encadenes tests/QA/commits» quedan SUSPENDIDOS. Implementa, gate, PR, CI, merge y /cerrar-total sin «¿Sigo?» ni dejar el merge a Jürgen. Device-QA de iPhone: ticket a `qa` con guion; no frena el merge.
4. Día (6:00–21:00 Lima): AskUserQuestion a Jürgen solo para decisiones REALES de producto o acceso. Recomendado (norma robusta Yala — elige la opción más robusta / buena práctica, nunca la más simple):
   - Mismo techo que Migrar: 15 min motivos definitivos / 72 h cualquier causa, por intento de claim.
   - «Cancelar» con confirmación y textos que NO digan «tus datos siguen en este dispositivo» cuando es un teléfono vacío/reinstalado.
   - Salida del techo: vuelve a un sitio desde el que se pueda entrar otra vez en la cuenta (no a «Migrar» bloqueado).
   - 403 / sesión borrada: avisar en cuanto se sepa (no solo esperar el techo), como ya hace el Welcome mientras está delante.
5. Criterios del ticket: claim adopt con techo + salida reentrable; ningún texto falso sobre datos locales; test con fallo persistente midiendo cambio de fase.
6. Residuales fuera de alcance → ticket propio en backlog antes de cerrar.

## Que NO hay que tocar
- marketing/ / Web/ (Lola).
- Ampliar el techo de «Migrar» (ya cerrado) salvo reutilizar el mismo patrón.
- Device-QA manual en iPhone como bloqueo de merge.

## Como se sabe que esta bien
- Gate verde; PR mergeado a 2.1; ticket en qa o done según device-QA; `docs/TICKETS.md` al día; /cerrar-total OK.
- Tests del fallo persistente en adopt claim.
- Avisos al bot dueño (Frank): POSTea al webhook local de la Mini (URL y key en fichero local, no en git) cuando (1) decisión de producto/acceso de Jürgen; (2) PR o preview listo; (3) terminaste y vas a /cerrar-total — resumen corto en lenguaje de usuario; (4) acabaste un tramo sin siguiente paso claro (una vez). NO por test rojo que reclasificas, build a reintentar ni ruido CI advisory.

## Avisos / Activity
Al terminar Frank apunta Actividad. Tras /cerrar-total exitoso mata tmux residual sin preguntar.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones del encargo se dan por buenas y el resto lo decide la sesión.
> Se discuten en el PR. Medido en este árbol (`f036277c`).

**Hechos medidos.** El claim del adopt corta sin evento en `MigrationRunner.driveClaim` (`guard intent == .migrateOnly
else { return false }`, tres ramas). La máquina YA acepta `.forwardStepStalled` y `.forwardStepCancelled` desde
`claimingMigration` sin mirar la intención: el corte es solo del runner y de `ForwardCancelScope`. `forwardClaimIntentRaw`
se borra al entrar en `failedRollback`/`notStarted`, y `resetAfterRollback` borra `forwardStepExitReasonRaw`: tras
«Reintentar» no queda ningún rastro de que el intento era un adopt. La tarjeta de `.idle` solo enseña «Activar la nube en
este dispositivo» con marcador de CloudKit (`markerDecision() == .secondaryDeviceCloudLogin`). Tras volver del Welcome
(`.accountBlocked`/`.error`) la persona cae en la app con el onboarding marcado y el journal en `claimingMigration`. El
seguidor (`waitingForLeader` → `pollLeader`) también reclama sin techo, pero es otra fase.

**D1 · ¿Techo en el claim del adopt?** → Sí, el mismo de «Migrar»: 15 min acumulados con un motivo definitivo (sesión
borrada por el SDK, 403), 72 h sin avanzar con cualquier causa, por intento. Se reusa `observeForwardStepStall` tal cual.
Por qué: el encargo lo recomienda y un solo mecanismo por paso no diverge. Alternativa descartada: sin techo para la red
(«se cura sola»): 72 h sin red no es una espera normal.

**D2 · ¿A dónde sale?** → A `failedRollback`, como «Migrar», con texto propio del adopt; «Reintentar» lleva a
Almacenamiento, que ahora enseña «Activar la nube en este dispositivo» aunque no haya marcador. Lo sostiene una marca
journaleada nueva (`MigrationState.adoptClaimExitRaw`, schema 11) que escribe la salida del claim del adopt, sobrevive a
`failedRollback`, a «Reintentar» y a `notStarted`, y se borra cuando otro claim empieza. Por qué: la tarjeta de adopt ya
conduce el camino entero (consentimiento → cuenta → claim `adoptIfExisting`, sin la puerta de «Migrar») y el Welcome
mapea `.failed` a su error con «Reintentar», que ya resetea. Alternativas descartadas: salir directo a `notStarted` (el
Welcome pinta `.idle` como progreso al 0 % y el auto-resume lo repetiría en bucle); reabrir el Welcome (segundo anchor, y
el onboarding ya está marcado).

**D3 · ¿«Cancelar» en el claim del adopt?** → Sí, el mismo botón y la misma confirmación, con cuerpo propio: «Lo que
tienes en la nube sigue ahí, sin cambios. Puedes volver a entrar en tu cuenta desde aquí cuando quieras.» Sale a
`notStarted` con la marca de D2, así que la pantalla enseña la tarjeta de adopt. Por qué: «Tus datos siguen en este
dispositivo» es falso en un teléfono recién instalado.

**D4 · ¿Avisar del 403 o la sesión borrada antes del techo?** → Sí, en la tarjeta de progreso del 22 %, solo con adopt:
«Tu sesión en la nube ya no es válida. Cancela y vuelve a entrar con tu cuenta.» / «Tu cuenta en la nube no permite
entrar ahora. Escríbenos a …». Se lee del reloj de causa journaleado (`forwardStepStallCauseRaw`), que solo guarda motivos
definitivos y sobrevive a un relanzamiento. Por qué: es lo que el Welcome ya hace mientras está delante; leerlo del
journal evita el `lastClaimBlocker` en memoria, cuyo `.sessionExpired` incluye el 401 con la sesión guardada (no
definitivo). Alternativa descartada: extenderlo a «Migrar» (fuera del ticket; queda en un ticket propio).

**D5 · Textos.** → Seis claves nuevas en los 16 idiomas: tres de la tarjeta de fallo del adopt (días sin avanzar, sesión
caducada, cuenta que no lo permitió con el correo), el cuerpo del diálogo y los dos avisos del 22 %. Ninguna habla de
datos en este dispositivo.

**D6 · La tarjeta de adopt sin marcador, ¿abre algo peligroso?** → Aceptado con su porqué. La marca solo la deja un
adopt que ESTE teléfono empezó (Welcome con su guard cross-cuenta, o la tarjeta de adopt), y la tarjeta conserva su
comprobación del faro (`signInDecision(isAdopt:)` → `.blockedOtherAccount`). Con la sesión borrada la persona elige
cuenta otra vez, igual que en la tarjeta de adopt de hoy.

**D7 · Fuera de alcance → ticket.** El seguidor sin techo (`waitingForLeader` con 403/sesión borrada) y el aviso temprano
en el claim de «Migrar».

### Paso 0 revisado tras la review adversarial (2026-09-23)

**D4 (revisada) · De dónde lee el aviso del 22 %** → De lo que vio el último claim (`MigrationRunner.lastClaimDefinitiveCause`,
en memoria), no del reloj de causa journaleado. Por qué: el reloj PAUSA sin borrar la causa, y el aviso seguía diciendo «tu
sesión ya no es válida» con la sesión recuperada y la red caída (dos lentes). Se pierde que salga nada más abrir tras
relanzar; lo repone la primera observación del arranque.

**D6 (revisada) · La tarjeta de adopt sin marcador** → Atada a la cuenta del intento (`adoptClaimAccountHash`, apuntada al
entrar en el claim): sin sesión o con la de esa cuenta se ofrece; con otra, no; y tras firmar otra cuenta en el chooser no
se adopta. Por qué: la lente de consumidores midió que con la sesión de Grupos de otra cuenta la tarjeta adoptaba esa y le
subía lo local, sin la puerta de «Migrar». La aceptación inicial de D6 era falsa: suponía que la sesión sería la del
intento. La marca también se borra al volver a iCloud.

**D5 (revisada) · Textos** → Siete claves. Ninguna afirma el estado del servidor («sin cambios»): dicen lo que este
dispositivo hizo. El 403 usa la frase del Welcome.
