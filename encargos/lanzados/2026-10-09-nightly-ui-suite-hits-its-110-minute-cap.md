# La QA nocturna se corta por tiempo cada noche y un cuarto de las suites UI nunca corre

## Contexto
Card del tablero `tablero-la-qa-nocturna-se-corta-por-tiempo-cada-7zso` (prioridad high). Ticket: `tickets/backlog/nightly-ui-suite-hits-its-110-minute-cap-every-night.md` (triage medium 2026-10-08 → high). Brief: `~/Claude/tmp-frank/nightly-ui-suite-hits-its-110-minute-cap-every-night.md`.

CADENA nocturna tras cerrar `new-transaction-account-picker-uitests-fail-on-ios-27` (PR #414 en cola de auto-merge a 2.1, solo tests; card 6fqv en done). No hay card adaptive lista para lanzar, así que sigue Cola A.

El paso `UI tests (YalaUITests) — solo nocturna · advisory` de `.github/workflows/qa.yml` (~línea 485, `timeout-minutes: 110`, `-only-testing:YalaUITests`, `-retry-tests-on-failure` en ~494) agota su tope en las diez últimas nocturnas: solo arrancan ~62 de las 84 suites de `YalaUITests/Flows/`, y las del final del alfabeto (`TransactionsCrudUITests` incluida) no corren en ningún CI. Como el paso es `continue-on-error`, el run sale verde igual. Además, el job va a 146,7 min frente a un tope de 150 (`qa.yml` ~306), así que cualquier rojo de unit con reintentos lo cancela entero (pasó el 2 y el 7 de octubre). La tabla de topes de `qa.yml` (~260-274, del 2026-09-07, UI p95 76 min) ya no es verdad. `.github/workflows/nocturna-vigilante.yml` lee el cron de `qa.yml`: si cambias crons o partes la suite, tócalo también.

Esto es trabajo de CI, sin build iOS local salvo que lo necesites para medir. Si llegas a compilar o abrir un simulador, sigue el pipeline serial de la Mini: (1) limpiar sims muertos/DerivedData de sesiones cerradas/cachés de XcodeBuildMCP de worktrees que ya no existen, sin preguntar; (2) `xcodebuild -jobs 2` sin sim booteado; (3) boot 1 sim; (4) tests; (5) apagar y limpiar ese sim. Un simulador a la vez. Al cerrar, borra sin preguntar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees retirados; si el borrado falla, dilo en el cierre. Disco de la Mini ~29 GB libres.

Gate después del CI del PR anterior: justo antes del gate, mira si el PR #414 sigue en CI. Si sigue, espera a que entre y rebasa una sola vez sobre `origin/2.1`. Si `2.1` no se movió, sigue de frente. Si ese CI falla, no esperes: rebasa con lo que haya y sigue.

## Que se pide
1. Medir con `gh run list` / logs cuánto duraría la suite UI entera en el runner: un `workflow_dispatch` de `qa.yml` sobre tu rama con el tope del paso de UI subido solo para medir (o el método equivalente más barato), y el reparto por suite.
2. Elegir y aplicar en `qa.yml` la opción más robusta: subir topes, partir la suite en dos pasos o dos noches (repartida para que ninguna suite quede fuera de forma fija), o quitar el reintento a los casos lentos. Deja escrita la decisión y las cifras en la tabla de topes. Objetivo: que las 84 suites corran al menos una vez cada 24 h, con el paso de UI bajo su tope y el job con al menos 15 min de margen.
3. Si cambias crons o el reparto, ajusta `nocturna-vigilante.yml` para que siga vigilando bien.
4. Validar con al menos un `workflow_dispatch` en tu rama que el log muestra arrancar todas las suites de su reparto y los tiempos caben.
5. Anota lo medido y lo decidido en el ticket. Como el criterio final pide tres nocturnas seguidas, deja el ticket en el estado que toque según las convenciones del repo con la comprobación pendiente escrita, y la card `7zso` en **in qa → frank** con la nota «verificar 3 nocturnas tras el merge» (no hace falta Jürgen).
6. Al terminar: `/cerrar-total` autónomo (PR a 2.1 con auto-merge, card bien puesta, quitar worktree/tmux/DerivedData/cachés de este worktree, ningún sim encendido).

## Que NO hay que tocar
- El gate de PR (los checks que bloquean merges) salvo lo mínimo para que la nocturna quepa; no hacerlo más lento.
- No quitar suites ni marcar tests como skip para que quepa; no bajar aserciones.
- Ni deploy, ni secretos, ni claves nuevas, ni cambios de runners de pago.
- Nada de producto.

## Como se sabe que esta bien
`qa.yml` con la decisión y la tabla de topes al día; un `workflow_dispatch` en la rama en el que arrancan todas las suites de su reparto, con el paso de UI bajo su tope y el job con ≥15 min de margen; PR a 2.1 en auto-merge; card en in qa → frank para verificar tres nocturnas.

## Paso 0

Medido antes de decidir (nocturna 37802106095, 8-oct, sobre `2.1`):

- Antes de la UI el job gasta 36 min (build 15,7 · pure-logic 15,8 · context 3,8). La UI arrancó a las 16:12:20 y se cortó a los 110 min con 65 suites cerradas (192 `func test`) y `SmartRefinementFabUITests` a medias. Reintentos: 2 casos. Es lentitud (~0,56 min por caso), no reintentos ni cuelgue.
- `YalaUITests/Flows/` tiene **85** suites (el encargo dice 84), una clase por fichero, 250 `func test`. Faltan 20 suites con 58 casos: ~33 min más. **Suite entera estimada: ~141 min** de UI, que con lo previo pondría el job en ~177 min.
- Reparto muy desigual: `AdaptiveNavigationUITests` 12,4 min, `IPhoneLandscapeUITests` 8,6, `SessionExitsPerCellUITests` 7,2; la mayoría 0,5-2.

Decisiones (autocontestadas, sesión autónoma):

1. **Partir la UI en 2 tandas que corren en paralelo cada noche**, en un job `ui` con matriz, cada una en su `macos-26` con su build. Descartado subir topes (job de ~3 h que vuelve a quedarse corto en cuanto crezca la suite), dos noches alternas (cada suite cada 48 h, incumple «cada 24 h») y quitar el reintento (solo 2 reintentos medidos: no es la causa).
2. **El reparto lo calcula un script desde el árbol** (`qa/scripts/ci-ui-tandas.sh`), no una lista en el YAML: una suite nueva cae en una tanda sin tocar nada. Equilibra por número de `func test` (greedy). La **última tanda es el complemento** (`-only-testing:YalaUITests` menos las suites de las otras): lo que el script no descubra corre igual. Ninguna suite queda fuera por construcción.
3. El job `tests` deja de llevar la UI. Su tope en la nocturna baja de 150 a 60 (medido 36); el del PR (45) **no se toca**.
4. Topes del job `ui`: paso de UI 110, job 150 (pre-UI ~20 min ⇒ aunque el paso agote su tope, el job conserva ≥20 min).
5. El aviso lee el resultado de cada tanda por outputs con nombre fijo (`ui_1`, `ui_2`); si una llega vacía, grita «no llegó a correr» (falla cerrado). Se comprueba en el dispatch.
6. `nocturna-vigilante.yml`: sigue un solo cron y una sola corrida diaria, y el vigilante cuenta runs, no jobs ⇒ su lógica no cambia. Solo se corrige el comentario de «nocturnas de 150 minutos».
7. `ci-sombra.yml` (la Mini, un solo runner) no se parte: queda con la suite entera. Fuera de alcance.
8. Banco `qa/scripts/ci-ui-tandas-test.sh` en `coverage-index`, como los demás scripts de CI.
9. Medición = validación: un único `workflow_dispatch` en la rama con las dos tandas corre la suite entera y da el reparto por suite.

**Revisión de la decisión 1 tras medir (dispatch 37906397439, dos tandas):** las 85 suites arrancaron y cerraron (42 + 43), pero cada paso de UI tardó 83,3 min: bajo los 110, con solo 1,3x de holgura, y la suite pasó de 149 casos (11-sep) a 250 (9-oct). Se sube a **3 tandas** (la más larga, ~61 min de suite con los tiempos de ese día). El mecanismo de salidas por tanda funcionó (aviso: tanda 1 `success`, tanda 2 `failure`). Segundo dispatch para validar las tres.
