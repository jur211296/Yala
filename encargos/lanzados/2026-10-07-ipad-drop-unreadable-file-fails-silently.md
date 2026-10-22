# En iPad, soltar un PDF o una imagen ilegible sobre Yala da un aviso claro en vez de no hacer nada

## Contexto
Card del tablero `tablero-ipad-soltar-un-pdf-o-imagen-ilegible-no-ti05` (lista para lanzar, prioridad baja). Ticket ya escrito: `tickets/backlog/ipad-drop-unreadable-file-fails-silently.md` (hallazgo del recorrido del registro por imagen del 2026-10-04).

Lo que le pasa al usuario: en iPad arrastra sobre Yala un PDF protegido o vacío, o un fichero que no es una imagen legible. El sistema acepta el soltar y no pasa nada: ni hoja ni mensaje. Según el ticket, en `Yala/App/Commands/RootCommandsModifier.swift` (`ReceiptDropHandler`) cada fallo de lectura solo hace `print` y `return`, después de haber devuelto `true` al sistema. Es la pista del ticket: verifícala en este árbol antes de tocar nada.

Relacionado: el ticket `ipad-keyboard-shortcuts-pointer-context-menus-and-drop` (en `qa`) cubre el camino feliz del soltar; no lo rompas.

Hoy se cerraron el PR #384 (los tres rojos de la suite UI) y el PR #385 (revisión del uso de IA, solo docs y tickets); los dos están en cola de auto-merge a 2.1. Ninguno depende de este encargo.

Para orientarte: `CLAUDE.md`, las `.claude/rules/` que toquen (en especial `swiftui-ds.md` para el aviso) y el ticket.

## Que se pide
1. Reproducir en el simulador de iPad el soltar de un fichero ilegible (PDF vacío o protegido, fichero que no es imagen) y confirmar que hoy no hay ninguna respuesta.
2. Darle al usuario una respuesta clara cuando el fichero no se puede leer, con la opción más robusta y coherente con el sistema de diseño y con cómo Yala ya avisa de errores en el registro por imagen. El texto va en español neutro latinoamericano y localizado como el resto de la app. Si el sistema permite rechazar el soltar antes de aceptarlo para los tipos que nunca vamos a leer, valóralo, pero el caso de un PDF o una imagen que sí son del tipo correcto y salen ilegibles necesita aviso igual.
3. El camino feliz (imagen o PDF legible) sigue igual.
4. Cubrirlo con test: lógica pura del manejador si se puede separar, y un control que salga rojo con el código viejo. Si un test de UI del soltar no es viable en el simulador, deja un guion de device-QA en `tickets/qa/` para iPad.
5. Capturas: el cambio se ve, así que deja `capturas/antes.png` (sin respuesta tras soltar) y `capturas/despues.png` (el aviso) en el worktree, con las rutas absolutas en el cierre.
6. Mueve el ticket a donde toque según las convenciones del repo.
7. Cierre: `/cerrar-total` autónomo (PR a 2.1 con auto-merge, limpieza). Al cerrar, mueve la card `tablero-ipad-soltar-un-pdf-o-imagen-ilegible-no-ti05` a «in qa» y asígnala a jurgen si queda device-QA en iPad, o a «done» si no queda nada para él, con `tablero mover <id> --a "<estado>" --agente frank`.

## Que NO hay que tocar
- El pipeline de lectura de la foto (modelos, prompts, gateway): esto es solo el soltar y su aviso.
- El código muerto de OCR local `Yala/App/Services/ImageOCR/`.
- `qa.yml`, `nocturna-vigilante.yml`, `ping-avisador.yml` ni `avisar-grok-push-principal.yml`.
- Nada de marketing/ ni Web/.

## Pipeline de la Mini (serial, obligatorio)
1. Limpiar sims muertos, DerivedData de sesiones cerradas y cachés de XcodeBuildMCP de worktrees que ya no existen, sin preguntar. El disco anda justo (~30 GB libres, por debajo del umbral de 32).
2. Build con `xcodebuild -jobs 2` sin simulador booteado.
3. Boot de 1 solo simulador (iPad para este caso).
4. Tests.
5. Apagar y borrar ese simulador.
Prohibido solapar swift-frontend + SpringBoard + app + UITests.

Gate tras el CI de los PR anteriores: la sesión arranca ya sobre `origin/2.1`. Justo antes del gate, mira si los PR #384 y #385 siguen en CI. Si siguen, espera a que entren y rebasa una sola vez, con el simulador apagado. Si `2.1` no se movió, sigue de frente. Si ese CI falla, no esperes: rebasa con lo que haya y sigue. El build y el simulador van después de ese rebase, una sola vez.

DerivedData y cachés de XcodeBuildMCP: al lanzar y al cerrar, borra el DerivedData de esta sesión y las cachés de worktrees retirados o ya mergeados, sin pedir aprobación. No toques los de otra sesión viva. Si el borrado falla, dilo en el cierre.

## Como se sabe que esta bien
- En iPad, soltar un fichero ilegible muestra un aviso claro y localizado; el soltar de un fichero legible sigue abriendo el registro igual que antes.
- Test con control rojo con el código viejo, o guion de device-QA para iPad si el soltar no se puede automatizar.
- Builds `Yala` y `Yala Dev` verdes; capturas antes y después en `capturas/`.
- PR a 2.1 en auto-merge, card del tablero movida, Mini limpia (sim apagado y borrado, sin DerivedData de la sesión).

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**Hechos medidos antes de decidir.** La pista del ticket es cierta en este árbol: `ReceiptDropHandler` devuelve `true` y
sus tres fallos (datos que no llegan, imagen ilegible o PDF sin página, no poder guardar en `PendingImages/`) solo hacen
`print` y `return`. El `onDrop` ya acepta solo `[.image, .pdf]`, así que lo que no es imagen ni PDF el sistema lo rechaza
antes de soltar. El ticket relacionado `ipad-keyboard-shortcuts-pointer-context-menus-and-drop` está en `done`, no en `qa`.

**D1 · ¿Qué ve el usuario?** → El registro por imagen se abre en su pantalla de fallo, con «No pude abrir este archivo» y
«Otra foto». Por qué: es como Yala ya avisa de un archivo ilegible desde Archivo, dentro de la misma hoja, y deja
una salida. Alternativa descartada: un `.alert` en la raíz. Su productor es asíncrono, y la regla de presentaciones de
`swiftui-ds.md` obliga a que vaya por el router; meterlo ahí pedía un `RouterIntent` nuevo y un alert más en un anchor
que ya ha roto flujos ajenos.

**D2 · ¿Por dónde llega?** → Por el router, con los intents que ya existen (`.presentImageEntry` o `.requestAIConsent(.image)`),
y el fallo viaja por ventana en `SceneNavigation.pendingImageEntryFailure`, como `pendingSharedImageURL`. Por qué: sin
intents nuevos ni anchors nuevos. Alternativa descartada: escribir los bytes ilegibles en `PendingImages/` para que la hoja
fallara sola; es un truco y la recuperación del arranque los re-emitiría.

**D3 · ¿Consentimiento de IA?** → Sí, el mismo que un recibo legible. Por qué: desde el fallo, «Otra foto» lleva a
leer con IA. Si el usuario no acepta, el fallo pendiente se borra para que no aparezca la próxima vez.

**D4 · ¿Copy?** → Un caso nuevo `ImageEntryFailure.unreadableFile` con copy propio en los 16 idiomas, porque «No pude abrir
esta imagen» no vale para un PDF. Archivo, desde dentro de la hoja, pasa a usarlo también: el mismo PDF ilegible no puede
dar dos textos según por dónde entre.

**D5 · ¿PDF protegido?** → `firstPageJPEG` lo trata como ilegible (`isLocked`). Se mide en test que PDFKit lo abre bloqueado.

**D6 · ¿No poder guardarlo en `PendingImages/`?** → Fallo `.generic` («falló la lectura»), no «no pude abrirlo»: el archivo
está bien y lo que falló es nuestro.

**D7 · ¿Rechazar antes de aceptar?** → No hace falta más: el filtro de tipos ya lo hace. El contenido de un PDF o una imagen
no se puede validar antes de que el sistema entregue los datos.

**D8 · ¿Tests?** → Unit de la lógica separada (`outcome` y `receive` con un sink de prueba, control rojo con mutante del
`return` viejo) + XCUITest con un seam `-uitest-receipt-drop` que suelta por el `handle` real. El arrastre entre apps no se
puede conducir desde XCUITest: queda un guion de device-QA para un iPad real.
