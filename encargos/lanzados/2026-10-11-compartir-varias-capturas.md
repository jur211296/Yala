# Yala no aparece al compartir varias capturas a la vez

## Contexto
Card del tablero `tablero-yala-no-aparece-al-compartir-varias-capt-3ut5` (versión 2.2, medium). Reporte de Jürgen (10-oct): con una captura Yala sale en el menú de compartir; con varias, no. Causa probable: `YalaShare/Info.plist` tiene `NSExtensionActivationSupportsImageWithMaxCount = 1`. El flujo de compartir foto ya pasó por #441 (lectura con la app cerrada, `EntryReadinessLogic`, `DeferredIntentBufferLogic`, `PendingImages/`) y #453 (el Panel espera a que se cierre la hoja de otra pestaña). Lee `docs/entry-points.md` y esos PRs; reutiliza ese camino, no inventes otro.

## Qué se pide
- Que Yala aparezca al compartir hasta N imágenes. Propuesta de la card (decídelo en Paso 0 y documéntalo en el PR): cada imagen genera su borrador en la Bandeja, con un tope razonable (p. ej. 10) y aviso claro si se pasa; respetando el gate Pro y el consentimiento de IA.
- Tests: unitarios del reparto en borradores y del tope; XCUITest si es viable.
- Capturas antes/después (`capturas/antes.png`, `capturas/despues.png`; mira `~/Claude/referencias-ui/README.md`).

## Rama
La card es 2.2, pero si el cambio es seguro y acotado va en PR a `2.1`. Si choca con la política de ramas del repo, abre el PR igualmente contra `2.1` **como borrador** y explícalo en el cuerpo.

## Qué NO hay que tocar
- El prompt/modelo de lectura de imágenes, nube/CloudKit, marketing/.
- Si encuentras otro hallazgo, crea card: `tablero crear --proyecto Yala --titulo "..." --version 2.1 --agente frank` (sin --fecha).

## Reglas de build y Mini (obligatorias)
- `nice -n 10 xcodebuild -jobs 2 ...`. Antes de cada build, esperar a que el load average (uptime) sea < 8.
- Nunca filtrar la salida del build con `| head`. `-only-testing` como array de argumentos (uno por target/test).
- Pipeline serial: limpiar → build sin sim booteado → boot 1 simulador → tests → apagar y erase de ese simulador. Un solo simulador a la vez; nunca build con sim booteado.
- DerivedData de esta sesión y cachés de XcodeBuildMCP de worktrees que ya no existen: bórralos al cerrar sin preguntar. No toques los de otra sesión viva.
- Gate tras el CI del PR anterior (#455): arranca ya sobre `origin/2.1`; no partas de su rama. Justo antes del gate, mira si #455 sigue en CI; si sigue, espera a que entre y rebasa una sola vez con el sim apagado; si 2.1 no se movió, sigue; si ese CI falla, no esperes: rebasa con lo que haya. Build y simulador van después de ese rebase, una sola vez.

## Cómo se sabe que está bien
Al compartir varias capturas Yala aparece y cada una llega a la Bandeja como borrador (con tope y aviso); tests nuevos en verde; PR a 2.1 con antes/después. Si el compartir real solo se puede verificar en iPhone, deja el ticket en `qa` con guion. Al terminar, `/cerrar-total` (sim apagado y borrado, Mini limpia).

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**Hechos medidos antes de decidir.** `YalaShare/Info.plist` activa con `NSExtensionActivationSupportsImageWithMaxCount = 1`
(la causa). La extensión guarda UNA foto en `PendingImages/<UUID>.jpg` y abre `yala://shared-image`; la app coge
`pendingImageURLs().first` y la hoja de lectura (`ImageSelectionView`) la lee. Esa misma hoja YA lee tandas de hasta
`PDFPageImport.maxPagesPerBatch` (10) fotos o páginas: cada foto da sus borradores, se insertan en la Bandeja al leer,
«Guardar» los aprueba y cerrar los deja en la Bandeja.

**D1 · ¿Qué tope?** → 10 fotos por vez, el mismo de Fotos y de los PDF (`PDFPageImport.maxPagesPerBatch`).
Por qué: un solo número en toda la lectura por imagen. Alternativa descartada: un tope propio para compartir (dos números
para lo mismo divergen).

**D2 · ¿Qué pasa con más de 10?** → Yala aparece hasta 100 fotos; la extensión guarda las 10 primeras y la hoja avisa
cuántas quedaron sin leer y cómo leerlas. Por qué: con el tope en la activación (10) Yala desaparecería del menú sin
decir nada, que es el bug reportado. Alternativa descartada: activación ilimitada con predicado `SUBQUERY` (deja entrar
selecciones mixtas con vídeo y no aporta nada real por encima de 100). Residual: con más de 100, Yala no aparece.

**D3 · ¿Cómo llega cada imagen a la Bandeja?** → Por la hoja de lectura que ya lee tandas: la tanda compartida entra en
`startReading` como una selección múltiple de Fotos. Por qué: es el camino que el encargo pide reutilizar y ya respeta
dedupe, fallos por foto, cupo de prueba y «quedan en la Bandeja». Alternativa descartada: borradores en segundo plano sin
hoja (camino nuevo, sin revisión ni aviso de fallos).

**D4 · ¿Cómo viaja la tanda hasta la hoja?** → En el nombre de los ficheros de `PendingImages/`
(`<tanda>-<nn>-<compartidas>.jpg`); el router sigue llevando UNA URL y la hoja la expande a su tanda. Por qué: no toca
`RouterIntent.presentSharedImage`, el buffer serializado ni sus fixtures; la recuperación del arranque y el aplazamiento
siguen igual. Un fichero con el nombre de antes (`<UUID>.jpg`, recibo soltado en el iPad) es una tanda de uno.
Alternativa descartada: `.presentSharedImage([URL])` (cambia el router y el formato persistido del buffer).

**D5 · Gate Pro y consentimiento de IA.** → Sin Pro se descarta la tanda ENTERA y sale la hoja de Pro una vez; sin
consentimiento la tanda espera en disco y la hoja la lee al aceptarlo. Por qué: el mismo trato que una foto, sin que la
recuperación vuelva a mostrar el aviso por cada foto que quedara.

**D6 · Tanda a medias.** → La extensión escribe cada foto como `.part` y las renombra al final. Por qué: la recuperación
de primer plano lee `PendingImages/` y no debe coger media tanda.

**D7 · Fallos de carga dentro de la extensión.** → Se guardan las que se pudieron cargar; si ninguna, error como hoy.
Residual aceptado: una foto que no se pudo cargar en la extensión no se avisa.

**D8 · Rama.** → PR a `2.1`: el cambio es acotado (extensión + entrada de la hoja) y no toca nube, prompt ni marketing.

**Ficheros (nota, no pregunta):** `YalaShare/Info.plist`, `YalaShare/ShareViewController.swift`, un helper compartido
nuevo (`YalaWidgets/Utils/SharedImageBatch.swift`, miembro de Yala y YalaShare como `WidgetURLHelper`),
`Yala.xcodeproj/project.pbxproj`, `Yala/Services/SharedContainerService.swift`, `Yala/App/AppBootstrapper.swift`,
`Yala/App/Views/Image/ImageSelectionView.swift`, `Yala/App/UITestSharedImageStage.swift`, `Yala/Utils/L10n.swift` + 16
`.strings`, tests (`YalaTests/SharedImageBatchTests.swift`, `YalaUITests/Flows/SharedImageEntryUITests.swift`),
`docs/entry-points.md`, `qa/coverage-index.json`.
