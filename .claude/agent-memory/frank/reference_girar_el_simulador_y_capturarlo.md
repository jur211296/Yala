---
name: girar-el-simulador-y-capturarlo
description: Cómo sacar una captura del simulador girado en la Max (sin app Simulator, Device MCP atado al iPhone): XCUITest con XCUIScreen.
metadata:
  type: reference
---

Medido el 2026-11-17 en la Max (iOS 27.2, Device MCP gratis):

- No hay app «Simulator» que girar por menú (`open -a Simulator` falla) y `rotate` de Device MCP no llega al simulador
  mientras el gratis refleja el iPhone 14.
- Lo que funciona: un XCUITest con `XCUIDevice.shared.orientation = .landscapeLeft` y la captura con
  `XCUIScreen.main.screenshot()`. Con `app.screenshot()` la imagen sale descuadrada (media pantalla negra y el contenido
  girado). El PNG exportado lleva la orientación en metadatos: `magick … -auto-orient` antes de usarlo.
- Las capturas se sacan del `.xcresult` con `xcrun xcresulttool export attachments`.

Ver [[conducir-el-iphone-real-con-device-mcp]].
