---
name: conducir-el-iphone-real-con-device-mcp
description: Cómo conducir y grabar el iPhone 14 de pruebas desde la Max con Device MCP, y qué no hace (teclado, open_url, PasteButton, Google).
metadata:
  type: reference
---

Medido el 2026-11-05 en la Max (Device MCP 0.5.0 gratis, iPhone 14 iOS 27.2 por cable):

- **Registrado a mitad de sesión no da tools**: se le habla por stdio con un cliente JSON-RPC (`device-mcp` +
  `initialize` + `tools/call`); `start_recording`/`stop_recording` sobreviven entre procesos (el .mov va a
  `~/Movies/Device MCP/`). Requiere el servidor MCP encendido en la app (lo enciende Jürgen).
- **`fill`/`type_text` teclean como teclado inglés**: con el teclado español del iPhone `:/=&` salen cambiados
  (`httpsÑ--yala'app…`). Letras y dígitos sí. Para texto con símbolos: `set_clipboard` y que pegue Jürgen.
- **`open_url` pide aprobación en la Max** y caduca a los 2 min. Sin ella: `xcrun devicectl device process launch
  --payload-url <url> <bundle>` entrega el enlace a la app.
- **El `PasteButton` no responde a toques sintéticos tampoco en el iPhone real**: tiene que tocarlo Jürgen.
- Google (`accounts.google.com`), Face ID, ajustes del sistema: Jürgen. Ver [[device-mcp-lo-enciende-jurgen]],
  [[el-iphone-de-pruebas-es-el-14-por-cable]].
- La Max no tenía cuenta de desarrollador en Xcode: Jürgen la añadió (Xcode › Settings › Accounts); sin ella,
  0 identidades y `No Accounts`.

Medido el 2026-11-09 (Device MCP con tools en sesión, versión gratis):

- **`build_and_run` es de la licencia Pro.** Sin ella: `xcodebuild -scheme "Yala Dev" -configuration Debug-Dev
  -destination id=<udid> -allowProvisioningUpdates build` y `xcrun devicectl device install app --device <udid> <.app>`.
- **`save_screenshot` con `overwrite: true` pide aprobación en la Max** y caduca a los 2 min, colgando el batch:
  usa siempre un nombre nuevo.
- **Atajos sirve de Siri sin voz**: Atajos › Yala Dev › la acción lanza el App Intent; vale para el camino de la hoja
  de Pro. La galería de widgets y Atajos enseñan contactos y apps personales: no las captures.
- **StoreKit en Yala Dev instalada así**: «No pudimos cargar los precios». Lo de compras va con TestFlight
  ([[qa-en-yala-dev-antes-que-prod]]).
