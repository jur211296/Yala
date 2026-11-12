---
name: portapapeles-y-pastebutton-en-simulador
description: En iOS 27.0, simctl pbcopy no llega al simulador y el PasteButton del sistema ignora los toques sintéticos de XCUITest; cómo se prueba igual un «pegar»
metadata:
  type: reference
---

Medido el 2026-10-21 (lote decidido 2.2 · 14, «Pega tu enlace»):

- `xcrun simctl pbcopy <udid>` devuelve 0 y `simctl pbpaste` sale vacío: el portapapeles del simulador no recibe nada.
- Desde el runner de XCUITest, `UIPasteboard.general.string = …` + tocar el `PasteButton` del sistema no pega: el campo
  no cambia (el control de pegado seguro no acepta toques sintéticos).
- `axe type` tampoco escribe en un `TextField` recién enfocado si no se toca con `axe touch` down/up (y deja el teclado
  físico armado: erase antes de volver a XCUITest).

**How to apply:** lo que hace la app con el texto pegado se prueba escribiendo el texto entero con `typeText` en el
XCUITest (la extracción es la misma); el toque del botón «Pegar» va al guion de iPhone de Jürgen. Relacionado:
[[conducir-simulador-con-axe]].
