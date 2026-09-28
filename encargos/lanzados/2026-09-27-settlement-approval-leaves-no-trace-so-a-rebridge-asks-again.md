# Una liquidación ya aprobada no vuelve a pedir cuenta ni duplica el abono al banco

## Contexto
Acaba de mergearse a 2.1 el PR #287 (`late-remote-wipe-on-a-device-without-groups-cannot-return-the-rows`): si un iPad sin Grupos procesa tarde el «Vaciar datos» del iPhone, el iPad declara lo que se lleva y el iPhone lo repone al arrancar, una vez.

En la review adversarial de ese cierre salió este ticket (medium, área groups/sync, leído en código, no reproducido): `tickets/backlog/settlement-approval-leaves-no-trace-so-a-rebridge-asks-again.md`.

Síntoma de usuario: vacía datos en el iPhone, vuelven gastos/liquidaciones de grupo, aprueba en el Inbox «Ana me pagó 25» a su cuenta del banco. Días después el iPad procesa el vaciado tarde. Al reabrir el iPhone, el Inbox vuelve a pedir a qué cuenta llegó ese pago; si lo aprueba otra vez, el banco suma 25 dos veces. Además el borrador de liquidación no se puede rechazar ni borrar.

Causa medida: aprobar el borrador crea la transacción real SIN enlace durable a la liquidación (`DraftService`, D7) y borra el borrador. La convergencia / `GroupsRemoteWipeReturn` re-puentea liquidaciones que quedaron sin patas y no ve la real ya aprobada, así que crea otro borrador.

Cola A real-risk (duplicación silenciosa de dinero). Carril Swift Cola A: una sesión a la vez. El carril adaptativo iPad/Duo es otro carril; no lo toques.

NOCTURNO (21:00–6:00 Lima): elige la opción recomendada sin AskUserQuestion. Si la decisión fuera demasiado grave para asumirla, aplaza con ticket propio — no inventes producto.

## Que se pide
Cierra el ticket `settlement-approval-leaves-no-trace-so-a-rebridge-asks-again` de punta a punta.

Decisión de producto ya tomada por Frank (opción robusta, buena práctica):
1. La aprobación de un borrador `groupSettlement` deja una marca durable que viaje por el espejo (no uses `splitSettlementID` en la transacción real si eso la convertiría en «pata» para el bridge; elige el campo/mecanismo nativo correcto).
2. El re-puente / convergencia / `GroupsRemoteWipeReturn` NO crea un borrador nuevo cuando esa marca indica que la liquidación ya se aprobó alguna vez.
3. El usuario puede rechazar o borrar un borrador `groupSettlement` del Inbox (hoy no puede), para no quedar atrapado si aparece uno.

Cubre los dos caminos del ticket (receptor tardío que se lleva la virtual; aprobación en la ventana entre borrado del receptor y llegada al origen). Relacionados a no absorber salvo que midas que son el mismo bug: `wipe-data-group-rows-return-only-on-the-next-cold-launch`, `late-remote-wipe-on-a-device-without-groups-cannot-return-the-rows`, `late-remote-wipe-signal-undoes-the-rows-the-origin-reconverged`.

## Que NO hay que tocar
- marketing/
- clinicas-dentales-bi / datos de salud
- el carril adaptativo iPad/Duo ni sus simuladores `YalaLane-Adapt-*`
- simuladores de otras colas
- prod Supabase; staging solo si el ticket lo exige de verdad
- no reabrir el diseño general de D7 más allá de lo necesario para la marca durable + no re-pedir + poder descartar el borrador

## Como se sabe que esta bien
- Tests (unit / integration al nivel del repo) que fijen: tras aprobar una liquidación, un re-puente / declaración de wipe tardío no vuelve a crear borrador ni segunda transacción al banco.
- Gate verde del encargo; PR a 2.1; ticket movido (qa o done según norma del repo) y `docs/TICKETS.md` al día.
- Si salen bugs o decisiones nuevas de camino: ticket propio en `tickets/` antes de `/cerrar-total`.
- Device-QA solo si hace falta; si queda, guion claro en el ticket — no frena el merge de código.

MODO AUTÓNOMO HASTA TERMINAR: gate, commit, docs/board del repo, actualizar `docs/TICKETS.md`, merge y `/cerrar-total` sin preguntar si corre el gate o el commit. Bugs/decisiones nuevas → ticket propio antes de cerrar. Solo parar ante decisión/acceso real de Jürgen o secreto que no tengas. No sync al Kanban del panel centro de mando.

Avisos al bot dueño (Frank): POSTea al webhook local de la Mini (URL y key en fichero local, no en git; no las escribas en el repo) cuando:
  (1) necesitas una decisión de producto o de acceso de Jürgen;
  (2) abriste el PR o dejaste preview/artifact listo;
  (3) terminaste el ticket y vas a /cerrar-total — incluye en el aviso un resumen corto de cierre en lenguaje de usuario (qué se hizo), no solo «cerré»;
  (4) acabaste un tramo y no tienes siguiente paso claro (aunque no haya pregunta formal) — una vez, no en bucle.
NO avises por: un test rojo que vas a reclasificar, un build que vas a reintentar, ni ruido de CI advisory. URL/key solo en la Mini.

## Paso 0

Sesión nocturna (23:10 Lima), MODO AUTÓNOMO: las decisiones se auto-contestan con la opción recomendada.

**1. ¿Qué marca durable? → un borrador APROBADO nuevo, creado en el mismo guardado que la transacción real.**
Medido: un campo nuevo en `TransactionItem` sería lo más limpio, pero exige desplegar el schema del contenedor
personal de CloudKit a Production (sin eso, producción rechaza los registros con el campo) y una columna en el
backend para el modo nube (prod Supabase, fuera del encargo). Las dos son acceso de Jürgen. El mecanismo nativo que
ya existe y viaja por el espejo es el del Inbox: el camino personal deja el borrador en `approved` con
`approvedTransaction` enlazado. Se usa ese, con un matiz medido: **no se reutiliza el registro del borrador
pendiente**. Ese registro nació junto a la pata virtual, así que un receptor tardío que importó la virtual casi
seguro importó también el borrador, y su borrado llegaría al origen y se llevaría la marca. Un registro nuevo nace
con la transacción real y comparte su suerte: si el receptor se llevó la real, se lleva también la marca y volver
a preguntar es lo correcto.

**2. ¿Qué hace el re-puente con la marca? → rehace la pata virtual y no crea borrador (ni la pata real enlazada
del Caso C).** `bridgeSettlement` es el embudo único (convergencia, `GroupsRemoteWipeReturn`, retome durable, sync
y edición local pasan por él). Deja de borrar los borradores ya resueltos (aprobados o rechazados); borra solo los
pendientes. La guarda «solo sin ninguna pata» de la convergencia y de la devolución no se toca: sigue protegiendo
la pata real enlazada.

**3. ¿Y si un borrador pendiente convive con la marca (creado en otro dispositivo antes de que llegara)? →
aprobarlo es idempotente**: si ya hay una marca de esa liquidación con su transacción, se descarta el pendiente y
se devuelve esa transacción; no se crea otra. Si la marca existe pero su transacción se borró, se aprueba normal
(es el «re-aprobar» nativo del Inbox).

**4. Rechazar/borrar → se permiten para `groupSettlement`, no para `groupExpense`.** Rechazar deja el borrador
`rejected`, y el re-puente lo respeta (no vuelve a preguntar en este dispositivo). Borrar lo quita sin rastro: un
re-puente posterior puede volver a preguntar, sin riesgo de dinero doble. `isFromGroup` no se toca (lo usa el
ruteo del aprobar en lote): propiedad nueva en `DraftSourceType`.

**Asumido / fuera:**
- Las liquidaciones aprobadas ANTES de este cambio no tienen marca y no se pueden reconstruir con certeza: el
  agujero sigue para ellas (ahora con salida: rechazar el borrador).
- Si el receptor importa la marca y no la transacción (o al revés), el resultado es el de hoy en esa fila; los dos
  nacen en el mismo guardado y viajan juntos por el espejo.
- Un dispositivo con una versión anterior de la app sigue borrando los borradores al aprobar.
- Review adversarial: sí (sync + dinero).

**Ficheros:** `InboxDraft.swift` (propiedad), `DraftService.swift` (marca, idempotencia, rechazar/borrar),
`GroupTransactionBridge.swift` (re-puente), cabeceras de `GroupsBridgeRestoreConvergence.swift` y
`GroupsRemoteWipeReturn.swift`, `.claude/rules/swiftdata-cloudkit.md`, tests, `qa/coverage-index.json`, ticket y
`docs/TICKETS.md`.

### Enmiendas tras la review adversarial (2026-09-28)

Tres lentes (dinero, sync, tests). Lo que cambió del Paso 0:

- **3 → la marca cuenta por su estado, y aprobar con marca da error.** Exigir la transacción enlazada dejaba una ventana
  (CloudKit trae la marca antes que la transacción) con dinero doble. El pendiente no se borra al fallar (la hoja sigue
  montada): lo poda el arranque (`pruneSettlementDraftsAlreadyResolved`), que además limpia los pendientes que crea un
  receptor tardío CON grupos que converge sin tener la marca.
- **4 → el rechazo se preserva a propósito**: todo upsert remoto de la liquidación re-puentea, así que sin eso no duraba. Y
  el rechazado sin cuenta sale en Archivados; si no, era invisible e irreversible.
- **Nuevo → la marca viva no se borra ni vuelve a pendientes desde el Inbox**: «Eliminar» en Archivados se llevaba la
  protección, y «Devolver a pendientes» la convertía en un pendiente que se aprobaba otra vez.
- **Nuevo ticket** `settlement-amount-edited-after-approval-leaves-the-bank-stale` (low): la corrección remota del importe
  de una liquidación ya aprobada no llega al banco.
