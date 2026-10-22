# Los tests que eligen cuenta en «Nuevo registro» fallan siempre en iOS 27 y dejan el gate en rojo

## Contexto
Card del tablero `tablero-los-tests-que-eligen-cuenta-en-nuevo-reg-6fqv` (prioridad high, vence 2026-10-12). Ticket: `tickets/backlog/new-transaction-account-picker-uitests-fail-on-the-ios-27-lane-pro-max.md` (triage medium 2026-10-08 → high).

CADENA nocturna tras cerrar `after-session-redesign-review-widgets-siri-applepay-and-web-copy` (PR #413 en cola de auto-merge a 2.1; card pb6r en qa → jurgen). Alternación Cola A ↔ adaptive: no hay card adaptive lista, así que toca este high de Cola A.

Tres XCUITest que entran por el FAB del Panel y eligen cuenta en «Nuevo registro» fallan de forma estable en el runtime iOS 27.0 (Pro Max del carril y el iPhone 17 Pro del gate, `46287CFE`), también aislados y también con 2.1 limpio:
- `TransactionsCrudUITests.test_createTransaction` — «No se montó AccountSelectorSheet con filas.»
- `QuickActionsFavoritesUITests.test_saveAsFavoriteFromTransactionAppearsInList` — mismo mensaje.
- `EdgeCasesUITests.test_extremeMinimumAmountSaves` — `Failed to tap Button … identifier BEGINSWITH "account_selector_row_"`.
Los tres registran «Automation type mismatch: computed Button from legacy attributes vs PopUpButton from modern attribute» y buscan con `app.buttons` (`TransactionsCrudUITests.swift:61`). Lleva siete gates seguidos en rojo: la red del alta de un registro está ciega en el runtime del gate y cada sesión pierde tiempo bisecando lo mismo. La anotación del 2026-10-09 en el ticket llega con el PR #413; si al rebasar hay conflicto en ese ticket, conserva las dos versiones.

Relacionados (leer, no arreglar salvo que caiga solo): `record-selectors-uitest-taps-the-tags-chip-off-screen`, `transaction-save-helper-flake-one-per-suite`, `edgecases-extreme-minimum-flaky-under-load`.

Disco de la Mini ~29 GB libres (umbral 32). Antes de construir: limpia DerivedData de sesiones cerradas, cachés de XcodeBuildMCP de worktrees retirados y sims muertos. Si el disco baja de ~20 GB, para, limpia y sigue.

Pipeline serial Mini (obligatorio): (1) limpiar sims muertos/basura/DerivedData de sesiones cerradas/cachés XcodeBuildMCP de worktrees que ya no existen, sin preguntar; (2) `xcodebuild -jobs 2` sin sim booteado; (3) boot 1 sim; (4) tests; (5) apagar y limpiar ese sim. Prohibido solapar swift-frontend + SpringBoard + app + UITests. Un simulador a la vez.

DerivedData y cachés de XcodeBuildMCP: al lanzar y al cerrar, borra sin preguntar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen (retirados o con PR mergeado). No toques las de un worktree vivo. Si el borrado falla, dilo en el cierre.

Gate después del CI del PR anterior: justo antes del gate, mira si el PR #413 sigue en CI. Si sigue, espera a que entre y rebasa una sola vez sobre `origin/2.1` con el simulador apagado. Si `2.1` no se movió, sigue de frente. Si ese CI falla, no esperes: rebasa con lo que haya y sigue. Build y simulador van después de ese rebase, una sola vez. Base al lanzar: `4c973dd8a`.

## Que se pide
1. Medir qué elemento sale como `PopUpButton` en iOS 27.0 (la fila del selector de cuenta o el chip de cuenta del formulario) con un volcado del árbol de accesibilidad en el momento del fallo.
2. Arreglar los tres tests con la opción más robusta y sin bajar lo que verifican: si es un `Menu`/`Picker` de SwiftUI que iOS 27 expone con otro tipo, el arreglo es del test (buscar por identificador con `descendants(matching: .any)` o un helper compartido de selección de cuenta usado por las tres suites). Si resulta que la hoja de verdad no monta filas en iOS 27, es de producto: arréglalo y dilo en el cierre.
3. Verde estable: los tres casos en lote (con las suites del gate) y aislados, dos rondas, en el iPhone 17 Pro iOS 27.0 del gate, centinela en 0. Comprueba que no se rompen en el runtime anterior si está instalado.
4. Si otros tests usan el mismo patrón `app.buttons … account_selector_row_`, pásalos al helper.
5. Anota lo resuelto en el ticket y muévelo según las convenciones del repo; `coverage-index` si aplica.
6. Card `6fqv`: sin QA manual → **done → frank**. Ticket o residual si algo queda fuera.
7. Al terminar: `/cerrar-total` autónomo (PR a 2.1 con auto-merge, card bien puesta, quitar worktree/tmux/DerivedData/cachés de XcodeBuildMCP de este worktree, ningún sim encendido).

## Que NO hay que tocar
- Más de 1 simulador.
- No relajar ni borrar aserciones para que pase; no marcar los tests como skip.
- Nada de producto fuera del selector de cuenta salvo que el paso 2 lo pida.
- Ni deploy, ni secretos, ni claves nuevas.
- No reabrir el trabajo del PR #413 salvo el rebase.

## Como se sabe que esta bien
Los tres XCUITest pasan en iOS 27.0 en lote y aislados, dos rondas, con el centinela en 0; el ticket explica qué cambió en iOS 27 y por qué el arreglo es del test o del producto; PR a 2.1 en auto-merge y card en done.

## Paso 0

Decidido antes de tocar código (sesión autónoma, auto-contestado):

1. **Primero medir, luego elegir el lado del arreglo.** Volcado de `app.debugDescription` en el punto del fallo, en el
   iPhone 17 Pro iOS 27.0 (`46287CFE`). Pista de partida, de lectura: `test_recordSelectorsOpenAtMediumDetent` usa la
   MISMA consulta (`app.buttons … account_selector_row_`) y no figura entre los rojos; la diferencia es que los tres
   rojos teclean el monto antes de tocar el chip (teclado abierto).
2. **Si es tipo de elemento** (la fila u otro sale como `PopUpButton`), el arreglo es del test: helper compartido en
   `YalaUITests/Support/` que busca por identificador con `descendants(matching: .any)` y lo usan todas las suites con
   ese patrón. **Si la hoja no monta o el toque no llega**, se arregla donde esté la causa y se dice.
3. **Sin bajar aserciones**: el helper sigue exigiendo que la fila exista y que el formulario vuelva con cuenta elegida.
4. **Runtime anterior**: en la Mini solo hay iOS 27.0 instalado (`simctl list runtimes`), así que no se puede medir en
   26.x; se dice en el cierre. El CI corre con Xcode 26.6 y es la red de ese runtime.
5. **Un simulador**, pipeline serial, `sim-lock.sh` en cada corrida.
6. **PR #413**: antes del gate, mirar si sigue en CI; rebasar una vez sobre `origin/2.1` con el sim apagado.
7. Card `6fqv` → done → frank si no queda QA manual.
