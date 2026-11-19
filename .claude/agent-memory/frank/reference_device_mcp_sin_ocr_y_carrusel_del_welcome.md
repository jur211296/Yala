---
name: device-mcp-sin-ocr-y-carrusel-del-welcome
description: iPhone 14 con Device MCP — scroll_to/wait_for caen al OCR y fallan, overwrite pide aprobación, Device Hub retiene el espejo; y el carrusel de la bienvenida mueve los botones.
metadata:
  type: reference
---

Medido el 2026-11-13 (iPhone 14, iOS 27.2.1, Yala Dev):

- `list_elements`, `scroll_to` y `wait_for` fallaron con «Text recognition failed … CRImageReaderError error 1». Lo que
  funciona: `take_screenshot` + `tap` por coordenadas + `swipe`. Para leer texto exacto (una dirección de correo),
  `save_screenshot` lossless y recortar con `sips`; `get_clipboard` pide aprobación en la Mac.
- El carrusel de la bienvenida 2.3 cambia la altura de su tarjeta y **mueve «Entrar con Google»**: un toque por coordenadas
  cayó en «Dividir gastos con amigos». Pausar el carrusel (botón ⏸ arriba a la derecha de la tarjeta) y volver a capturar.
- La hoja «Yala quiere usar accounts.google.com» es del sistema: la toca Jürgen.
- «Cerrar sesión» de Ajustes deja el teléfono como recién instalado tras «cierra y vuelve a abrir»: `terminate_app` +
  `launch_app` vale; medir con devicectl que el store queda a cero (solo tipos de cambio).
- Avisos de banco a la dirección de Yala de staging: `smtplib` a `route2.mx.cloudflare.net:25` desde `@yalainbox.com`
  (script en el scratchpad de la sesión; `timeout` no existe en macOS para acotar `wrangler tail`).

Remedido el 2026-11-19 (misma pareja):

- `list_elements` (`view=controls`, con `include_offscreen` para encontrar un botón al final) y `tap_text` sí funcionaron;
  `scroll_to` y `wait_for` siguen cayendo al OCR y fallan. Para bajar: `scroll` con `distance` y `x/y` en el contenido.
- `save_screenshot` con `overwrite: true` pide aprobación en la ventana de Device MCP y a los 2 min no corre: guardar
  con un nombre nuevo y mover el viejo.
- «blocked: Another app (such as Xcode's Device Hub) is mirroring» con el Device Hub de esta Mac abierto y sin otra sesión de
  Yala: `reconnect_device` lo recupera al momento.
- Sin Pro, `build_and_run` no va: `xcodebuild build -destination id=<udid> -allowProvisioningUpdates` y
  `devicectl device install app`; el `.app` sale en `/Volumes/ExtDev/DerivedData/…/Debug-Dev-iphoneos/` (míralo en el log).

Ver [[conducir-el-iphone-real-con-device-mcp]].
