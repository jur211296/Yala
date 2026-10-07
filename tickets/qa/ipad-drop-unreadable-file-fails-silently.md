---
id: ipad-drop-unreadable-file-fails-silently
status: qa
updated: 2026-10-07
qa-status: needs-testing
priority: low
area: "image"
created: 2026-10-04
source: recorrido del registro por imagen (encargo 2026-10-04-mejorar-el-registro-por-imagen-de-punta-a-punta)
---

# Soltar en iPad un PDF o una imagen ilegible no hace nada

## Qué le pasa al usuario

Arrastra un PDF protegido, vacío o un fichero que no es imagen sobre Yala. Se acepta el soltar, y no pasa nada:
ni hoja ni mensaje.

## Dónde (medido en este árbol, base `5a7f6f9e6`)

`Yala/App/Commands/RootCommandsModifier.swift`, `ReceiptDropHandler`: si no se leen los datos, si no es imagen
legible o si `PDFDocument(...)?.page(at: 0)` es `nil`, solo hay un `print` y `return`. Ya ha devuelto `true` al
sistema, así que el soltar parece aceptado.

Relacionado: `ipad-keyboard-shortcuts-pointer-context-menus-and-drop` (en `qa`) prueba el camino feliz.

## Hecho (2026-10-07)

Soltar sobre Yala algo que no se puede abrir ya no se queda en nada: se abre Nuevo registro por imagen en su pantalla de
fallo, «No pude abrir este archivo», con el motivo probable (vacío, dañado o protegido con contraseña) y «Elegir otra
foto». Es la misma pantalla que sale al elegir un archivo ilegible desde Archivo, dentro de la hoja, y Archivo pasa a
usar este mismo texto: «No pude abrir esta imagen» no valía para un PDF.

- Lo que no es imagen ni PDF ya lo rechazaba el sistema antes de soltar (`onDrop` solo acepta esos dos tipos).
- Un PDF protegido con contraseña cuenta como ilegible (`firstPageJPEG` mira `isLocked`); vale también para Archivo.
- Si falla guardar lo soltado en `PendingImages/`, el fallo es el genérico («falló la lectura»): el archivo está bien.
- Va por el router y con el consentimiento de IA, como un recibo legible. Si el usuario no acepta, el fallo se olvida.
- Unit: `YalaTests/ReceiptDropHandlerTests`. XCUITest: `YalaUITests/ReceiptDropUITests`, con el seam
  `-uitest-receipt-drop` que suelta por el `ReceiptDropHandler.handle` real (arrastrar entre apps no se puede conducir
  desde XCUITest).

## Guion de device-QA para Jürgen (iPad, ~5 min)

Montaje:

1. Un iPad con la build de este PR, sesión con Pro (o prueba activa) y el consentimiento de IA ya aceptado (si no,
   en el paso 3 sale primero el aviso de consentimiento: acéptalo).
2. En la app Archivos del iPad, deja tres ficheros: una foto de un recibo, un PDF protegido con contraseña y un
   fichero renombrado a `.jpg` que no sea una imagen (por ejemplo, un `.txt` renombrado). Los tres se pueden pasar
   desde el Mac con AirDrop a Archivos.
3. Abre Yala y, deslizando desde el borde inferior, saca el Dock; arrastra Archivos al lateral para tenerlo en
   Split View junto a Yala.

Pasos:

1. **Arrastra el PDF protegido** desde Archivos y suéltalo sobre Yala. Pasa: se abre Nuevo registro por imagen con
   «No pude abrir este archivo» y el botón «Otra foto».
2. Toca **«Otra foto»**. Pasa: la hoja vuelve a ofrecer Cámara, Fotos y Archivo. Ciérrala.
3. **Arrastra el `.jpg` falso** y suéltalo. Pasa: el mismo aviso del paso 1.
4. **Arrastra la foto del recibo**. Pasa: se abre Nuevo registro por imagen y lee la foto, como antes de este cambio.


## Encontrado por el camino (tickets propios)

- [[image-entry-uitests-cannot-reach-the-fab-on-ipad]]
- [[keyboard-shortcut-command-f-uitest-goes-red-on-a-used-ipad-simulator]]
- [[declining-ai-consent-keeps-a-dropped-or-shared-photo-pending]]
- [[image-entry-uitests-save-stays-off-for-a-complete-record]]
