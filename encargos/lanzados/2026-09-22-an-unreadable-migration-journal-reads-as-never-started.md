# Si el registro de la migración no se deja leer, la app ya no dice que nunca empezó ni borra el motivo del aborto

## Contexto
Cola A autónoma de Yala (rama 2.1), en serie tras el cierre limpio de `forward-migration-steps-have-no-ceiling-and-no-exit` (PR #214 mergeado). Device-QA de ese ticket queda en qa y no frena código.

Ticket: `tickets/backlog/an-unreadable-migration-journal-reads-as-never-started.md` (very-high). Misma familia que `verify-reads-a-failed-local-fetch-as-an-empty-outbox`: un fallo de lectura local no puede convertirse en un permiso o en un estado mentiroso.

Quién arranca: contexto limpio. Lee el ticket, `docs/ESTADO.md` (sesión #214), la regla en `.claude/rules/swiftdata-cloudkit.md` («El par que apaga el mirror»), y los vecinos del mismo patrón citados en el ticket.

## Que se pide
1. Una lectura fallida del journal NO se presenta como `notStarted` (fase estable).
2. Esa lectura fallida NO borra `cutoverBlocker` / `reverseAbortReason` / `hasPendingReverseExit`.
3. La pantalla de Almacenamiento dice algo honesto cuando el journal no se deja leer.
4. Test con la lectura lanzando + control positivo.
5. Revisa también los tres `try?` de la misma pantalla (`refreshSyncBanner`, `reverseEligibility`, `dryRunCounts`) y aplícales el mismo criterio de default seguro, uno a uno, sin ampliar el alcance a otros sitios.

## Decisiones (regla Jürgen 2026-09-22: opción más robusta / buena práctica, nunca la más básica)
- Preferir un desenlace honesto de «no pude leerlo» (fase o error de superficie) frente a mentir `notStarted`.
- Sacar del `catch` cualquier escritura que limpie el motivo del aborto: una lectura no escribe.
- Defaults de los `try?` de superficie: el que no invente progreso ni elegibilidad falsa.
- Estamos en horario diurno Lima (6:00–21:00): si una decisión de producto o de acceso de Jürgen es REALMENTE necesaria, usa AskUserQuestion. Si no lo es, elige la opción robusta y sigue.

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board del repo, actualizar `docs/TICKETS.md`, PR, CI, merge a 2.1 y `/cerrar-total` sin preguntar si corre el gate o el commit. Bugs/decisiones nuevas → ticket propio (`--solo-crear`) antes de cerrar. Solo parar ante decisión/acceso real (AskUserQuestion de día). Board Yala: create/move directo en `tickets/` (sin inbox Tim).

OVERRIDE (Jürgen 2026-09-22): en esta cola autónoma, la regla del repo «espera aprobación si >3 ficheros» / «¿Sigo?» tras el plan queda SUSPENDIDA — implementa hasta el cierre sin pedir continuar.

Al empezar: mueve el ticket a `in-progress` y deja `docs/TICKETS.md` al día. Al cerrar con device-QA pendiente: déjalo en `qa` con guion; si no hace falta QA manual: `done`.

## Que NO hay que tocar
- `marketing/` / Web/ (Lola).
- No reabrir el techo de los pasos 22/35/80 % ya cerrado en #214 salvo bug real nuevo con ticket.
- No paralelizar otro ticket de la misma familia en este worktree.
- Secrets: no pegar en el repo.

## Como se sabe que esta bien
- Criterios del ticket marcados.
- Gate verde (build + unit + XCUITest del alcance) sin warnings nuevos atribuibles.
- Mutantes del cambio muertos o justificados.
- PR mergeado a 2.1 + `/cerrar-total` + board e índice al día.
- Aviso de cierre al bot dueño (Frank) con resumen en lenguaje de usuario (qué cambió / necesita de ti / encontrado).

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL y key en fichero local, no en git; no las escribas en el repo) cuando:
  (1) necesitas una decisión de producto o de acceso de Jürgen;
  (2) abriste el PR o dejaste preview/artifact listo;
  (3) terminaste el ticket y vas a /cerrar-total — incluye un resumen corto de cierre en lenguaje de usuario;
  (4) acabaste un tramo y no tienes siguiente paso claro — una vez, no en bucle.
NO avises por: un test rojo que vas a reclasificar, un build que vas a reintentar, ni ruido de CI advisory.

## Paso 0

*Resuelto por Frank el 2026-09-22, sin nadie delante (cola A autónoma). Todas las decisiones son técnicas; ninguna
es de producto ni de acceso, así que ninguna pregunta.*

**Premisas medidas, no heredadas.** Las coordenadas del ticket envejecieron con #214 (`readJournalSnapshot` está en
la 1289, no en la 1229). La tabla de vecinos cuenta TRES `try?` en la pantalla y hay CUATRO: falta
`markerDecision()`. Y la lectura del journal que pierde el motivo no borra nada DURABLE — limpia seis espejos en
memoria del controller—, pero uno de ellos (`hasPendingReverseExit`) es el que frena una vuelta nueva encima de
una salida a medias: limpiarlo en el `catch` era también un permiso.

1. **La lectura fallida tiene su propio valor, no una fase.** `JournaledPhaseRead { .phase(MigrationPhase), .unreadable }`.
   No se añade un case a `MigrationPhase`: es un enum journaleado con fixtures APPEND-ONLY y veinte `switch`
   exhaustivos que clasifican fases REALES; «no pude leerlo» no es una fase por la que pase la máquina.
2. **`MigrationPhaseStore.currentPhase` cambia de tipo y de nombre** (`currentPhaseRead`). Conservar un getter que
   devuelva `MigrationPhase` es dejar la trampa puesta para el siguiente consumidor. Cada uno de los siete se
   pronuncia, y todos hacia el lado que no concede: tareas en segundo plano → la clasificación de fase TRANSITORIA
   (lector suspende, escritor exige quiescencia); motor del dominio → no arranca; remap de identidad → bloqueado;
   drenaje iKV→outbox → no drena (tiene centinela, reintenta en el arranque siguiente).
3. **La ventana de captura de identidad no se decide con una lectura fallida, ni hacia un lado ni hacia el otro.**
   Encenderla por las dudas contradice «no se enciende globalmente» (I14) y un arranque prewarm la encendería en
   medio parque; dejarla apagada pierde la identidad de lo creado en la ventana. Se APLAZA: `configure` apunta que
   no pudo derivarla y la deriva la primera lectura buena.
4. **El controller no escribe nada cuando no lee.** El lector pasa a una función pura (`MigrationJournalSnapshot.read`)
   cuyo caso `.unreadable` no lleva valores: aplicar el snapshot en el controller es un `switch` en el que la rama
   ilegible no tiene qué asignar. Los seis campos conservan su último valor leído.
5. **Las cuatro decisiones del controller con el journal ilegible no hacen nada**: ni retomar, ni sondear al líder,
   ni re-kickear, ni arrancar el motor. El re-kick de primer plano SÍ refresca si la pantalla se había quedado en
   «no pude leer» y ahora lee: sin eso, un arranque prewarm dejaría la fila de Ajustes abierta y el aviso de cambio
   de Apple ID apagado todo el proceso.
6. **Estado de UI propio: `CloudMigrationUIState.journalUnreadable`.** La pantalla dice que no pudo leer en qué punto
   está el paso de los datos, que lo vuelve a intentar sola (ya refresca cada segundo) y que, si sigue, se cierre y
   se vuelva a abrir Yala. Sin botones de migrar, volver, retomar ni cancelar. **Conserva la sección de Grupos**,
   como `.failed` y `.waitingForLeader`: puede durar, y ocultarla quitaría la única puerta para soltar esa cuenta.
   El relanzamiento pendiente hacia la nube (`mirrorOffArmed` + espejo montado) sigue ganando: no depende del journal.
   `canCancelMigration` y `canCancelReverse` dan `false` mientras dure, para que un diálogo abierto no reaparezca.
   El onboarding (`CloudWelcomeSignInFlow`) lo trata como error reintentable, y deja de re-arrancar un adopt por
   leer `.idle` de un journal que no se leyó.
7. **Los cuatro `try?` de la pantalla, uno a uno:**
   - `refreshSyncBanner` → el motor ya está parado hasta firmar; si la cola no se deja contar, se ofrece firmar SIN
     cifra (copy nuevo). El default de hoy pintaba «Todo sincronizado» con el motor parado.
   - `reverseEligibility` → no elegible (no se concede con un dato que no se leyó) pero con su propio motivo,
     `mapUnreadable`, en vez de `degradedNoMap`. El born-cloud de este dispositivo no necesita el mapa y sigue
     elegible. La frase en pantalla («Ahora mismo no puedes…») ya es cierta en los dos casos.
   - `dryRunCounts` → sin cifras: «no pudimos contar tus datos» (copy nuevo). Un cero inventado era el peor default.
   - `markerDecision` → se queda en `false` («Migrar»), que es el lado seguro: la regla de las dos capas impide que
     «Migrar» adopte. Solo pasa de `try?` a `do/catch` con rastro.
8. **Rastro en producción**: `migrationJournalUnreadable(reader:)`. El controller lo emite en la TRANSICIÓN (la pantalla
   lee cada segundo); el store en cada lectura (sus consumidores son discretos).
9. **Fuera, con ticket si no lo tiene**: el `readPhase()` que decodifica mal un `phaseData` presente y devuelve
   `notStarted` (mismo desenlace por otro camino; tiene fixture APPEND-ONLY y breadcrumb ruidoso).

**Asumido:** copy nuevo en los 16 idiomas con `qa/scripts/add-l10n-key.sh`; tests con fetch que lanza por seam
(molde `_testOutboxFetchThrowsFromCall`) o closure; el controller se cubre por función pura + scan del cuerpo
entero, porque no se puede instanciar en tests. Review adversarial: sí (migración + estado de sync).
