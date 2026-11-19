---
name: girar-para-qa-sin-device-mcp-pro
description: Cómo probar «con el iPhone girado» cuando el iPhone 14 tiene el bloqueo de rotación y Device MCP Free solo refleja un aparato; y el susto de la app personal.
metadata:
  type: reference
---

Medido el 2026-11-17 en la Mini (encargo «Pagos que se repiten: banner y hoja»):

- **`rotate` de Device MCP en el iPhone 14 falla con el bloqueo de rotación puesto** («did not rotate… Turn off Lock
  Rotation»). Y justo después, el siguiente toque abrió la **app de Spotify personal** de Jürgen y un
  `save_screenshot` la capturó con sus listas. Se borró la captura en el acto. ⇒ tras un `rotate` fallido, mira
  `get_foreground_app` o una captura antes de tocar nada, y nunca guardes una captura sin mirarla.
- **Device MCP Free refleja un solo aparato**: con el iPhone tomado, no conduce el simulador (lo dice el error).
- **El simulador se gira sin Simulator.app** (en Xcode 27 no existe; es DeviceHub): `osascript -e 'tell application
  "DeviceHub" to activate' -e 'delay 1' -e 'tell application "System Events" to key code 123 using command down'`
  (⌘←; 124 = ⌘→ para volver). Se comprueba con el tamaño del `simctl io screenshot` (2622×1206 = horizontal).
- **`devicectl device process launch` necesita `--` antes de los argumentos de la app** (`-- -uitest -uitest-reset …`):
  sin él toma `-uitest` como opción suya y sale con el «Usage».
- El tema de Yala no sigue al del sistema: claro es `-userTheme 1` al lanzar; `set_appearance` no lo cambia.

Ver [[conducir-el-iphone-real-con-device-mcp]], [[tema-claro-de-yala-en-el-simulador]].
