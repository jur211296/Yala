# Un drain de grupos que falla se lee como «no hay nada pendiente» — el pre-check de wipe/sign-out falla abierto

MODO AUTÓNOMO (override Jürgen 2026-09-22, vigente): la regla del repo «espera aprobación si >3 archivos» / «¿Sigo?» tras el plan queda SUSPENDIDA. Implementa de punta a punta — plan → código → gate → PR → merge a 2.1 → /cerrar-total — sin preguntar si continúas. AskUserQuestion de producto/acceso solo 06:00–21:00 Lima y solo si es decisión real de producto o acceso; estamos en NOCTURNO (~05:25 Lima, antes de 06:00): NO uses AskUserQuestion; elige la opción robusta / buena práctica y sigue. Si algo es demasiado consecuente para asumir, aparca el ticket y cierra limpio — no inventes producto. Siempre la opción más robusta / buena práctica, nunca la más simple.

## Contexto
Ticket medium Cola A (riesgo real: pérdida silenciosa). Residual adversarial de `fresh-start-wipe-kills-unsent-group-writes-silently` (#256, mergeado 2026-09-26). Ese PR hace que «Empezar de cero» (y el cinturón de wipe de grupos) drene el outbox y cuente filas vivas antes de borrar. Pero `GroupsSyncClient.drainOnce` / `performDrain` se traga errores (`fetchHistory`, `buildLookups`, `save`) y el corte del reloj HLC sale con `break`: lo no traducido vive solo en SwiftData History, el recuento da 0 y el borrado / cierre sigue. Después ningún drain encuentra fila viva — el gasto se pierde en silencio. El hueco ya existía en `CloudSessionSignOut.pushAllPendingGroupsForSignOut`; desde #256 también lo usa `groupsOutboxIsSettledEmpty`.

Gemelo por el espejo App Group (regla Q3): un kill o `save` fallido deja la fila solo en el espejo; la rehidratación solo corre en `startIfEligible` con flag compuesto + sesión. Sin eso el recuento da 0 y `resetSyncState` purga el espejo.

Cola A armada solo para mediums cloud/sync con riesgo real. Device-QA del ticket padre queda pendiente en paralelo; NO bloquea este lanzamiento ni el merge.

## Qué se pide
Cerrar el fail-open del drain de grupos antes de los pre-checks de wipe / «Empezar de cero» / sign-out.

Molde robusto (asumido de noche, sin AskUserQuestion): igual que el canal personal — `CloudSyncEngine.drainOnce` ya devuelve si terminó (desde `drain-duplicates-the-unit-clock-when-its-row-cannot-be-read`). Haz que `GroupsSyncClient.drainOnce` (o el equivalente que usan los pre-checks) reporte éxito/fallo, y que `groupsOutboxIsSettledEmpty` / `pushAllPendingGroupsForSignOut` (y cualquier caller del cinturón de #256) bloqueen con «no vacío / no settled» si el drain falló. No borres ni cierres como si no hubiera nada pendiente.

Para el espejo: el cinturón del borrado debe contar también entradas del espejo App Group que aún no rehidrataron, para no purgarlas con recuento 0.

Tests: unit/canario del drain que falla → pre-check false; mutantes acotados a YalaTests. Device-QA puede quedar apuntado sin bloquear merge si el canario cierra el hueco.

## Qué NO
- No abras / no implementes `fresh-start-has-no-way-out-when-group-writes-can-never-upload` (decisión de producto de Jürgen: ofrecer «perderlos» o no).
- No abras `sign-out-exits-do-not-verify-the-cloud-session-closed` (necesita decisión; sin prisa).
- No rediseñes el flujo entero de session-exits / paso 9.
- No pidas «¿Sigo?» ni esperes aprobación por >3 archivos.
- No AskUserQuestion de noche.
- No toques credenciales, secrets, ni producción.
- No escribas el effort en prosa del encargo/PR (ADR-043); ya va en el flag de lanzamiento.

## Cómo se sabe
- Si `drainOnce` de grupos falla (History / lookups / save / corte HLC a medias), los pre-checks de wipe / «Empezar de cero» / push-all de sign-out NO tratan el outbox como vacío: el gesto se para o reintenta; no borra en silencio.
- Entradas solo en el espejo App Group cuentan como pendientes en el cinturón de borrado.
- Unit/canario verde en YalaTests; gate/PR/merge a 2.1; /cerrar-total forma 4 limpia.
- Residual tmux se puede matar tras cierre (Frank lo hará).

## Paso 0 (auto-contestado, nocturno)
- **Dónde se entrega:** worktree → rama `encargo/…` + PR a `2.1`, merge propio con CI verde.
- **Alcance:** `GroupsSyncClient.drainOnce` / `performDrain` + callers de pre-check (`groupsOutboxIsSettledEmpty`, `CloudSessionSignOut.pushAllPendingGroupsForSignOut`, cinturón de #256). Espejo App Group en el cinturón de conteo/purge.
- **Semántica:** drain fallido ⇒ «no settled empty» (fail closed). No inventar copy nuevo de producto salvo el que ya exista para bloqueo por pendientes / motivo de sign-out; reutilizar.
- **Espejo:** contar entradas del espejo pendientes de rehidratar antes de `resetSyncState` / wipe; no purgarlas con recuento 0.

## Paso 0 — decisiones de la sesión (Frank, asumidas de noche)

- **Qué es «captura completa».** `GroupsSyncClient.drainOnce` devuelve `Bool` (molde personal). `false` también con el
  corte del reloj HLC (a diferencia del personal, donde `true` lo tolera): aquí el llamador decide si borrar.
- **La captura previa a una salida** = rehidratar el espejo → drenar → barrer el veneno
  (`GroupsSyncClient.captureLocalWritesForExit`). Rehidratar aquí cierra el gemelo del espejo cuando HAY sesión, que es
  el caso real (flag compuesto apagado ⇒ `startIfEligible` no corrió).
- **Veredicto puro** `CloudSignOutFlowLogic.groupsCaptureVerdict`: con filas vivas, a subir (nil); sin filas, `.drained`
  solo si la captura terminó y el espejo no guarda nada fuera del outbox; si no, `.blocked(uploadRetryLater)` con la
  cifra del espejo o `Int.max` («no se pudo contar»). Motivo reutilizado: su copy («no llegaron, siguen aquí, inténtalo en
  un rato») es verdad para un drain fallido. Sin copy nuevo.
- **El push-all re-captura tras vaciar el outbox**: el drain del ciclo no viaja en el outcome, así que `live == 0` tras
  un ciclo no prueba nada. Testigo directo, no estado compartido.
- **Alcance del espejo.** Push-all (cierre, desasociar, «Empezar de cero»): solo las entradas del `sub` de la sesión
  (M1; sin sesión no puede subirlas y no bloquea el cierre). Cinturón y pre-check de «Empezar de cero»: las de la
  sesión, o TODAS si no hay sesión — es el borrado el que purga el espejo entero.
- **Seams explícitos** (`GroupsExitWitness`), no estado compartido: el espejo real del simulador guarda 48 entradas de
  `auth-uid-1` que otras suites dejan (medido).
- **Fuera:** la salida «perderlos» (decisión de Jürgen pendiente) y el hueco gemelo del canal PERSONAL en el push-all del
  cierre, que va a ticket propio.
