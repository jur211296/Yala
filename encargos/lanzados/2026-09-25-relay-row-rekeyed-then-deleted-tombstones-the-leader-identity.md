# Un movimiento re-identificado y borrado en la ventana del relevo ya no reaparece ni tumba la activación

## Contexto
Viene del cierre de `displaced-leader-late-identity-export-can-rekey-the-relief-corpus` (PR #243, mergeado a 2.1). Ese ticket hizo que el relevo recupere su propia identidad cuando el líder desplazado exporta tarde a iCloud. Residual adversarial (lentes del duplicado y de los consumidores): si en esa misma ventana se borra una fila que el espejo re-identificó, el tombstone sale con la identidad del líder (la que el backend no conoce) y la del relevo sigue viva en el backend. Resultado de usuario: el movimiento borrado reaparece en los otros teléfonos, y a veces la activación falla por MISMATCH hasta `failedRollback` y hay que repetirla.

Ticket: `tickets/backlog/relay-row-rekeyed-then-deleted-tombstones-the-leader-identity.md`. Quién arranca va en contexto limpio.

Hermanos del mismo cierre (NO tocar aquí; quedan en backlog):
- `adopt-window-late-leader-identity-export-can-duplicate-after-the-remount` (medium)
- `reverse-mount-can-reimport-a-late-leader-identity` (low)
Relacionado previo (low, no absorber sin medir): `row-deleted-during-the-relief-wait-comes-back-after-the-relief`.

## Decisión de producto (Frank, noche — ya tomada; no repreguntar)
SÍ merece la pena arreglarlo. Opción robusta: un borrado del usuario no debe reaparecer ni tumbar la activación de la nube. No aparcar. No pedir techos/copy/Cancel a Jürgen.

## Que se pide
1. Paso 0: leer el ticket y el código vivo alrededor de `MigrationWorkExecutor.restoreRelayIdentities`, el drain de tombstones (`tombstone[\.syncID]`, `.preserveValueOnDeletion`), y cómo el espejo conserva metadatos del objeto borrado hasta exportar el borrado. Fijar el contrato medible (canario) antes de tocar producción.
2. Implementar la traducción del tombstone a la identidad que el backend conoce (la del relevo / testigo huérfano), o el mecanismo equivalente robusto que cierre el hueco entre pasadas del runner y del cutover al relanzamiento — sin abrir nuevas ventanas de duplicado ni de datos perdidos.
3. Canario/prueba que falle en rojo con el bug y pase en verde con el fix. No “casar prueba” que no pueda fallar.
4. Board del repo: ticket a in-progress al empezar; al cerrar → done si no hace falta QA en iPhone (el webhook dijo que el valor de iCloud de #243 no se mide sin dos teléfonos; aquí el daño es borrado que revive + posible failedRollback — si el fix queda cubierto por canario/unitario sin script de dos dispositivos, done; si hace falta device-QA real, qa). Actualizar `docs/TICKETS.md`. Bugs/decisiones nuevas de camino → ticket propio (`--solo-crear`) antes de `/cerrar-total`.
5. Gate, commit, PR, merge a 2.1 y `/cerrar-total` sin preguntar.

## MODO AUTÓNOMO HASTA TERMINAR
Bypass activo. Gate, commit, docs/board del repo, `docs/TICKETS.md` al día, merge y `/cerrar-total` sin preguntar si corre el gate o el commit. La regla del repo «espera aprobación si >3 ficheros» / «¿Sigo?» tras el plan queda SUSPENDIDA en este encargo: implementa de punta a punta. Solo parar ante decisión/acceso real que no puedas resolver con la decisión de arriba (device/secrets de Jürgen). De noche (21:00–6:00 Lima): elige lo recomendado/robusto sin AskUserQuestion; si fuera demasiado grave para asumir, aparca en ticket propio — no inventes.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL y key en fichero local, no en git; no las escribas en el repo) cuando:
  (1) necesitas una decisión de producto o de acceso de Jürgen;
  (2) abriste el PR o dejaste preview/artifact listo;
  (3) terminaste el ticket y vas a /cerrar-total — incluye en el aviso un resumen corto de cierre en lenguaje de usuario (qué se hizo), no solo «cerré»;
  (4) acabaste un tramo y no tienes siguiente paso claro (aunque no haya pregunta formal) — una vez, no en bucle.
NO avises por: un test rojo que vas a reclasificar, un build que vas a reintentar, ni ruido de CI advisory. URL/key solo en la Mini.

## Que NO hay que tocar
- marketing/, Web/, destinos de Lola.
- Los hermanos residuales listados arriba (salvo crear ticket si aparece algo nuevo).
- No pedir a Jürgen techos, copy, Cancel ni formas AskUserQuestion de producto: ya está decidido.
- No Cursor; Claude Code en este worktree.

## Como se sabe que esta bien
- Borrar una fila re-identificada en la ventana del relevo (entre pasadas / cutover→relanzamiento) no la resucita en otros dispositivos ni deja la verificación en bucle MISMATCH→failedRollback por identidad de líder desconocida.
- Canario o prueba de contrato en rojo→verde que fija ese comportamiento.
- PR mergeado a 2.1, ticket e índice al día, `/cerrar-total` limpio.

## Paso 0 (2026-09-25, 01:20 Lima — de noche, auto-contestado)

**Medido en el código antes de decidir:**
- El drain emite el tombstone con `tombstone[\.syncID]` (`CloudSyncEngine.translateChange`, rama `.delete`): el valor
  que la fila tenía AL BORRARSE. Si el espejo la re-identificó y nadie la restauró antes, sale la del líder.
- Los testigos `SyncIdentity` se quedan al borrar la fila (huérfanos para el rebind): con muchos huérfanos, «el único
  huérfano de su tipo» no identifica nada. Hace falta un vínculo fila→identidad que sobreviva al borrado.
- La idea del ticket (leer el record del objeto borrado en los metadatos del espejo) depende de que el drain llegue antes
  de que el espejo exporte el borrado: con red son segundos, y del cutover al relanzamiento pueden ser horas. Descartada
  como mecanismo principal: es justo la carrera sin medir.
- El `Z_PK` de una fila no cambia cuando el espejo le cambia la identidad (es un update del mismo objeto) y Core Data no
  reutiliza `Z_PK`. El `PersistentIdentifier` del tombstone es el mismo que tenía la fila viva.
- El executor de la migración tiene su PROPIO `CloudSyncEngine` (`CloudMigrationController.makeExecutor`); el del
  runtime es otro. Las salidas `finishedHere/finishedElsewhere` del reconcile dejan el drain al runtime.

**Decisiones:**
1. **Un registro local «fila → identidad que este teléfono le dio»** (`RelayIdentityLedger`, JSON en Application
   Support), sembrado en `assignIdentity` con los pares fila↔testigo de los seis tipos de identidad acuñada. Se fusiona,
   nunca se recorta: una entrada de una fila borrada es justo la que hace falta.
2. **El drain traduce el tombstone** (cualquier motor, lee el fichero): si la identidad del tombstone NO tiene testigo
   aquí, el registro apunta esa fila a otra identidad CON testigo, con coordenadas de CloudKit y que ninguna fila viva
   lleva → el tombstone sale con esa. Es la identidad que `restoreRelayIdentities` le habría devuelto (mismas tres
   condiciones de #243, con el `Z_PK` en lugar del record). Cualquier otra cosa → sin traducir, como hoy.
3. **Lectura del testigo que falla → el drain no consume esa transacción** (se reintenta en el siguiente); **fichero
   ilegible o que no se puede escribir → rastro y se sigue sin traducir**: bloquear la migración entera por la red
   suplementaria sería peor que el daño que cubre.
4. **Limpieza**: el primer drain completo con la fase en `done` (espejo ya apagado, nada más que traducir) borra el
   fichero. Si la migración cae a iCloud, el fichero queda inerte (toda traducción exige las tres condiciones).
5. **Canario** `cloudRelayTombstoneTranslated` + rastro, molde de `cloudRelayIdentityRestored`.
6. **Board**: si el canario unitario cubre verify + cutover + reconcile, `done` sin device-QA (el valor que gana
   CloudKit sigue sin medirse sin dos teléfonos, igual que en #243).

**Asumido (anotado, no preguntado):** en el líder desplazado la traducción, igual que la restauración de #243, apunta a
la identidad que ESE teléfono acuñó; lo que pase ahí al entrar en la cuenta es de los hermanos
`adopt-window-late-leader-identity-export-can-duplicate-after-the-remount` y `reverse-mount-can-reimport-a-late-leader-identity`.
