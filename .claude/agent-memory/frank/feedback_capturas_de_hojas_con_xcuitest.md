---
name: capturas-de-hojas-con-xcuitest
description: Para capturar pantallas dentro de la hoja de Ajustes, un XCUITest con XCTAttachment sale más barato que axe: los swipes de axe cierran o tocan la hoja
metadata:
  type: feedback
---

Las capturas de pantallas que viven dentro de la hoja de Perfil/Ajustes (Temas, Icono de la app) se sacan con el propio
XCUITest del cambio: `XCTAttachment(screenshot:)` con `.keepAlways` y después
`xcrun xcresulttool export attachments --path <bundle> --output-path <dir>` (el `manifest.json` empareja nombre y fichero).

**Why:** el 2026-10-19 (lote decidido 06) tres intentos con `axe swipe` dentro de la hoja de Perfil acabaron igual: el
gesto se leyó como toque (abrió Tutoriales o Personalización) o cerró la hoja. El XCUITest, que ya tenía que escribir,
llegó a las dos pantallas a la primera con `swipeUp()` y dejó las capturas.

**How to apply:** si la pantalla a capturar pide desplazarse dentro de una hoja, no conduzcas con axe: añade el
`capture(app, "<nombre>")` al XCUITest del caso y extrae los adjuntos. axe sigue valiendo para pantallas de primer
nivel y toques por id. Relacionado: [[conducir-simulador-con-axe]].
