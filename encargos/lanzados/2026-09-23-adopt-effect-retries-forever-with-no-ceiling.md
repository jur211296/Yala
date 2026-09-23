# Si entrar en tu cuenta de la nube no puede terminar, la app lo reintenta para siempre sin decírtelo

## Contexto
Cola A autónoma reanudada tras cerrar #225 (TestFlight 14 VALID en grupo interno). Device-QA del guion `qa/guion-tanda.md` corre en paralelo con Jürgen y NO frena esta cola de código.

Ticket: `tickets/backlog/adopt-effect-retries-forever-with-no-ceiling.md` (medium, área modo-nube/migración/adopt). Sale de la review de `an-incomplete-inventory-reads-as-the-whole-corpus`: al adoptar, si la reconciliación de huérfanas no puede terminar (red o tabla local ilegible), el efecto queda en reintento eterno, Almacenamiento pinta idle, sin tarjeta ni salida. Es el mismo hueco que ya se cerró en los pasos de la ida (`forward-migration-steps-have-no-ceiling-and-no-exit`) y en el claim del adopt (`adopt-claim-stays-parked-with-no-ceiling`, #221).

ARRANCAS EN CONTEXTO LIMPIO. Lee el ticket, `docs/ESTADO.md`, y los PRs/reglas de techos ya mergeados (CauseStallClock, StorageFailureCopyLogic, adopt-claim). No toques marketing/ ni Web/.

## Que se pide
Cierra el callejón del adopt-effect: techo + texto + salida cuando la reconciliación no puede terminar, con tests.

MODO AUTÓNOMO HASTA TERMINAR: gate, commit, docs/board del repo, actualizar `docs/TICKETS.md`, merge a `2.1` y `/cerrar-total` sin preguntar si corre el gate o el commit. Bugs/decisiones nuevas → ticket propio antes de cerrar. Board: create/move directo en `tickets/` (sin inbox Tim). Mueve este ticket a `in-progress` al empezar; al cerrar, a `qa` solo si hace falta device-QA manual, si no a `done`.

OVERRIDE de la regla «espera aprobación si >3 ficheros» / «¿Sigo?» tras el plan: NO preguntes para seguir implementando. Implementa hasta gate/PR/merge/cerrar-total. Solo paras ante decisión de producto/acceso real vía AskUserQuestion (horario diurno 6:00–21:00 Lima).

DIA (AskUserQuestion): el ticket pide decisión de Jürgen sobre (1) techo corto vs largo, (2) texto al vencer, (3) salida (ojo: `failedRollback` → Reintentar → `notStarted` es callejón para quien adopta; #221 ya eligió salida a «Activar la nube en este dispositivo»). Recomendación robusta a ofrecer: mismo patrón que ida/claim — corto (15 min) para causa definitiva/local que esperar no arregla, largo (72 h) para red; Cancelar; copy honesto por motivo; salida que no deje al adoptante en un bucle. Si Jürgen no contesta a tiempo y el riesgo es reversible, aplica esa recomendación y anótalo en el ticket/ESTADO.

Regla de producto: entre opciones, elige la más robusta / buena práctica, nunca la más simple.

## Que NO hay que tocar
- marketing/, Web/, store copy.
- Relanzar tickets ya en `qa` (device-QA de Jürgen).
- Pedir beta review del TestFlight ni subir otro build salvo que el ticket lo exija (no lo exige).
- Inventar device-QA si el escenario no se monta a voluntad en un iPhone.

## Como se sabe que esta bien
- Un adopt que no puede terminar por causa que esperar no arregla sale con techo, texto y salida acordados; hay test.
- Gate verde; mutantes del cambio muertos si aplica.
- Ticket y `docs/TICKETS.md` al día; `docs/ESTADO.md` actualizado; PR mergeado a `2.1`; `/cerrar-total`.
- Avisos al bot dueño (Frank): POSTea al webhook local de la Mini (URL y key en fichero local, no en git) cuando (1) necesitas decisión de producto/acceso de Jürgen; (2) abriste el PR o dejaste preview/artifact listo; (3) terminaste y vas a /cerrar-total — incluye resumen corto de cierre en lenguaje de usuario; (4) acabaste un tramo sin siguiente paso claro (una vez). NO avises por test rojo que reclasificas, build que reintentas, ni ruido CI advisory.

## Paso 0 — decisiones

> Las tres de producto las contestó Jürgen el 2026-09-23 (15:40 Lima) eligiendo la recomendación en las tres. El resto lo
> decide la sesión. Medido en este árbol (`2dd80e0f`).

**Hechos medidos.** `runAdoptOrphanReconcile` devuelve `.transient` tanto por la red (enumeración, Merkle, push) como por
la base local (inventario, backfill, fetch de huérfanas, outbox). `runAdoptFlow` lo convierte en
`adoptRetry(reason: "reconcileTransient")`, el runner lo deja pendiente (`drainPendingEffects` → `Stop.effectFailed`) y
`runGuarded` se lo traga. El par queda `(notStarted, [.adoptBackendAccount])` con `.icloud` persistido: el paso 5
(`writeCloudArmed`) va DESPUÉS del reconcile y desde ahí nada lanza. `CloudMigrationUIStateDeriver` pinta `.idle` en
`notStarted` + `.icloud`, y el Welcome lo lee como `.adopting(0)`. El re-kick de 30 s de Almacenamiento lo reintenta, y
cada intento enumera el backend entero antes de leer el inventario local.

**D1 · Techo (Jürgen).** → 15 min ACUMULADOS con la base local que no se deja leer, 72 h desde el primer intento fallido
con cualquier causa. El corto usa `CauseStallClock.observeAnyDefinitive` (hoy el único motivo definitivo del adopt es la
base local; la red lo PAUSA, no lo borra, por el re-kick de 30 s). El largo se sella en la primera observación.

**D2 · Mientras espera (Jürgen).** → Almacenamiento enseña la tarjeta de progreso con «Retomar» y «Cancelar la
activación» en vez de `.idle`: `.migrating` con la fase journaleada (`notStarted`) y una fracción propia. Cancelar sale a
`notStarted` sin el pendiente y deja la marca del adopt (`adoptClaimExitRaw = cancelled`), así que la pantalla ofrece
«Activar la nube en este dispositivo», igual que el claim del adopt (#221). El diálogo usa el cuerpo del adopt.

**D3 · Salida al vencer (Jürgen).** → `failedRollback` con `[.rollback]`, la misma salida del claim: tarjeta de fallo con
texto por motivo y «Reintentar», que lleva a «Activar la nube en este dispositivo» por la marca. En el Welcome `.failed`
ya es `.error(retryable: true)`, cuyo reintento resetea y vuelve a entrar.

**D4 · Textos (Jürgen).** → Dos claves nuevas en los 16 idiomas. Ninguna dice «no cambiamos nada en la nube»: el
reconcile puede haber subido algo de este teléfono antes de fallar.

**D5 · ¿Marca nueva o la del claim?** → La del claim: `AdoptClaimExit` gana `effectLocalFailure` y `effectStalled`
(append-only). La marca ya hace lo que hace falta —elige el texto, sobrevive a «Reintentar», ofrece la tarjeta y está
atada a la cuenta del intento, que se apunta al entrar en el claim, antes del efecto—. Un campo paralelo duplicaría
`offersReentry`. Schema 13 → 14 por los tres campos del reloj (`adoptEffectStall*`).

**D6 · ¿Quién reinicia el reloj?** → El adopt que termina (en el mismo save que borra el pendiente) y cualquier `handle`
(un claim nuevo, la cancelación, la salida). Desde la UI solo «Cancelar», que ya es salida. Relanzar no lo reinicia:
está en el journal. Un claim nuevo lo reinicia a propósito; sin eso el intento siguiente heredaría el sello y saldría con
cero segundos.

**D7 · Sin techo si el adopt ya persistió `.cloud`.** → Un kill entre `writeCloudArmed` y el borrado del pendiente
relanza con `.cloud` + pendiente. Salir de ahí a `failedRollback` es el terminal «pelado» que la regla del cutover
prohíbe. Ese caso sigue reintentando como hoy (no se provoca sin un kill en una ventana de milisegundos).

**D8 · Coste.** → El reconcile lee el inventario local ANTES de la red: una avería local deja de pagar la enumeración
entera en cada reintento. No cambia ningún desenlace.

**D9 · Fuera de alcance → ticket.** La sesión borrada por el SDK y el 403 en la enumeración del adopt siguen yendo al
plazo largo (la enumeración los aplana a `nil`). Tiparlos pide un texto que Jürgen no ha visto.

**D10 · La sesión del intento al cancelar.** → Se cierra, como en el claim (`closeSessionIfOpened`), pero solo si el
cancelar ocurrió: la guarda pasa a exigir que el modo no sea `.cloud`. Sin ella, un «sí» que llegara tarde con el adopt ya
terminado cerraba la sesión de una cuenta recién adoptada; la misma carrera existía desde el claim.

### Paso 0 revisado tras la review adversarial (2026-09-23)

**D4 (revisada, Jürgen) · Textos.** → «Tus datos siguen en este dispositivo» se cambia por «Lo que tienes en este
dispositivo sigue aquí» en los dos textos. Por qué: la frase era la que #221 prohibió para el adopt; en un teléfono recién
instalado los datos están en la nube (lo cazaron dos lentes). pt-PT vuelve a «você/a sua» y zh-Hans a 您, como el resto
de la pantalla, y cada idioma toma el arranque del texto del claim del adopt.

**D8 (revisada) · Coste.** → El inventario se lee una vez antes de la red como puerta, y el plan preliminar del guard
anti-fusión se vuelve a leer después de enumerar. Por qué: leído solo antes, lo creado o importado durante la enumeración
no contaba en el guard; «no cambia ningún desenlace» no era exacto.

**D10 (revisada) · La sesión al cancelar.** → Sin cambios en el código. La guarda nueva protegía una rama que no existe:
`migrationAttempt` solo se rellena con «Migrar», así que ni el claim del adopt (#221) ni su efecto cierran la sesión. Se
quita la guarda y va a ticket (`adopt-exit-keeps-the-session-it-opened`).

**D11 (nueva) · «Cancelar» antes de un intento que saldría bien.** → El «sí» apuntado se mira también ANTES de ejecutar el
efecto. Por qué: mirándolo solo al fallar, un re-kick en vuelo que acababa bien adoptaba a quien acababa de confirmar que
cancelaba.

**D12 (nueva) · La sección de Grupos.** → Se conserva bajo la tarjeta de progreso mientras el efecto se reintenta. Por
qué: puede durar 72 h y es la única puerta para soltar esa cuenta, como en `.waitingForLeader` y `.failed`.

**Fuera de alcance → ticket:** el Welcome no dice el motivo ni ofrece «Cancelar» durante el efecto
(`welcome-adopt-effect-failure-has-no-reason-and-no-cancel`); un import que no se asienta nunca no se observa
(`adopt-effect-ceiling-never-sees-an-import-that-never-settles`); el kill tras el paso 5 deja `.cloud` con el efecto
pendiente, «Todo sincronizado» en pantalla y el motor parado (`adopt-effect-after-the-cloud-mode-retries-silently`).
Residual de la clase ya abierta en `a-failed-snapshot-enqueue-save-leaves-the-journal-unsaved`: un `save()` local fallido
deja el contexto sucio y el sello del reloj tampoco llega a disco.
