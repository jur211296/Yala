---
id: ipad-drop-unreadable-file-fails-silently
status: backlog
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
