# Con needsRelaunch, la sección Grupos vuelve a quedar sin puerta para desasociar

## Contexto
Cola A (riesgo real, medium). Ticket: `tickets/backlog/needsrelaunch-hides-the-groups-section.md`.
Carril: una sola sesión Yala a la vez (alternancia Cola A ↔ adaptive). Adaptive 13/13 ya cerró; associate-cta (#328) quedó en cola de auto-merge — este es el siguiente natural de la misma review adversarial de `cloud-killswitch-hides-the-only-door-to-detach-groups` (mismo surface: Ajustes → «¿Dónde viven tus datos?»).
Base: `origin/2.1` fresco (incluye #327).
Día (Lima): si hace falta una decisión de producto/riesgo, pregunta; si no, decide en autónomo.

## Qué se pide
1. Lee el ticket entero y mide en código actual (no asumas el snapshot del 11-sep): en `StorageSettingsView`, el `case .needsRelaunch` solo pinta la card de relanzamiento y **omite** la sección Grupos. El estado es durable (`mirrorOffArmed` / `phase == .reverseMountMirror`). El daño real es `.needsRelaunch(.toICloud)`: ahí la sección sí aplicaría con `offersDetach == true` y la persona se queda sin puerta hasta matar la app.
2. Comportamiento esperado: la sección Grupos **convive** con la card de relanzamiento (misma justificación ya escrita para `.waitingForLeader` / `.failed`: journal persistido → ocultar dejaría sin desasociar indefinidamente). La card sigue siendo la instrucción principal («cierra Yala y vuelve a abrirla»); no la conviertas en pantalla normal ni debilites el mensaje de relanzar.
3. `.migrating` / `.reverting` durante el cutover: mide si el hueco importa; en `.reverting` el ticket dice daño nulo (no ofrece detach). No amplíes alcance sin medir.
4. Tests que cubran: needsRelaunch(.toICloud) + asociación viva → sección Grupos visible con puerta de desasociar; needsRelaunch no borra/oculta la card de relanzamiento; casos ON de waitingForLeader/failed siguen intactos.
5. Mueve el ticket a `qa` (o `done` si no aplica device-QA) y deja el PR en cola de auto-merge a `2.1`.

## Pipeline Mini (obligatorio — serial, 1 sim)
1. Limpiar sims muertos / basura previa
2. Build con `xcodebuild -jobs 2` **sin** sim booteado
3. Boot **1** solo sim
4. Tests
5. Apagar y erase/limpiar data de ese sim
Prohibido solapar swift-frontend + SpringBoard + app + UITests. Norma flota: 1 sim a la vez.

## Qué NO hay que tocar
- No CI de GitHub runner / workflows salvo que el ticket lo pida (no lo pide).
- No marketing/, no clinicas.
- No CloudKit Production schema ni cambios de infra ajenos a StorageSettings / sección Grupos.
- No relanzar adaptive ni otro ticket en paralelo.
- No reabrir associate-cta (#328) ni tocar el kill-switch salvo que midas un acoplamiento real al montar la sección.

## Cierre
Al terminar (PR listo o bloqueo real): `/cerrar-total` **autónomo** sin esperar. Deja la Mini limpia: apagar sim de la sesión → erase/limpiar data del device → si el PR ya mergeó o el worktree ya no sirve, quitar worktree + `.ddp`/caches → no acumular Devices apagados ni worktrees. No dejes la sesión colgada.

## Cómo se sabe que está bien
- En `.needsRelaunch(.toICloud)` con cuenta de grupos asociada, la sección Grupos aparece y ofrece desasociar; la card de relanzamiento sigue visible y clara.
- No se introduce un camino que permita usar la app «normal» sin relanzar cuando el diseño pide relanzar.
- Gate/tests verdes en local; PR a `2.1` con auto-merge; ticket fuera de backlog.

## Paso 0 — decisiones (resueltas en autónomo, bypass)

1. **¿La premisa del ticket se sostiene?** No. Medido en `2.1` (b051d8d03): en `.needsRelaunch(.toICloud)` el
   modo sigue en `.cloud`. `.mountMirrorAndRelaunch` solo desarma el flag («DESARMA el flag manteniendo `.cloud`»,
   `MigrationWorkExecutor`); `.persistICloudMode` solo sale en el cuarteto de `reverseUpload → icloudActive` y en el
   aborto del paso 4 (→ `failedRollback`). Con `.cloud`, `deviceState == .cloudComplete` ⇒ la sección sería
   `.sameAccountAsPersonal`, que no ofrece desasociar. Las otras dos aristas de `needsRelaunch` (cutover/adopt y
   `.rearmMirrorOff`) también escriben `.cloud`.
2. **¿Se monta la sección junto a la tarjeta de relanzamiento?** No. No abriría ninguna puerta (solo pintaría «tus
   grupos usan esta misma cuenta»), y añadiría contenido a una tarjeta cuyo diseño es «cierra y vuelve a abrir».
3. **¿Qué se entrega entonces?** Un test que fija la cadena entera (efecto real → modo → estado de UI → estado de la
   sección → sin puerta), para que si algún día una arista escribe `.icloud` antes de relanzar, salte; y un
   comentario en el `case` que explica por qué la sección no está. Cobertura del área `cloud-migration-ui`.
4. **`.migrating` / `.reverting`.** `.reverting`: modo `.cloud` ⇒ daño nulo (lo dice el ticket y lo confirma la
   misma medición). `.migrating` pre-cutover sí tiene modo `.icloud`, pero es tránsito salvo el adopt que se
   reintenta, que ya conserva la sección. No se amplía alcance.
5. **Ticket** → `done` (no hay device-QA: no cambia nada visible).
