# ReceiptDropUITests: el «no hay aviso de tope» del PDF nunca puede fallar

## Contexto
Card del tablero `tablero-receiptdropuitests-el-no-hay-aviso-de-to-g9jb` (Yala 2.1, medium). Hallazgo del PR #456 (compartir varias fotos): `ReceiptDropUITests` afirma «no hay aviso de tope» del PDF buscando el aviso como `otherElements`, pero el aviso es un `StaticText`; esa aserción no puede fallar nunca, así que no protege nada. La trampa quedó anotada en `.claude/rules/testing.md`. Lee #456 (tope de 10 compartido con `PDFPageImport.maxPagesPerBatch` y el aviso `image_shared_left_out`) y la regla de testing.

## Qué se pide
- Corregir la consulta para que busque el aviso por su identificador/tipo real (sin depender del tipo de elemento si se puede, p. ej. `descendants(matching: .any)` por identifier).
- Demostrar que ahora sí puede fallar: mutante (forzar que aparezca el aviso de tope) ⇒ rojo; código real ⇒ verde. Dilo en el PR.
- Barrer el resto de XCUITests por el mismo patrón (aserciones negativas `!exists` sobre `otherElements` de algo que es `StaticText`/botón) y arreglar las que encuentres; si son muchas, arregla las de esta suite y crea card para el resto.
- Si al hacerlo cae un bug real de la app, arréglalo y dilo claro en el PR.

## Qué NO hay que tocar
- Código de producto salvo bug real, la matriz del CI, timeouts a ciegas. Nada de nube/CloudKit ni marketing/.
- Si encuentras otro hallazgo, crea card: `tablero crear --proyecto Yala --titulo "..." --version 2.1 --agente frank` (sin --fecha).

## Reglas de build y Mini (obligatorias)
- `nice -n 10 xcodebuild -jobs 2 ...`. Antes de cada build, esperar a que el load average (uptime) sea < 8.
- Nunca filtrar la salida del build con `| head`. `-only-testing` como array de argumentos (uno por target/test).
- Pipeline serial: limpiar → build sin sim booteado → boot 1 simulador → tests → apagar y erase de ese simulador. Un solo simulador a la vez; nunca build con sim booteado. `ReceiptDropUITests` es de iPad: usa un sim iPad por UDID.
- DerivedData de esta sesión y cachés de XcodeBuildMCP de worktrees que ya no existen: bórralos al cerrar sin preguntar. No toques los de otra sesión viva.
- Gate tras el CI del PR anterior (#463): arranca ya sobre `origin/2.1`; no partas de su rama. Justo antes del gate, mira si #463 sigue en CI; si sigue, espera a que entre y rebasa una sola vez con el sim apagado; si 2.1 no se movió, sigue; si ese CI falla, no esperes: rebasa con lo que haya. Build y simulador van después de ese rebase, una sola vez.
- PR contra la rama `2.1`.

## Cómo se sabe que está bien
La aserción del aviso de tope ya puede fallar (mutante rojo / real verde); `ReceiptDropUITests` en verde en iPad; PR abierto a 2.1. Al terminar, `/cerrar-total` (sim apagado y borrado, Mini limpia).

## Paso 0

Decisiones, auto-contestadas (sesión autónoma):

1. **Consulta nueva:** `app.descendants(matching: .any)["image_pages_left_out"]`, no `staticTexts`: no depende del tipo con el que SwiftUI publique la fila (la regla de testing L120 lo recomienda).
2. **Prueba de que puede fallar:** mutante en producto `if pagesLeftOut > 0` → `>= 0` (el aviso sale siempre). Tres corridas de `test_threePagePDF_readsEveryPage` en iPad: mutante + consulta vieja (verde ⇒ demuestra que no protegía), mutante + consulta nueva (rojo), real + consulta nueva (verde, con la suite entera).
3. **Barrido (medido con grep sobre `YalaUITests/`):** hay 3 aserciones negativas sobre `otherElements`; las otras dos son `image_failed_photos`, que es un contenedor `.contain` y tiene un positivo hermano por `otherElements` (ImageEntryReviewUITests:123) que pasa ⇒ es `Other` y sus negativos sí pueden fallar. Inferido del positivo, no del árbol. No se tocan: alcance mínimo.
4. **Simulador:** iPad Pro 11-inch (M5) `FE5FC26C-…`.
