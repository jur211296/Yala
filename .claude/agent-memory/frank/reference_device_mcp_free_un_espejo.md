---
name: device-mcp-free-un-espejo
description: Device MCP Free solo abre un espejo a la vez; si otro dispositivo lo ocupa, el simulador se conduce con axe + simctl.
metadata:
  type: reference
---

Device MCP en plan Free admite **un espejo a la vez**: con el iPhone 14 (u otro) ya espejado, `select_device` o
`take_screenshot` sobre un simulador fallan con «Device MCP Free allows one mirror at a time». No se cambia el espejo
de Jürgen: se conduce el simulador con `axe describe-ui/tap/swipe --udid` y `xcrun simctl io <udid> screenshot`.

Medido el 2026-11-12 al revisar los disparadores de Atajos en iOS 27.2. En Atajos los toques de axe por coordenada a
veces no entran tras un cambio de hoja: esperar 2-3 s y releer con `describe-ui` antes de tocar. Relacionado:
[[device-mcp-lo-enciende-jurgen]].
