# «Empezar de cero» sin salida cuando los cambios de grupos no pueden subir nunca: ofrecer «perderlos» con guardas

## Contexto
Desde `fresh-start-wipe-kills-unsent-group-writes-silently` (PR #256), «Empezar de cero» sube el outbox de grupos
antes de borrar y, si no sube, no borra. Con `.sessionExpired`, `.permanent` o `.channelPaused` sostenido no drena
nunca, y el usuario queda atrapado (p. ej. iPhone heredado de otra persona): la única salida es desinstalar.
Ticket: `tickets/backlog/fresh-start-has-no-way-out-when-group-writes-can-never-upload.md` (léelo entero).
Molde a seguir: la salida «perderlos» del cierre de sesión con `.attestUnavailable`.

## Que se pide
Decisión ya tomada (opción 1 del ticket, con guardas; norma de Jürgen: la opción robusta):
- Ofrecer «Empezar de cero y perderlos» SOLO con motivos que esperar no arregla: `.sessionExpired`, `.permanent`
  y `.attestUnavailable`. Con `.channelPaused` y cualquier motivo transitorio, NO: se mantiene el bloqueo con su
  texto actual (sin pedir «vuelve a iniciar sesión» en una cuenta que puede no ser del usuario cuando el motivo es
  `.sessionExpired`; revisa ese copy).
- Mostrar la cifra de cambios de grupo que se perderán y exigir segunda confirmación (segundo alert con labels
  literales), y su entrada en la matriz de readiness (`.claude/rules/swiftui-ds.md`).
- Nada se borra sin esa segunda confirmación; cancelar deja todo intacto. El motivo se evalúa en el momento del
  gesto (no un valor cacheado viejo).
- Tests que cubran cada motivo (ofrece / no ofrece), la cifra, cancelar en cada alert y que el wipe solo ocurre tras
  confirmar.
- Copy en español sencillo, coherente con el del cierre de sesión. Lo decides tú.

## Que NO hay que tocar
- El comportamiento del desasociar (decisión de Jürgen 2026-09-15) y el del cierre de sesión, salvo reutilizar su
  molde.
- `mcp/` y staging: hay otra sesión en paralelo trabajando ahí. Si chocan `tickets/` o `docs/TICKETS.md` al
  integrar, rebasa sobre origin/2.1 y recuenta.
- Producción de Supabase.

## Como se sabe que esta bien
- Build y suite verdes, tests nuevos verdes.
- Review adversarial del diff antes del merge.
- PR a 2.1 mergeado con guion de device-QA en el ticket, ticket movido y `docs/TICKETS.md` al día, `/cerrar-total`.

## MODO AUTÓNOMO
Queda suspendida para este encargo la regla del repo de esperar aprobación si hay más de 3 ficheros y el «¿Sigo?»
tras el plan: implementa de punta a punta (gate, PR, merge, `/cerrar-total`) sin pedir permiso para seguir. Es
horario diurno (Lima): puedes preguntar a Jürgen con AskUserQuestion solo lo que sea de producto o acceso de verdad;
las decisiones técnicas y de copy las tomas tú eligiendo la opción robusta. Si aparecen bugs o decisiones nuevas,
ticket propio antes de cerrar.

## Paso 0 (decidido por Frank, 2026-09-26, sin nadie delante)

**Qué ofrece la salida.** `CloudSignOutFlowLogic.freshStartOffersGroupsLossExit(_:)`, `switch` exhaustivo: sí con
`.sessionExpired`, `.permanent` y `.attestUnavailable`; no con el resto (`.channelPaused`, `.uploadRetryLater`,
`.transient`…). Con esos, el texto de hoy no cambia.

**Cuándo se evalúa el motivo.** En el gesto: la confirmación final no borra a partir del bloqueo que se enseñó, sino
que vuelve a subir. Si drena, borra sin perder nada. Si vuelve a bloquear con un motivo que ofrece la salida **y** lo
que queda está entre lo que se enseñó, borra perdiéndolo. Con otro motivo, o con un cambio que no salió en el aviso,
vuelve el aviso con la cifra nueva. Es el molde del cierre de sesión (`continuesAfterBlockedUpload`).

**Lo aceptado va por fila, no por cifra.** Filas vivas del outbox por `clientMutationID` y entradas del espejo del App
Group por su clave `(syncID, hlc, op)`: el borrado se lleva las dos, así que la cifra del aviso cuenta las dos. El
cinturón del escritor (`requireNoUnsentGroupWrites`) acepta exactamente eso y nada más.

**Segunda confirmación: una fase, no un alert.** Las dos pantallas con fases (puerta privada del Welcome y aviso del
espejo tardío) ganan dos fases: la oferta y el «¿seguro?». La regla de `swiftui-ds.md` prohíbe encadenar dos `.alert`
del mismo anchor y prefiere fases. Al no haber presentación nueva, no hay entrada nueva en la matriz de readiness.

**El alert del shell no puede ofrecerla, y por eso deja de negarse en el sitio.** Con cambios pendientes no sube (no hay
nada montado donde enseñar una subida), así que nunca conoce el motivo y siempre diría «inténtalo en un rato»: es la
trampa del ticket, en el camino del iPhone heredado. Asumido: con algo pendiente, «Borrar todo y continuar» reabre el
Welcome en la puerta privada, directo en el borrado del teléfono (`performDeviceCorpusWipe`, que ya sube, espera al
import y tiene las fases). Sin nada pendiente, borra en el mismo tap, como siempre.

**Copy.** El `.sessionExpired` de «Empezar de cero» deja de decir «vuelve a iniciar sesión»: dice que solo suben con la
cuenta que los apuntó y ofrece perderlos. Texto nuevo en 16 locales; botones «Empezar de cero y perderlos» y
«Perderlos y empezar de cero», «Mejor no» y «Dejarlo por ahora» reutilizados.

**Asumido, sin tocar:** un kill a mitad de un borrado con pérdida aceptada deja el arm; la reanudación del arranque
no lleva aceptación, así que se para en la subida y se desarma (lo de siempre). La aceptación vive en memoria.

**Ajustado tras la review adversarial (tres lentes):** antes de ofrecer la salida se vuelve a capturar el History (con
`.sessionExpired`/`.permanent` el ciclo no lo hacía); lo aceptado lo toma el borrado en su primer paso, no la subida; la
entrada `.wipeDevice` exige un permiso de un uso que da el tap del alert; la X del aviso tardío hace lo de «Dejarlo por
ahora». Nuevo ticket `fresh-start-drops-mirror-entries-of-another-identity-without-counting-them` (decisión B2, preexistente).
