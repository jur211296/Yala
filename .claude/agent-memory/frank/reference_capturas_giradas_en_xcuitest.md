---
name: capturas-giradas-en-xcuitest
description: En el simulador, app.screenshot() con el iPhone girado sale recortado; XCUIScreen.main.screenshot() sale entero (rotarlo 90°). Device MCP Free no sirve si espeja el iPhone 14.
metadata:
  type: reference
---

Medido el 2026-11-23 (encargo «Conecta tu IA», iPhone 17 Pro, iOS 27.2, en la Max):

- `XCUIDevice.shared.orientation = .landscapeLeft` + `app.screenshot()` da un PNG de 2622×1206 con la mitad en negro y
  el contenido recortado: no sirve de evidencia. **`XCUIScreen.main.screenshot()`** sale entero (1206×2622, de lado):
  `magick in.png -strip -rotate 90 out.png`.
- Las capturas de XCUITest llevan orientación EXIF: `magick … -auto-orient` las «endereza» mal. Usa `-strip`.
- En la Max no hay `Simulator.app` (Xcode 27 usa Device Hub): girar por AppleScript no es posible.
- **Device MCP Free espeja un solo aparato**: con el iPhone 14 espejado (aunque esté bloqueado) no conduce el simulador;
  cambiarlo es un clic de Jürgen («Mirror This Simulator Instead»).
- El tema de Yala no sigue al simulador: «claro» es `-userTheme 1` (ver [[tema-claro-de-yala-en-el-simulador]]).

Relacionado: [[device-mcp-lo-enciende-jurgen]].
