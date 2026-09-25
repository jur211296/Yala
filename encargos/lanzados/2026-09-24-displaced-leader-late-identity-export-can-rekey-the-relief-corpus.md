# Medir y cerrar: export tardío de identidades del líder desplazado no puede pisar el relevo ni duplicar el libro

## Contexto
Cola A autónoma (noche Lima). Acaba de mergearse a `2.1` el PR #242 (`lineage-coverage-blocks-forever-after-a-row-deleted-during-the-wait`): un borrado en el otro teléfono durante la espera ya no deja el relevo ni el adopt sin salida. El residual hermano de la review de #241 sigue abierto y ya está en `tickets/in-progress/displaced-leader-late-identity-export-can-rekey-the-relief-corpus.md` (medium, área modo-nube/migración).

Hipótesis del ticket (parte inferida): tras un takeover, el líder desplazado puede exportar tarde a iCloud identidades `syncID` distintas a las que acuñó el relevo; si CloudKit gana ese campo, el relevo rekeyea filas ya subidas y el siguiente push/pull duplica. Clase del residual (c) del adopt en el docblock de `MigrationWorkExecutor.runAdoptOrphanReconcile`, pero en la ida y con el líder volviendo.

Quién recibe este encargo arranca en contexto limpio: no vio la conversación previa. Lee el ticket, ESTADO, el código citado y mide antes de inventar.

## Que se pide
1. Leer el ticket completo y el código relevante (`SyncIdentityService.backfillIdentities` / `assignIdentity`, espejo CloudKit del campo `syncID`, camino de relevo/takeover, docblock de `runAdoptOrphanReconcile`).
2. **Medir primero** si una exportación tardía del líder desplazado puede cambiar la identidad de filas ya subidas por el relevo (conflicto CloudKit del `syncID`, orden de import, rebind). Si la premisa no se sostiene, documentarlo en el ticket, mover a done o discarded con la evidencia, y actualizar `docs/TICKETS.md` — sin “arreglar” un fantasma.
3. Si se sostiene: arreglar para que no duplique el libro (opción robusta / good-practice; no la más simple). Sin salida “subir igualmente” que reabra el hueco de #241/#242.
4. Pruebas que fallen cerradas; gate; mutantes cuando toque; review adversarial antes de merge.
5. Gate/PR/merge a `2.1` y `/cerrar-total`. Board del repo: ticket en el estado correcto + `docs/TICKETS.md` al día. Bugs o decisiones nuevas → ticket propio (`--solo-crear`) antes de cerrar.

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board del repo, actualizar `docs/TICKETS.md`, merge y `/cerrar-total` sin preguntar si corres el gate o el commit. La regla del repo «espera aprobación si >3 ficheros» / «¿Sigo?» tras el plan queda **suspendida** en este encargo: implementa hasta cerrar. Solo parar ante decisión/acceso real que no puedas asumir. Bugs/decisiones nuevas → ticket propio antes de cerrar. Board: create/move directo en `tickets/` (sin inbox Tim).

## Regla de decisiones (noche Lima, 21:00–6:00)
Elige la opción robusta / good-practice sin AskUserQuestion. Si la decisión es demasiado importante para asumirla (datos de usuario irreversibles, prod), aplaza en ticket propio y sigue con lo que sí puedas cerrar. No despiertes a Jürgen de madrugada por preferencias reversibles.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL y key en fichero local, no en git; no las escribas en el repo) cuando:
  (1) necesitas una decisión de producto o de acceso de Jürgen;
  (2) abriste el PR o dejaste preview/artifact listo;
  (3) terminaste el ticket y vas a /cerrar-total — incluye en el aviso un resumen corto de cierre en lenguaje de usuario (qué se hizo), no solo «cerré»;
  (4) acabaste un tramo y no tienes siguiente paso claro (aunque no haya pregunta formal) — una vez, no en bucle.
NO avises por: un test rojo que vas a reclasificar, un build que vas a reintentar, ni ruido de CI advisory.

## Que NO hay que tocar
- `marketing/` y Web/ (lane Lola).
- No reabrir el duplicado de #241/#242 ni debilitar `adoptSharedRowsProof` / la regla de filas del líder.
- No device-QA en iPhone de Jürgen (este ticket se cierra sin QA de dispositivo salvo que el arreglo solo se pruebe ahí; si hace falta su dispositivo/secretos, ticket/aviso y aparca).
- No tocar el deduplicador de notificaciones (`notification-dedup-…`) ni UI/UX de Cola B.

## Como se sabe que esta bien
- Premisa medida (sí/no) con evidencia en ticket o PR.
- Si sí: no hay duplicado por export tardío del líder; pruebas fallan cerradas; gate verde; PR mergeado a `2.1`; `/cerrar-total`; `docs/TICKETS.md` y ticket en disco al día.
- Si no: ticket cerrado con la medición y sin código cosmética.

## Paso 0 (auto-contestado, noche Lima)

1. **¿Se sostiene la premisa?** Sí en el camino del código, sin medir en CloudKit. Medido: `syncID` va en el schema
   personal (espejado; `CD_syncID` en los `.ckdb`), los testigos `SyncIdentity` viven en el store de metadatos `.none`,
   y el relevo tiene el espejo vivo desde `assignIdentity` hasta el remonte posterior al cutover. En esa ventana una
   fila cuyo `syncID` cambia por debajo duplica por dos caminos: el paginado por `afterSyncID` del snapshot la vuelve
   a subir con la identidad nueva, y el pull del `verify` crea un born-remote con la vieja. Sin medir (pide dos
   teléfonos y iCloud): qué valor gana CloudKit. **Se diseña para el peor caso.**
2. **¿Qué identidad gana en el relevo?** La suya, la que ya subió: el backend la conoce y el líder desplazado no sube
   más. El líder, al entrar, se re-identifica por el linaje de #242.
3. **¿Cómo sabe el relevo cuál era?** Por el testigo y las coordenadas de CloudKit que `assignIdentity` le captura: el
   record es el mismo en los dos teléfonos. Solo se restaura una fila cuya identidad no tiene testigo y cuyo record
   casa con UN testigo huérfano (ninguna fila viva lleva su `syncID`). Casos ambiguos o sin coordenadas: no se tocan.
4. **¿Dónde?** Antes de cada página del snapshot, antes de cada drain del `verify` de la ida (también los del pull,
   tras su `await`) y del cutover, y una vez tras el remonte antes del reconcile de `done`. La vuelta a iCloud y el
   adopt quedan fuera (el adopt ya casa por linaje en #242): ticket propio si hace falta.
5. **Fallo al leer** → avería local de cada fase (`.blocked(.localFailure)`, drain abortado, efecto retomable). Nunca
   «no había nada que restaurar».
6. Sin copy nuevo ni salida «subir igualmente». #241/#242 intactos.
