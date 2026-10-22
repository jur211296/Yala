# El borrado del dominio Grupos promete atomicidad cross-store y no la tiene

## Contexto
Alternancia Cola A ↔ carril adaptativo (una sola sesión Yala a la vez). El turno adaptativo (#320 cabeceras con poco alto) acaba de cerrar sesión; #319 (`groups-detach-ledger-has-no-exit`) y #320 siguen en cola de auto-merge — no los reabras. Cola A otra vez.

Ticket: `tickets/backlog/groups-purge-save-crosses-two-stores-without-atomicity.md` (medium, modo-nube/groups). Riesgo real de usuario: en desasociar / «Empiezo de cero» / wipe de grupos, un fallo a mitad puede dejar el par peligroso «cursor de sync borrado + filas Split* vivas» (o al revés). La regla de área lo marca: al re-asociar re-emite upserts con HLC nuevos. El docblock promete UNA transacción; el `save()` cruza `groups.sqlite` y `syncmeta.sqlite`.

Hermano de `detach-failure-looks-like-success` (el fallo ya se ve) y de la saga detach/ledger (#319). No es UI, no es Cola B/C, no es adaptativo.

MODO AUTÓNOMO hasta el final: al cumplir el criterio, abre PR a `2.1`, encola auto-merge (ADR-054) y cierra solo con `/cerrar-total`. No despiertes a Jürgen por preferencias reversibles; elige Recommended en Paso 0 y sigue. Solo para si hace falta su dispositivo, secretos o algo irreversible/prod.

## Qué se pide
1. Lee el ticket entero y el código vivo: `DataWipeService.deleteLocalGroupsRows`, `CloudSessionSignOut.purgeGroupsDomainForDetach`, la regla L211 de `.claude/rules/swiftdata-cloudkit.md`, y el andamio `GroupsDetachPurgeFailureTests`.
2. Mide el hueco ANTES de arreglar: con tres stores on-disk y `syncmeta` en solo lectura (`allowsSave: false`), grupos escribible — corre el purge y cuenta `SplitGroup` vs `GroupSyncCursor` después. Confirma si la atomicidad prometida existe o no (los tests de hoy fallan `alsoDeleting` ANTES del save; miden rollback en memoria, no el save cross-store).
3. Arregla para que morir entre stores no deje el par incoherente: dos `save()` con orden que haga inocuo el corte, o un sello/reparador de arranque que deje el par reparable. Recommended: orden de saves que haga inocuo el kill (documenta en Paso 0 si eliges el sello).
4. Cubre también los llamadores que pasan `alsoDeleting` (desasociar, «Empiezo de cero», wipe de dominio grupos) — un arreglo en N sitios se prueba en los N.
5. Tests que fijen el bug en rojo→verde contra el save real cross-store (no solo el fallo pre-save). No aflojes guards vecinos (`PrivateSignOutWiringTests`, detach purge existentes).
6. Al terminar: mueve el ticket, PR a `2.1` con parte en el cuerpo, auto-merge, y **`/cerrar-total` de forma autónoma** (sin esperar a nadie).

## Qué NO hay que tocar
- No es carril adaptativo: no uses simuladores `YalaLane-Adapt-*` ni abras tickets de layout/iPhone/iPad.
- No abras Cola B (rediseño UI) ni Cola C / diferidos post-2.1.
- No reabras #319 (ledger) ni #320 (cabeceras); no toques `GroupsDetachedBridgeLedger` salvo que el purge lo deje inseparable (entonces dilo en el PR, no ensanches el alcance).
- No toques marketing/, store copy, schema CloudKit de Production, ni Supabase prod.
- No limpies worktrees ajenos ni relances otros encargos.
- No pidas OK a Jürgen por el camino Recommended del Paso 0.

## Cómo se sabe que está bien
- Medición previa documentada: con syncmeta read-only, el estado post-purge ya no puede ser el par peligroso (o el test demuestra el hueco y el arreglo lo cierra).
- Matar / fallar el segundo save no deja cursor borrado + filas vivas (ni el inverso dañino); tests nuevos o ampliados en rojo→verde.
- Desasociar y «Empiezo de cero» / wipe de dominio grupos siguen fallando cerrado a la vista cuando corresponde (no se revive el «éxito mentiroso» de detach-failure).
- PR abierto contra `2.1` con parte; sesión cierra limpia con `/cerrar-total` sin intervención.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Orden de saves o sello/reparador de arranque?** → Orden de saves (Recommended), sin sello nuevo.
Por qué: los dos pares a medias no pesan igual. «Cursor borrado + filas vivas» re-emite upserts con HLC
nuevo al volver a entrar y pisa el servidor para todos los miembros (irreversible). «Filas borradas +
cursor vivo» es local y tiene tres salidas que ya existen: el reintento del desasociar
(`GroupsDetachPendingPurge` + `retryDetachPurge`, que se arma en el `catch`), repetir el gesto, y el Merkle
de Grupos, que con filas locales vacías y remoto poblado da `.diverged`, resetea el cursor y re-baja el grupo
(inferido del código de `runGroupMerkleVerification`, no medido en device). Alternativa descartada: un sello
nuevo de arranque — otra marca durable con su propio ciclo de vida para cubrir un kill entre dos `save()`
síncronos consecutivos, cuando el fallo realista (el segundo `save()` lanza) ya lo cubre el `catch`.

**D2 · ¿Qué orden?** → outbox → `GroupBridgePreference` → filas de Grupos → cursor (revisado tras la review
adversarial; la primera versión era Grupos → outbox/cursor → preferencias).
Por qué: tres reglas. (a) El cursor no puede irse antes que las filas (el par que daña el servidor). (b) Las filas
de Grupos son el testigo con el que los reintentos de «Empiezo de cero» saben que falta borrar
(`checkHasExistingData` cuenta `SplitGroup`): con ellas fuera y otro tramo a medias, dos de los tres caminos daban el
borrado por hecho y el sello no se escribía nunca — así que van lo más tarde posible. (c) El outbox va primero: el
Merkle de Grupos salta los grupos con dead-letters, y con ellas el par reparable no se repararía solo.
Alternativas descartadas: syncmeta entero primero (deja el par peligroso); preferencias al final (deja el testigo
fuera antes que ellas).

**D3 · ¿Dónde vive el arreglo?** → Dentro de `DataWipeService.deleteLocalGroupsRows`, el escritor común de los
tres caminos (desasociar, su reintento, «Empiezo de cero» en sus tres llamadores). Firma intacta; el autor del
canal sigue envolviendo todos los saves. Por qué: un arreglo en el escritor lo heredan los N llamadores.

**D4 · ¿Cómo se prueba contra el save real?** → Tres stores on-disk con un fallo REAL en el segundo store
(medición previa con `allowsSave: false` y con un lock exclusivo de SQLite desde otra conexión), contando
`SplitGroup` y `GroupSyncCursor` en un contenedor nuevo. Un caso por llamador.

**D5 · Docblocks y regla de área.** → Se corrigen las frases que prometen «UNA transacción» (docblocks de
`deleteLocalGroupsRows`, `purgeGroupsDomainForDetach`, `wipeLocalGroupsDomain`) y la regla de
`swiftdata-cloudkit.md` (§ «ARCHIVOS, nunca FILAS» … y el bullet del cursor), con lo medido.

**D6 · `GroupsDetachedBridgeLedger`.** → No se toca: el purge no lo deja inseparable.
