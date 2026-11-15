---
name: conducir-el-iphone-real-con-device-mcp
description: Cómo conducir y grabar el iPhone 14 de pruebas desde la Max con Device MCP, y qué no hace (teclado, open_url, PasteButton, Google, bloqueo, Atajos).
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

Medido el 2026-11-14 (prueba B0 del atajo del banco):

- **El iPhone 14 se bloquea solo a los pocos minutos y tiene código**: desbloquearlo es de Jürgen
  (`request_human_action` + `preguntar-bot`). Deja la prueba «con el iPhone bloqueado» para el final, después de todo lo
  que pida el teléfono desbloqueado; si no, la sesión se queda esperando su mano a mitad.
- **`tap_text` cae por OCR en lo que haya debajo si el diálogo ya se fue**: buscando «OK» de un `Mostrar contenido` tocó
  el icono de Grok Bot (chats personales) en el dock. Para un botón de un diálogo, `tap` por coordenadas tras la captura.
- **Atajos se conduce bien con Device MCP**: buscador de acciones, «Seleccionar variable», renombrar. Para leer qué
  recibe una automatización, añade «Copiar en el portapapeles» y lee con `get_clipboard` (sobrevive al bloqueo).
- **Una acción de Atajos solo DEBUG en Yala Dev** que programa una notificación local con retardo sirve para simular
  avisos de otras apps («Al recibir una notificación de Yala Dev»): el molde es `BankNoticeTestEmitIntent`.

Medido el 2026-11-14 (pagos recurrentes S1):

- **Un toque justo después de abrir una hoja se pierde**: el interruptor de la hoja de ajustes no cambió y parecía un
  bug de la app. Con la hoja ya quieta (una captura antes), el mismo toque funcionó. Tras abrir una hoja, captura o
  `wait_for` antes de tocar dentro, y comprueba el estado después.
- **Para un «antes» y «después» con los mismos datos**: instala la build de la base (git archive), siembra con
  `-uitest -uitest-reset -uitest-skip-onboarding -uitest-seed realista`, prepara el estado, captura, e instala encima la
  build nueva con `devicectl device install app` (conserva los datos) y lanza sin `-uitest-reset`.
