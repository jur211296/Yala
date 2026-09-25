# Medir y, si aplica, cortar el relevo que duplica filas cuando las identidades del líder callado no llegaron por iCloud

## Contexto
Acaba de mergearse a 2.1 el PR #240 (`adopt-after-the-cutover-needs-a-marker-the-leader-never-exported`): tras el cutover, el segundo iPhone del mismo iCloud ya puede entrar en la cuenta aunque el primero no exportara su marca, siempre que iCloud le haya traído lo que el primero subió; si no, no sube nada para no duplicar.

La review adversarial de ese ticket (lente del dispositivo legítimo, misma familia en la ida) abrió este residual medium: el relevo (`checkForwardLineage` → `assignIdentity` → subida del snapshot) puede subir duplicados de lo que el líder callado ya subió si las identidades sintéticas no llegaron a B por iCloud. En el adopt ya se exige prueba de filas compartidas (`MigrationWorkExecutor.adoptSharedRowsProof`); aquí falta MEDIR si el relevo ya evita el duplicado (rebind con testigos, dedupe servidor, verificación de snapshot) y, si no, cortarlo.

Ticket: `tickets/backlog/migration-takeover-may-duplicate-rows-whose-leader-identities-never-arrived.md`
Cola A autónoma (mediums callejón nube). Un solo Claude Yala a la vez.

## Que se pide
1. Leer el ticket y el código del relevo / linaje / assignIdentity / snapshot upload. Medir (test o traza) si, con identidades del líder ausentes en B, el relevo duplica filas ya subidas por A.
2. Si NO duplica ya: documentar qué lo evita, cerrar el ticket con evidencia (done o qa según haga falta device-QA), actualizar `docs/TICKETS.md` / ESTADO.
3. Si SÍ duplica: el relevo no debe subir una fila cuya identidad del líder no llegó — esperar a que iCloud termine de traer, o salir con el texto de «espera a que iCloud termine de traer tus datos». Criterio robusto / buena práctica (no el más simple). Tests que fijen el bug como contrato.
4. Mover el ticket a in-progress al empezar; al cerrar → qa si hace falta device-QA en dos iPhone, o done si basta con test/código y no hay guion manual razonable. Actualizar `docs/TICKETS.md`.
5. Gate, PR a 2.1, merge, `/cerrar-total`. Bugs o decisiones nuevas de camino → ticket propio (`--solo-crear`) antes de cerrar.

## MODO AUTÓNOMO HASTA TERMINAR
Bypass: gate, commit, docs/board del repo, índice `docs/TICKETS.md`, merge y `/cerrar-total` sin preguntar. La regla del repo «espera aprobación si >3 ficheros» / «¿Sigo?» tras el plan queda SUSPENDIDA en este encargo: implementa hasta el cierre. Solo parar ante decisión/acceso real (AskUserQuestion vía webhook a Frank). Frank contesta él la opción robusta / Recommended sin despertar a Jürgen salvo device, secretos o decisión demasiado grave para asumir. Horario Lima diurno (antes de 21:00): AskUserQuestion permitido para producto/acceso; Frank decide robusto. Board de proyectos: create/move directo en tickets/ (sin inbox Tim).

## Que NO hay que tocar
- `marketing/` (Lola).
- Relanzar tickets ya en qa/done ni el settings-migrate «parado en Migrar» (ticket aparte `settings-migrate-blocks-a-second-device-before-its-marker`) salvo que midas que es el mismo bug.
- No inventar device-QA a Jürgen si el cierre es solo medición/código con tests.
- No tocar Web/ ni otros destinos.

## Como se sabe que esta bien
- Medido con evidencia si el relevo duplica o no en el caso del ticket.
- Si duplicaba: ya no sube filas cuya identidad del líder no llegó (espera o salida clara); tests verdes que lo fijan.
- Ticket e índice al día; PR mergeado a 2.1; `/cerrar-total` limpio.
- Resumen de cierre en lenguaje de usuario (Necesita de ti → Cambiado → Encontrado).

Avisos al bot dueño (Frank): POSTea al webhook local de la Mini (URL y key en fichero local, no en git; no las escribas en el repo) cuando:
  (1) necesitas una decisión de producto o de acceso de Jürgen;
  (2) abriste el PR o dejaste preview/artifact listo;
  (3) terminaste el ticket y vas a /cerrar-total — incluye en el aviso un resumen corto de cierre en lenguaje de usuario (qué se hizo), no solo «cerré»;
  (4) acabaste un tramo y no tienes siguiente paso claro (aunque no haya pregunta formal) — una vez, no en bucle.
NO avises por: un test rojo que vas a reclasificar, un build que vas a reintentar, ni ruido de CI advisory. URL/key solo en la Mini.

## Paso 0

- **Medido (lectura + test existente):** SÍ duplica. El servidor solo deduplica por identidad (`PRIMARY KEY (user_id, sync_id)`
  en las 16 tablas de `supabase-staging.ddl`); los testigos `SyncIdentity` son locales de cada teléfono (store de metadatos sin CloudKit), así que el rebind del relevo no tiene ninguno del líder; el `verify` hace pull ANTES del Merkle, así que trae
  las copias del líder al store local y el Merkle CUADRA con el libro doble. El test
  `forwardLineage_foreignCorpusUnproven_sameICloudProven` fijaba el bug: `proven` con la categoría del líder ausente y otra
  sin identidad.
- **Arreglo:** `checkForwardLineage` exige, con una fila compartida, la misma cobertura que el adopt
  (`adoptSharedRowsProof`: en cada tabla con algo que subir, todas las filas vivas del backend ya en local), sobre una
  enumeración que el Merkle da por completa. Nuevo `ForwardLineageOutcome.accountRowsMissing(table:missing:)`.
- **Salida:** techo de 15 min, como el linaje. Primero reusé el texto de `lineageUnproven`; la review lo tumbó («no
  coinciden, revisa la cuenta» es falso en el mismo iCloud), así que va con motivo propio (`leaderRowsNotArrived`) y texto
  propio en los 16 idiomas. Decidido por Frank sin despertar a Jürgen: es la opción robusta y no mueve datos.
- **Contrato que cambia:** una fila compartida ya no prueba con la enumeración incompleta (antes sí): sin Merkle completo la
  cobertura no se puede afirmar → `transient`.
- **Cierre:** `done` sin device-QA — el escenario (identidades del líder sin llegar a B tras >1 h) no se monta con fiabilidad
  en dos iPhone, igual que #240.
