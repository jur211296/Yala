# Si la fase guardada de la migración no se entiende, no se presente como «nunca empezó»

## Contexto
Cola A autónoma (mediums del callejón nube). Acaba de mergear a 2.1 el PR #248 (`adopt-on-an-empty-store-uploads-what-the-mirror-imports-before-the-relaunch`); ese ticket quedó en qa con guion de iPhone. Residual hermano con decisión sin prisa (`adopt-window-uploads-what-reaches-the-mirror-after-the-icloud-check`) se deja en backlog — no es este encargo.

Ticket: `tickets/backlog/an-undecodable-migration-phase-reads-as-never-started.md`
Padre ya cerrado: `an-unreadable-migration-journal-reads-as-never-started` (fetch que lanza → unreadable). Este cubre el downgrade: `phaseData` presente que no decodifica.

MODO AUTÓNOMO HASTA TERMINAR: gate, commit, docs/board del repo, actualizar `docs/TICKETS.md`, merge y /cerrar-total sin preguntar si corre el gate o el commit. Bugs/decisiones nuevas → ticket propio antes de cerrar. Solo parar ante acceso real de Jürgen (device/secrets) o decisión demasiado grave para asumir. Board Yala: create/move directo en `tickets/` + índice.

OVERRIDE (Jürgen 2026-09-22): la regla del repo «espera aprobación si >3 ficheros» / «¿Sigo?» tras el plan queda suspendida en esta cola — implementa hasta gate/PR/merge/cerrar-total sin pedir permiso para continuar.

Decisión de producto YA tomada por Frank (robusta, sin preguntar):
1. `decodeFailed` → `.unreadable` en los dos lectores (`MigrationPhaseStore.phaseRead` y `MigrationJournalRead.read`), usando el tipo `JournaledPhaseRead` que ya existe.
2. Revisar el runner que también usa `readPhase()`: mismo desenlace fail-closed (no tratarlo como `notStarted` estable).
3. Efectos pendientes que no decodifican (`readPendingEffects` → `[]`): misma pregunta un nivel más abajo — si el vacío silencioso puede abrir el mismo callejón, fail-closed coherente (ticket residual si el alcance se dispara; no inventar producto).

Horario diurno Lima: AskUserQuestion SOLO si hace falta acceso/device/secrets de Jürgen. No preguntes techos/copy/producto ya cubiertos arriba.

## Que se pide
- Un `phaseData` presente que no decodifica no se presenta como `notStarted` en ninguno de los dos lectores.
- Test con un blob que no decodifica + control positivo.
- Mover el ticket a in-progress al empezar; al cerrar: qa solo si hace falta device-QA real; si no, done. Actualizar `docs/TICKETS.md`.
- PR a 2.1, merge, `/cerrar-total`.

## Que NO hay que tocar
- marketing/, Web/
- Los residuales de #248 (espejo post-check / late-imports) salvo crear ticket si aparece otro hallazgo distinto
- Canarios / tickets en espera de canary
- No relajar fail-closed a «sigue como notStarted»

## Como se sabe que esta bien
- Criterios del ticket tachados con evidencia (test + comportamiento de lectores/runner)
- PR mergeado a 2.1; board e índice al día; `/cerrar-total` limpio
- Aviso de cierre con resumen en lenguaje de usuario (Necesita de ti → Cambiado → Encontrado)

Avisos al bot dueño (Frank): POSTea al webhook local de la Mini (URL y key en fichero local, no en git; no las escribas en el repo) cuando:
  (1) necesitas una decisión de producto o de acceso de Jürgen;
  (2) abriste el PR o dejaste preview/artifact listo;
  (3) terminaste el ticket y vas a /cerrar-total — incluye en el aviso un resumen corto de cierre en lenguaje de usuario (qué se hizo), no solo «cerré»;
  (4) acabaste un tramo y no tienes siguiente paso claro (aunque no haya pregunta formal) — una vez, no en bucle.
NO avises por: un test rojo que vas a reclasificar, un build que vas a reintentar, ni ruido de CI advisory. URL/key solo en la Mini.

## Paso 0 — decisiones (resueltas en autónomo, bypass)

Medido antes de decidir: el único camino real a un blob que no decodifica es un **downgrade** (un build con un case nuevo
escribe; uno anterior lee). Y el runner no solo leía `notStarted`: en cada entrada **reseteaba la fila** a `notStarted`
sin pendientes (la «normalización» M1), así que cambiar solo los lectores habría sido cosmético — el primer `resume()` del
arranque dejaba la fila en `notStarted` de verdad.

1. **Qué cuenta como «no se entiende».** Fase, pendientes o pendientes del origen de la vuelta: los tres rellenan con un
   valor que concede (`notStarted`, `[]`) y los tres los escribe la máquina. Un solo testigo: `MigrationState.isJournalUndecodable`.
2. **Lectores.** `MigrationPhaseStore.phaseRead` y `MigrationJournalRead.read` devuelven `.unreadable` (el tipo que ya
   existe). Los consumidores ya saben qué hacer con él desde el ticket padre — no se toca ninguno.
3. **Runner: parar, no resetear.** Se retira la normalización: la fila queda intacta y ninguna entrada conduce. El chequeo
   va en `runGuarded`, así lo heredan las seis entradas públicas y las futuras. Salida de este estado: actualizar Yala (el
   build que lo escribió lo retoma donde estaba). Resetear borraba una migración en vuelo con sus pendientes.
4. **Rastro.** `migrationPhaseDecodeFailed` («fallback notStarted») era falso tras el cambio → `migrationJournalUndecodable(reader:)`.
5. **Copy (asumido, residual).** La tarjeta `.journalUnreadable` dice «cierra y vuelve a abrir»; en un downgrade la cura es
   actualizar. No se inventa copy en 17 idiomas aquí: ticket propio low con la propuesta.
6. **Tests que fijaban el reset como contrato** (tres en `MigrationRunnerTests`) se reescriben para exigir la fila intacta.
7. **Device-QA:** no hace falta (se monta en unit con un blob real); el ticket va a `done`.
8. **Tras la review (tres lentes, sin altos):** el testigo entra también `forwardClaimIntentRaw` y `reverseOriginRaw`
   con un valor desconocido (su relleno concede; su `nil` sigue legítimo), y la matriz del runner siembra un pendiente
   conocido para que la columna de la fase muerda. A ticket: push del cierre de sesión sin candado de fase, `storageMode`
   desconocido leído `.icloud`, y el adopt de la bienvenida sin el guard del journal ilegible.
