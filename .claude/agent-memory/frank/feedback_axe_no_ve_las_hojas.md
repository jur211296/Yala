---
name: axe-no-ve-las-hojas
description: Al conducir el simulador a mano, axe describe-ui no ve el contenido de una hoja y sus toques no abren filas de List; el snapshot_ui de XcodeBuildMCP sí.
metadata:
  type: feedback
---
`axe describe-ui` devuelve el árbol de la pantalla de DEBAJO cuando hay una hoja presentada, así que parece que
el toque no abrió nada aunque la hoja esté arriba (mírala con una captura, no con el árbol). Y un toque de axe sobre
una fila de `List` dentro de una hoja (Ajustes › Cuentas) no la abre; `snapshot_ui`/`wait_for_ui` + `tap` de
XcodeBuildMCP sí. En los selectores de Archivos, un toque de 0,1 s puede leerse como pulsación larga: 0,05 s.
**Why:** el 2026-10-14 (lote 7) perdí una docena de vueltas creyendo que la app no respondía.
**How to apply:** captura de pantalla como verdad; filas de List con MCP; el resto con `axe touch` por coordenadas.
Y antes de volver a XCUITest tras teclear con axe o MCP, `simctl erase` (regla de testing.md).
**2026-11-19 (maquetas de Nuevo registro):** tampoco abrió la hoja el toque de axe sobre «Nuevo registro» del Panel
(`panel_action_new`, «Tap completed» y nada), ni dentro de la hoja los segmentos de tipo; ni tras reiniciar el
simulador. El `tap` de XcodeBuildMCP sobre la ref de `snapshot_ui` abrió y cambió todo a la primera. Para capturar
estados de una hoja: MCP para tocar, `simctl io screenshot` para la foto. El tema oscuro de la app es el de fábrica
de `-uitest`; claro, `-userTheme 1` (la apariencia del simulador no lo cambia).
**2026-11-20 (oferta Pro):** `axe tap -x -y` sobre un `Button(.plain)` dentro de la hoja de la oferta SÍ empujó la página
(6 de 6, tres modelos). Y `device-mcp-cli tap` no sirve con un simulador si el espejo de Device MCP Free está en el
iPhone físico: contesta «mirrors one device at a time» y no toca. Coordenadas medidas en la captura (píxeles ÷ escala).
