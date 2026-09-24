# El teléfono que perdió el relevo de una activación no debe seguir subiendo datos encima del que tomó el relevo

## Contexto
Residual medium de Cola A (callejón nube) abierto en la review adversarial de `migration-takeover-uploads-without-a-lineage-check` (PR #236, mergeado a 2.1 hoy). Ese PR protege a quien TOMA el relevo (B): no sube un corpus sin linaje. No cierra el caso del teléfono A que YA era líder, perdió el lease por >60 min de silencio, y al recuperar red sigue en `uploadingSnapshot` subiendo páginas encima de lo que B ya puso.

Quien recibe este encargo arranca en contexto limpio. Ticket: `tickets/backlog/displaced-migration-leader-keeps-uploading-after-a-takeover.md` (al tomar el encargo muévelo a in-progress y actualiza `docs/TICKETS.md`). Lee también `docs/ESTADO.md` (sesión #236) y el ticket padre en `tickets/qa/migration-takeover-uploads-without-a-lineage-check.md` solo para no deshacer su guarda de linaje.

Cola A autónoma sigue ON. Device-QA del #236 (relevo legítimo, dos iPhone, 61 min) corre en paralelo y NO frena este código.

## Que se pide
Cierra el dead-end de producto: un teléfono que perdió el lease de la migración no sube ni una página más a la cuenta; sale con el texto de «otro dispositivo tomó el relevo» sin esperar al cutover.

Lo medido en el ticket (código, sin ejecutar):
- `MigrationRunner.driveUpload` no mira el lease.
- El heartbeat `other_leader` (`MigrationWorkExecutor.sendLeaseHeartbeatIfDue`) solo deja rastro.
- `/sync/push` solo mira `reverse_frozen_at`, no quién lidera.
- A solo sale en cutover pending con `ForwardStepBlocker.otherDevice`; B en verify puede mezclar corpus.

Candidatas del ticket (elige la más robusta / buena práctica, no la más simple):
- Que `other_leader` del heartbeat corte la subida de forma definitiva, con heartbeat SIN throttle al empezar cada pasada (un relevo exige 60 min de silencio; dentro de una pasada viva no puede ocurrir).
- O guarda de lease en el servidor en `/sync/push` mientras `migration_in_progress` (exigiría `device_id` en el push; toca Worker).

MODO AUTÓNOMO HASTA TERMINAR: implementa, gate, commit, docs/board del repo, actualiza `docs/TICKETS.md`, PR, merge a 2.1 y `/cerrar-total` sin preguntar si corres el gate o el commit. La regla del repo «espera aprobación si >3 ficheros» / «¿Sigo?» tras el plan queda suspendida en este encargo: sigue hasta cerrar. Bugs o decisiones nuevas → ticket propio (`--solo-crear`) antes de cerrar. Board Yala = ficheros en `tickets/` + índice; create/move tú.

Decisiones de producto/técnicas: elige siempre la opción más robusta / buena práctica (nunca la más básica). De día (06:00–21:00 Lima) puedes usar AskUserQuestion solo si hace falta acceso/dispositivo/secretos de Jürgen o una decisión demasiado grave para asumir; si no, decide y sigue. De noche: decide o aparca en ticket.

Avisos al bot dueño (Frank): POSTea al webhook local de la Mini (URL y key en fichero local, no en git; no las escribas en el repo) cuando:
  (1) necesitas una decisión de producto o de acceso de Jürgen;
  (2) abriste el PR o dejaste preview/artifact listo;
  (3) terminaste el ticket y vas a /cerrar-total — incluye en el aviso un resumen corto de cierre en lenguaje de usuario (qué se hizo), no solo «cerré»;
  (4) acabaste un tramo y no tienes siguiente paso claro (aunque no haya pregunta formal) — una vez, no en bucle.
NO avises por: un test rojo que vas a reclasificar, un build que vas a reintentar, ni ruido de CI advisory.

## Que NO hay que tocar
- marketing/ ni Web/ (Lola).
- No deshacer la guarda de linaje del #236 ni el claim/adopt de #234–#235.
- No paralelizar otro ticket de Cola A en esta sesión.
- No inventar PASS de device-QA ni cerrar tickets de QA ajenos.
- Secrets.xcconfig ya va por `.claude/worktree-enlaces`; no copiar a mano salvo que falte el enlace.

## Como se sabe que esta bien
- Criterios del ticket cumplidos (aceptación).
- Gate verde (o residuales con ticket propio); UI tests advisory no bloquean merge.
- Ticket a `qa` (si hace falta guion device) o `done` según el propio criterio del ticket; `docs/TICKETS.md` y `docs/ESTADO.md` al día; PR mergeado a 2.1; `/cerrar-total`.

## Paso 0

Decisiones tomadas por la sesión (MODO AUTÓNOMO, sin preguntas: ninguna es de producto ni de acceso).

1. **Mecanismo: puerta de lease en el cliente antes de CADA página, no guarda en `/sync/push`.** La guarda de servidor
   exigiría `device_id` en el push; los builds en la calle no lo mandan, así que tampoco los protegería, y metería el lease
   en el camino caliente de todos los teléfonos en nube (la misma razón por la que I14-pre llevó el latido al RPC). La
   puerta cubre cada página, no solo cada pasada: una pasada suspendida más de 60 min se reanuda a mitad.
2. **Prueba de lease = un `ok` del latido de hace menos de 60 s**, medido con `ContinuousClock` (cuenta el reposo del
   teléfono y no retrocede si alguien cambia la hora). Sin prueba reciente se late en el acto, sin throttle. Margen:
   60 s contra un lease de 60 min.
3. **«Perdido» = `other_leader` o `not_in_progress`.** El RPC mira «¿hay migración en curso?» ANTES que «¿quién lidera?»
   (medido en el cuerpo vivo de producción), así que cuando B ya terminó, A recibe `not_in_progress`. A, en la subida, no
   puede recibirlo por un camino legítimo: solo otro dispositivo cierra la migración que A abrió.
4. **Lo demás no sube y no sale:** red, 5xx o `no_profile`/`bad_action` → la pasada espera como la red; sesión borrada
   por el SDK → `sessionExpired`, igual que el push. Falla cerrado y vuelve a preguntar en cada pasada: nada se cachea,
   porque el mismo teléfono puede volver a liderar tras «Reintentar».
5. **Salida inmediata, no a los 15 min**: evento nuevo `migrationLeaseLost` → `failedRollback` con `[.rollback]`. El
   `other_leader` no se arregla esperando y la subida ya está parada; 15 min de barra quieta no protegen nada. El cutover
   conserva su techo de 15 min para el mismo motivo: no se toca (fuera del encargo).
6. **Texto: el que ya existe**, `storage.failed.stepOtherDevice`, vía `forwardStepExitReasonRaw = otherDevice`. Sin strings
   nuevos. Dice «Tus datos siguen aquí, sin cambios», y es verdad: la subida no toca la base local.
7. **La verificación de la ida también pasa por la puerta.** Empuja el outbox y trae el corpus de la cuenta: el líder
   desplazado que vuelve con el journal en `verifying` subiría y mezclaría igual. Misma salida.
8. **El latido tras cada página se retira de la subida**: la puerta lo sustituye (≤ 1/min). La vuelta a iCloud sigue con
   `sendLeaseHeartbeatIfDue` tal cual. **Cambio de significado aceptado (lo cazó la review):** antes solo latía una página
   confirmada; ahora late toda pasada que pregunta, avance o no. El lease pasa a decir «el líder está vivo»: el líder sin
   red lo pierde igual a los 60 min, y el conectado cuyo push falla lo conserva hasta su techo, en vez de cedérselo a otro
   y volver luego a subir encima, que es este bug.
11. **La confirmación también caduca a media página (lo cazó la review):** una página son varios trozos de 50 filas, y la
    app congelada entre dos trozos más de 60 min reanudaría el siguiente sin preguntar. Antes de cada trozo, y antes del push
    y del pull de la verificación, la confirmación tiene que tener menos de 30 min; si no, la pasada se corta sin error y la
    siguiente vuelve a preguntar. 30 y no 60 s, para que una página lenta no se corte sola.
9. **El requisito del protocolo va SIN default**: un default `.held` sería una puerta que falla abierta en cualquier
   conformador que se olvide de implementarla.
10. **Worker de producción medido**: su última versión (2026-09-10) ya acepta `heartbeat`; el `account.ts` de HEAD solo
    difiere en comentarios. Sin eso, la puerta habría parado todas las subidas.

Asumido y fuera: la bienvenida muestra la salida `otherDevice` como `.error(retryable:)` («Revisa tu conexión»), igual que
hoy la del cutover → ticket propio.
