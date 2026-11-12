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
