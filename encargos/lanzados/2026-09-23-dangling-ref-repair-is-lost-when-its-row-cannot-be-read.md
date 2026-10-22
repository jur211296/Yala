# Si la app no puede leer un movimiento al final de la sync, ya no pierde a qué categoría o cuenta apuntaba

## Contexto
Cola A autónoma (restore/cloud sin callejones). Acaba de mergear a `2.1` el PR #216 (`apply-overwrites-a-pending-local-write-without-its-guards`): en `applyPage`, «no pude leer» ya no es «no hay nada». Quedó como residual **very-high** el mismo patrón **fuera** de `applyPage`, en el pase final de refs pendientes: `dangling-ref-repair-is-lost-when-its-row-cannot-be-read`.

Memoria del proyecto: `.claude/agent-memory/frank/project_apply_no_pisa_sin_salvaguardas.md` — el dangler es el siguiente candidato natural. Ticket en `tickets/backlog/dangling-ref-repair-is-lost-when-its-row-cannot-be-read.md`.

Horario Lima ~00:08 (nocturno): elige la opción recomendada / más robusta sin AskUserQuestion. Solo aparca si la decisión es demasiado importante para asumirla (datos irreversibles o acceso de Jürgen).

Regla de producto vigente: ante cualquier decisión técnica/producto, elige la opción más robusta / buena práctica, nunca la más simple.

## Que se pide
Cierra el ticket `dangling-ref-repair-is-lost-when-its-row-cannot-be-read` (very-high, modo-nube/sync):

1. Al empezar: muévelo a `in-progress` y deja `docs/TICKETS.md` al día.
2. En el pase final (`reresolveDanglingRefs` / `EntityApplyMap.reresolveDangler`): una fila origen ilegible NO es `.rowGone`. Conserva el dangler (tercer desenlace, p. ej. `.unreadable` vía `find*`, no los `fetch*` lenient que convierten throw en `nil`).
3. `clearDangler` / `registerDangler`: un fetch de `SyncDanglingRef` que lanza no deja un dangler viejo ni un duplicado.
4. `resolveRef`: un destino ilegible no pisa una ref local buena con `nil` (coherente con tirar la página / no asumir vacío, misma familia que #216).
5. Tests con fetch lanzando + control positivo (seam `EntityApplyMap._testThrowOnFetchOf` o el equivalente que ya exista tras #216).
6. Gate verde. Destino del simulador en esta Mac: si `name=iPhone 17 Pro` sin `OS=` falla con exit 70, usa `id=9D0F6D32-1F49-46AD-8070-603D42B5220F` (iPhone 17 Pro / 26.5); ticket conocido `the-gate-destination-no-longer-resolves-on-this-mac`.
7. PR a `2.1`, merge, board a `done` (o `qa` solo si hace falta QA manual en iPhone; este caso suele ir a `done` con seam/XCTest), `docs/TICKETS.md` al día, `/cerrar-total`.

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board del repo, actualizar `docs/TICKETS.md`, merge y `/cerrar-total` sin preguntar si corre el gate o el commit. Bugs/decisiones nuevas → ticket propio (`--solo-crear`) antes de cerrar. Solo parar ante decisión/acceso real de Jürgen (de noche: decide lo recomendado o aparca).

OVERRIDE (Jürgen 2026-09-22): la regla del repo «espera aprobación si >3 ficheros» / «¿Sigo?» tras el plan queda **suspendida** en este encargo. Implementa hasta el final sin pedir continuar. No preguntes «¿Sigo?» ni gates de conteo de ficheros.

## Que NO hay que tocar
- No reabrir el alcance de #216 dentro de `applyPage` (ya cerrado).
- No mezclar en este PR el residual high `drain-duplicates-the-unit-clock-when-its-row-cannot-be-read` (bloqueado por el `catch` sin rollback de `drainOnce`) ni el low `a-local-read-failure-in-the-migration-apply-reads-as-network`, salvo ticket propio si surgen de camino.
- No tocar `marketing/` ni Web/.
- No inventar device-QA si el caso no tiene guion razonable en iPhone.

## Como se sabe que esta bien
- Criterios del ticket cumplidos (dangler ilegible sobrevive; sin dangler viejo/duplicado; destino ilegible no pisa ref buena; tests con throw).
- Gate verde; PR mergeado a `2.1`; ticket en el estado correcto; `docs/TICKETS.md` coherente; `/cerrar-total` OK.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL y key en fichero local, no en git; no las escribas en el repo) cuando:
  (1) necesitas una decisión de producto o de acceso de Jürgen;
  (2) abriste el PR o dejaste preview/artifact listo;
  (3) terminaste el ticket y vas a /cerrar-total — incluye en el aviso un resumen corto de cierre en lenguaje de usuario (qué se hizo), no solo «cerré»;
  (4) acabaste un tramo y no tienes siguiente paso claro (aunque no haya pregunta formal) — una vez, no en bucle.
NO avises por: un test rojo que vas a reclasificar, un build que vas a reintentar, ni ruido de CI advisory. URL/key solo en la Mini.

## Paso 0

Resuelto sin nadie delante (00:10 Lima, nocturno): opción más robusta en cada rama. Medido en este árbol
(`9a97f617`), no leído del ticket.

**Medido antes de decidir**

- Los appliers de columna se invocan en UN solo sitio: `applyToEntity` (`SyncApplyEngine.swift:410`), al que solo
  llega `dispatchApply`, al que solo llaman `applyPage` y `drainQuarantineOnce`. Los dos envuelven el bucle en
  `saveWithAuthor` con `catch { rollback }`. ⇒ un applier que lanza cae en el rollback que ya existe.
- `fetchTags` / `fetchAccounts(byShortcutIDs:)` / `fetchSubcategories(byShortcutIDs:)` solo tienen llamadores dentro
  de los appliers (`EntityApplyMap.swift:403,407,916`).
- La premisa del ticket «`registerDangler` inserta un duplicado» es **falsa** en el código de hoy: si el fetch lanza,
  el `catch` se salta el update y el insert. El efecto real es otro y no menos grave: la nota nueva **no se escribe**
  (fila sin ref y sin rastro del destino) o la vieja se queda con el destino **viejo**. Un duplicado solo aparecería
  si alguien convirtiera ese fetch en tolerante (`nil`), que es justo el mutante a matar.
- `reresolveDanglingRefs` ya conserva todo si falla el fetch de la tabla de danglers o el save; el agujero es solo
  el `nil` de la fila origen ⇒ `.rowGone` ⇒ borrado.

**Decisiones**

1. **Pase final: tercer desenlace `.unreadable`**, que conserva el dangler. `reresolveDangler` pasa a `find*`
   (lanza) para la fila **y** para el destino; cualquier lectura que lanza ⇒ `.unreadable`. Se sigue con el resto de
   danglers (son independientes: uno ilegible no frena los que sí se resuelven) y el pase se reintenta en cada ciclo,
   así que el fail-closed tiene quien vuelva a preguntar. `.rowGone` queda para la ausencia leída de verdad. El
   `default` (combinación desconocida ⇒ `.rowGone`) no es una lectura fallida y no se toca.
2. **Appliers: la lectura que falla TIRA LA PÁGINA** (no «basta con no pisar la ref»). `ColumnApplier.apply` pasa a
   `throws`; `resolveRef`, `clearDangler` y `registerDangler` lanzan. Coherente con #216 y medido que no hay
   applier fuera de un save con rollback. «No pisar» a secas dejaría avanzar el cursor con el valor del wire sin
   aplicar ni registrar: el mismo dato perdido por otro camino.
3. **M2M (punto 4 del ticket) entra**: `tag_refs`, `subcategory_ids`, `account_ids` pasan a lecturas que lanzan. Viven
   en el mismo save y el mismo applier que ya lanza (el gemelo vive en el mismo save); dejar un `setTags([])` por
   avería vaciaba la relación aunque el CSV la salvara.
4. **Seam**: el existente `EntityApplyMap._testThrowOnFetchOf`, dentro del helper que hace el fetch real
   (`fetchFirstOrThrow` y uno nuevo para las lecturas M2M), con las claves `SyncDanglingRef`, `Tag`, `Account`,
   `Subcategory` además de las de fila.
5. **Breadcrumb**: `applyPageFailed(reason: "reresolve:unreadable…")` una vez por pase con alguna fila ilegible. Es un
   `logger.notice`, no un contador: no toca telemetría.
6. **Fuera** (encargo): `drain-duplicates-the-unit-clock-…`, `a-local-read-failure-in-the-migration-apply-…`, y
   `liveRowExists`/`verifyRebinds` (un conteo de breadcrumb, no mueve datos).
7. **Destino del gate**: `id=9D0F6D32-1F49-46AD-8070-603D42B5220F` (ticket `the-gate-destination-no-longer-resolves-on-this-mac`).
8. **Board**: `done` sin device-QA. Una base local ilegible no se provoca en un iPhone.

**Tras la review (3 lentes, en árbol aislado)**

9. Sin defectos altos ni medios en lo cambiado. Entra en este PR: breadcrumb propio `danglersUnreadable(count:)` (el
   `applyPageFailed` anunciaba un atasco que no había), cobertura de las 18 ramas del pase y de los 25 appliers que
   leen (con scan: un `fetch*` tolerante compila limpio), el drenaje de cuarentena con un applier que lanza, el orden
   del caso «uno ilegible entre dos legibles» y controles positivos que ESCRIBEN.
10. A ticket propio (fuera del alcance del encargo): `dangling-ref-pass-overwrites-a-pending-local-edit`,
    `post-pull-reconcilers-read-an-unreadable-table-as-nothing-to-repair`, `a-malformed-ref-leaves-a-stale-dangler`, y
    nota en `a-local-read-failure-in-the-migration-apply-reads-as-network` (su saco crece con estas lecturas).
11. Intercambio aceptado y escrito en la regla: una tabla ilegible para siempre deja el pull en `.transient`.
12. Encontrado al commitear, fuera del producto: el sello del gate cambia si un renombrado entra o sale del índice y
    no ve su lado borrado (`the-gate-stamp-hides-the-deleted-side-of-a-staged-rename`, low). Re-sellado tras comprobar
    que el disco no cambió (la huella vuelve al poner el rename en el índice).

**Cierre:** gate verde (build `Yala` y `Yala Dev` sin warnings en lo tocado; 7582 unit en 747 suites; 4 XCUITest de
`EdgeCasesUITests` + `WelcomeFreshStartAlertUITests`, centinela solo). 17 mutantes, todos muertos. Ticket a `done`.
