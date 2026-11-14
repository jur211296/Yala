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

Medido el 2026-11-14 (barrido de la parte 2, iPhone 14, iOS 27.2.1):

- **Los seams `-uitest-*` van en el iPhone real** con `launch_app` + `arguments` (p. ej. `-uitest -uitest-reset
  -uitest-pro -uitest-voice-result two`): sirve para lo que el teléfono no reproduce sin voz ni red. `-uitest-reset`
  borra la sesión; el siguiente arranque normal pide «reabre Yala» para soltar el iCloud, y luego la bienvenida.
- **Con una animación viva (la onda de la hoja de voz) el árbol de accesibilidad se queda congelado** en la pantalla
  anterior: `list_elements` devuelve otra vista. Para una etiqueta de VoiceOver, verifica en textos y tests.
- **Widget en dos toques:** pulsación larga sobre el icono de Yala Dev → la fila de tamaños de arriba lo convierte en
  widget sin pasar por la galería (que enseña apps personales). Para deshacerlo, pulsación larga → el tamaño icono.
- `press_button home` puede dejarte en otra página de inicio con apps personales: no la captures; desliza a la de Yala.

Medido el 2026-11-14 (barrido, parte 3):

- **`devicectl … process launch --console` dentro de `timeout N` MATA la app al vencer** (signal 15): para capturar
  la consola de un arranque y seguir mirando, deja el plazo largo o reabre la app después; si no, la «pantalla de
  inicio» que ves es tu propio corte, no un cierre de Yala.
- **`scroll_to` de Device MCP se cuelga >120 s** en pantallas largas de Yala (Más, Panel) y el batch pasa a segundo
  plano: usa `scroll` con `distance` y una captura.
- **Para volver a la app tras «Inicio», toca su icono**, no `launch_app`: con la app suspendida `launch_app` la
  relanzó y perdió la pantalla (y el filtro) que estabas probando.

Medido el 2026-11-14 (lote B del barrido):

- **`devicectl … process launch --console` solo trae `print`**: los breadcrumbs con `Logger` (`CloudSyncBreadcrumb`) no
  salen. Para leer un desenlace en el teléfono, que el breadcrumb imprima también en `#if DEBUG` (así se vio
  `CloudSignOut swap COMPLETED`). Engánchala en segundo plano y **no uses `launch_app` después**: relanza y corta la consola.
- Tras eliminar la cuenta en la nube, Google vuelve a pedir el consentimiento («Iniciar sesión en Yala» → «Continuar»
  abajo, con scroll).
