# El XCUITest del hero de Distribución tras un registro nuevo falla en la tanda 2 del CI

## Contexto
Card del tablero `tablero-el-xcuitest-del-hero-de-distribucion-tra-drax` (Yala 2.1, medium). Run de CI 38059703509 (HEAD dc9ad91, 10-oct 09:34 Lima): `StatisticsHeroLikePanelUITests.test_distributionHeroFollowsANewRecord` falla 3 de 3 intentos esperando a que `new_transaction_account_chip` / `subcategory_chip` dejen de moverse (el teclado los desplaza). El test lo añadió el PR #417; no lo causan #433-#439. Mismo patrón que la card 6fqv (PR #414): usar el helper de espera de iOS 27 o cerrar el teclado antes. Lee #414 y #417 y reutiliza ese helper; no inventes otro. Revisa también si el test sigue fallando hoy en `origin/2.1` (mira los últimos runs de CI con `gh run list`), por si ya se arregló de rebote.

## Qué se pide
- Que el test pase de forma estable (3 de 3) en local con iOS 27 y en la tanda 2 del CI, **sin bajar lo que verifica** (el hero de Distribución sigue al registro nuevo).
- Si el fallo revela un bug real de la app (no solo del test), arréglalo y dilo en el PR.
- Sin capturas salvo que cambie algo visible.

## Qué NO hay que tocar
- No desactivar ni saltar el test, no subir timeouts a ciegas, no cambiar la matriz del CI. Nada de nube/CloudKit ni marketing/.
- Si encuentras otro hallazgo, crea card: `tablero crear --proyecto Yala --titulo "..." --version 2.1 --agente frank` (sin --fecha).

## Reglas de build y Mini (obligatorias)
- `nice -n 10 xcodebuild -jobs 2 ...`. Antes de cada build, esperar a que el load average (uptime) sea < 8.
- Nunca filtrar la salida del build con `| head`. `-only-testing` como array de argumentos (uno por target/test).
- Pipeline serial: limpiar → build sin sim booteado → boot 1 simulador → tests → apagar y erase de ese simulador. Un solo simulador a la vez; nunca build con sim booteado.
- DerivedData de esta sesión y cachés de XcodeBuildMCP de worktrees que ya no existen: bórralos al cerrar sin preguntar. No toques los de otra sesión viva.
- Gate tras el CI del PR anterior (#461): arranca ya sobre `origin/2.1`; no partas de su rama. Justo antes del gate, mira si #461 sigue en CI; si sigue, espera a que entre y rebasa una sola vez con el sim apagado; si 2.1 no se movió, sigue; si ese CI falla, no esperes: rebasa con lo que haya. Build y simulador van después de ese rebase, una sola vez.
- PR contra la rama `2.1`.

## Cómo se sabe que está bien
`test_distributionHeroFollowsANewRecord` pasa 3 de 3 en local (iOS 27) y en la tanda 2 del CI del PR, verificando lo mismo que antes; PR abierto a 2.1. Al terminar, `/cerrar-total` (sim apagado y borrado, Mini limpia).

## Paso 0

Auto-contestado (sesión lanzada en bypass, sin nadie delante).

- **¿Sigue fallando en `origin/2.1`?** Intermitente, no arreglado de rebote. Nocturnas de la tanda 2: pasó el 9-oct (`37950667923`) y el 11-oct (`38149084065`), falló 3/3 el 10-oct (`38059703509`). Los push a `2.1` no corren la UI (`skipped`). La UI del CI es advisory, por eso esos runs salen verdes.
- **¿Hay que inventar un helper?** No. El test ya usa `chooseFirstSelectorRow` de #414; el rojo sale de DENTRO de su `waitForSettledLayout`.
- **Causa (medida en el log del 10-oct, iteración 2):** en el runner frío cada consulta a la UI cuesta 1–3,5 s («Checking existence of Keyboard» 85,27 s → «Find the Keyboard» 88,76 s). `waitForSettledLayout` necesita tres lecturas (fijar marco + dos iguales) dentro de 5 s de reloj; caben dos y devuelve «no dejó de moverse» con todo quieto. El CI corre iOS 26.5, no 27.
- **Hipótesis descartada:** suite previa que deja el simulador en «teclado físico» (regla de `testing.md`). La única suite que corrió antes solo el día rojo es `AppleIDCloseNoticeUITests`, que no teclea; `KeyboardShortcutsUITests` corrió antes también el 9-oct y pasó.
- **Arreglo:** el plazo acota el movimiento, no el coste de leer. El helper hace siempre las lecturas mínimas para poder concluir «quieto» aunque el plazo venza a mitad; si en ellas algo se mueve, sigue devolviendo `false`. No sube ningún timeout ni baja ninguna aserción.
- **¿Bug de la app?** No: es latencia del runner leyendo la UI.
- **Otras instancias:** solo este helper exige varias lecturas seguidas; los demás sondeos (`waitUntilOnScreen`, `rotate`) aceptan con una lectura buena.
- **Prueba local del caso del CI:** mutante temporal que añade ~2 s de latencia por lectura dentro del helper: rojo sin el arreglo, verde con él.
