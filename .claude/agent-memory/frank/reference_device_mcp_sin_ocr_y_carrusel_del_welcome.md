---
name: device-mcp-sin-ocr-y-carrusel-del-welcome
description: En el iPhone 14 el árbol/OCR de Device MCP puede fallar (CRImageReaderError) y el carrusel de la bienvenida mueve los botones: pausar antes de tocar.
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
Ver [[conducir-el-iphone-real-con-device-mcp]].
