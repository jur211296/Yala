# Un estado de cuenta en PDF se lee hasta su página 10, cada página cuenta como una foto, y si tiene contraseña Yala la pide

## Contexto
Card del tablero `tablero-un-estado-de-cuenta-en-pdf-solo-se-lee-e-4j2s` (in progress frank, prioridad alta, vence 2026-10-11). Ticket: `tickets/backlog/pdf-statement-reads-only-the-first-page.md` (pedido por Jürgen el 2026-10-07).

Hoy, al subir un estado de cuenta en PDF (+ › Registrar con imagen › Archivo, o soltarlo en el iPad) solo se leen los movimientos de la página 1; un PDF de tres páginas pierde la 2 y la 3 sin aviso. Si el PDF tiene contraseña (muchos bancos peruanos), la app lo da por ilegible.

**Decisión de Jürgen (2026-10-07), opción 1B:** se leen **hasta 10 páginas por PDF**, y **cada página cuenta como una foto** en la cuota gratuita. Abierto (criterio del ticket): cómo quitar duplicados entre páginas (saldo arrastrado, subtotales); si una página sin movimientos cuenta como fallo o se ignora; qué pasa con un PDF de más de 10 páginas (avisar, no leer en silencio). Contraseña (punto 2) y casos multipágina en el banco (punto 3) no cambian.

Pistas (verifícalas en este árbol):
- `ReceiptDropHandler.firstPageJPEG(pdfData:)` renderiza solo `document.page(at: 0)`, a 2×, como JPEG. Lo reusan el selector de Archivo y el soltar en el iPad.
- `guard … !document.isLocked`: PDF con contraseña → `nil` → «ilegible».
- Cada página entra como una «foto» más del flujo multi-foto (una `photo.read` por página).
- Coste: con `gpt-6-luna` ≈ 0,0005 USD por página. Tope de gasto por corrida del banco (misma clave prepago que prod, `.claude/rules/ai-gateway.md`).

Gate post-CI del PR anterior: justo antes del gate, mira si el PR #410 (o el anterior en cola) sigue en CI. Si sigue, espera a que entre y rebasea una sola vez con el simulador apagado. Si `2.1` no se movió, sigue. Si ese CI falla, no esperes: rebasea con lo que haya y sigue. Build y simulador van después de ese rebase, una sola vez.

Pipeline serial Mini (obligatorio): (1) limpiar sims muertos/basura/DerivedData de sesiones cerradas/cachés XcodeBuildMCP de worktrees retirados; (2) `xcodebuild -jobs 2` sin sim booteado; (3) boot 1 sim; (4) tests; (5) apagar/limpiar ese sim. Prohibido solapar swift-frontend + SpringBoard + app + UITests. Norma: 1 simulador a la vez.

Antes de tocar UI: `~/Claude/referencias-ui/README.md` y `.claude/rules/swiftui-ds.md`.

## Que se pide
1. Reproducir con un PDF ficticio de 3 páginas: hoy solo salen los movimientos de la 1.
2. Renderizar hasta 10 páginas y meter cada una en el flujo multi-foto, con progreso. Cada página consume un uso de foto: comprueba dónde se cuenta (app, gateway o los dos) y que un PDF de N páginas consuma N. Si la cuota se acaba a mitad, propón qué decir (recomendación: leer lo que cabe, decir cuántas quedaron sin leer y ofrecer Pro como el cupo agotado de hoy) y decide con la regla día/noche.
3. Más de 10 páginas: se leen las 10 primeras y la persona lo sabe (texto claro).
4. Duplicados entre páginas: saldo arrastrado y subtotales no son movimientos. Elige la solución más robusta medida en el banco y déjala escrita en el ticket.
5. Páginas sin movimientos (portada, condiciones): recomendación ignorarlas sin error salvo que ninguna traiga movimientos. Decide con regla día/noche y anótalo.
6. Contraseña: si `isLocked`, pedirla con campo seguro y `document.unlock(withPassword:)`. Nunca se guarda ni viaja: desbloqueo en el teléfono y solo sube la imagen de cada página. Si falla, «contraseña incorrecta», no «ilegible».
7. Banco: añade a `gateway/bench/cases/` extractos ficticios multipágina con saldo arrastrado; mídelos con tope de gasto. Si lo medido pide cambiar modelo/resolución de `photo.read`, propón en el ticket con números; en esta sesión no despliegues el Worker.
8. Textos nuevos (contraseña, >10 páginas, cuota a mitad) en los 16 idiomas con `qa/scripts/add-l10n-key.sh`, español neutro latinoamericano.
9. Tests: lógica pura del troceo (1, 3, 10 y 11 páginas; bloqueado con/sin contraseña buena) y XCUITest con PDF de 3 páginas sembrado.
10. Si el cambio se ve: `capturas/antes.png` y `capturas/despues.png` en el worktree, rutas absolutas en el cierre. Si no, guion device-QA en `tickets/qa/`. Aquí: antes PDF 3 páginas solo pág. 1; después las tres + petición de contraseña.
11. Anota la decisión 1B y lo resuelto en el ticket; muévelo según convenciones del repo.
12. Al terminar: `/cerrar-total` autónomo (PR a 2.1 con auto-merge, card a in qa→jurgen si queda device-QA o done→frank si no, limpiar worktree/tmux/DerivedData/cachés XcodeBuildMCP de este worktree, sin sims).

## Que NO hay que tocar
- No cambiar el modelo de `photo.read` en producción en esta sesión (solo proponer si el banco lo pide).
- No abrir más de 1 simulador.
- No tocar clinicas ni secretos nuevos en el Llavero sin subirlos a 1Password al cerrar.
- No pedir créditos ni claves nuevas.

## Como se sabe que esta bien
- PDF de hasta 10 páginas leído página a página; >10 avisado; contraseña pedida y no persistida; cuota por página.
- Tests de troceo + XCUITest verdes; PR mergeable a 2.1.
- `/cerrar-total` hecho y Mini limpia.

## Paso 0

Hora de arranque: 20:15 Lima (de día) → lo de producto se preguntó a Jürgen en una ronda; contestó las cuatro con la recomendada.

**Medido en este árbol**
- `ReceiptDropHandler.firstPageJPEG` solo pinta `page(at: 0)`; lo llaman el soltar (`outcome(for:isPDF:)`) y Archivo (`ImageSelectionView.loadImage`).
- La cuota se cuenta **solo en la pasarela**, por cada `photo.read`: free `vision: { trial: 5 }` en total, Pro `daily: 50`, ráfaga free 5/min y Pro 15/min (`gateway/src/policy.ts`). La app no lleva contador. ⇒ una página = una llamada = un uso, sin tocar la pasarela.
- `DraftDeduplicationService.deduplicate` ya quita duplicados DENTRO de lo nuevo (importe + día + nota parecida). Un «saldo anterior» y un «saldo que pasa» tienen notas distintas: esa red no los caza. El prompt de la foto no dice nada de saldos ni subtotales.
- `pendingImageURLs()` solo reconoce `.jpg`/`.png`; lo usan la recuperación del arranque y la purga del App Group.

**Decidido por Jürgen (2026-10-08, 20:17)**
1. Cupo a mitad: se lee lo que cabe y debajo sale «quedaron N sin leer: ya usaste tus fotos de prueba» con «Ver Yala Pro» en vez de «Reintentar».
2. Página sin movimientos: se ignora sin aviso; solo si NINGUNA trae movimientos, el fallo «sin importes».
3. Más de 10 páginas: se leen las 10 primeras y se dice al final, en lo leído.
4. Varios ficheros a la vez: tope de 10 páginas por tanda, sumando todos; lo que no entra, con el aviso del punto 3.

**Asumido (técnico)**
- El PDF soltado en el iPad se guarda TAL CUAL (`drop-<uuid>.pdf`) en `PendingImages/` y la hoja lo trocea al abrirlo: así la contraseña se pide en la hoja, igual que desde Archivo. `pendingImageURLs()` pasa a reconocer `.pdf`, para que la recuperación y la purga lo vean.
- Con el cupo agotado en la página k, las siguientes no se piden: salen como «sin leer» por cupo sin gastar llamadas.
- En la práctica guiada («Configura tu Yala») el tope es 1 página, como su selector de una foto.
- Imágenes sueltas por encima de 10 desde Archivo: como hoy (se toman las 10 primeras); el aviso de «más de 10» cuenta páginas de PDF.
- Contraseña: `@State` de la hoja, se borra al usarla o al salir; nunca a disco, log ni red. Solo sube la imagen de cada página.
- Duplicados entre páginas: lo decide el banco (fork en paralelo) — regla en el prompt si lo medido la pide; la red de `DraftDeduplicationService` se queda como está.
- Fichero de lógica pura nuevo: `Yala/App/Logic/PDFPageImport.swift` (troceo, tope, desbloqueo), con su test.

**Resuelto tras medir**
- Duplicados entre páginas: el banco (12 páginas ficticias, 66 lecturas con la fila de producción) no sacó ni un saldo ni un subtotal como movimiento ⇒ sin regla nueva en el prompt; queda la red de `DraftDeduplicationService`. `photo.read` sin cambios de modelo ni resolución. Coste: 0,041 USD.
- Antes/después medido con XCUITest: con el código de antes, el PDF de 3 páginas da 1 registro y el bloqueado no pide contraseña.
