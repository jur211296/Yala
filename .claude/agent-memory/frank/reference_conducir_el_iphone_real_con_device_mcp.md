---
name: conducir-el-iphone-real-con-device-mcp
description: Cómo conducir y grabar el iPhone 14 de pruebas desde la Max o la Mini con Device MCP, y qué no hace (teclado, open_url, PasteButton, Google).
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

**En la Mini también (2026-11-10)**: Jürgen instaló Device MCP y el iPhone 14 va por Wi-Fi (`iPhone de JURGEN`). Si no
sale entre las herramientas de la sesión, el binario es `/Applications/Device MCP.app/Contents/MacOS/device-mcp` y se le
habla igual por stdio (initialize → notifications/initialized → tools/call; un proceso por tanda vale, la grabación
sobrevive). Para escribir «con el teclado de la pantalla», `list_elements` con `include_keyboard: true` y `tap` en las
teclas: `press_key` manda teclas de hardware, no lo que hace un dedo. `wait` no admite `device`.
