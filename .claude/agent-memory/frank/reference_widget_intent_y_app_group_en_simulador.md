---
name: widget-intent-y-app-group-en-simulador
description: Un botón de widget (Button(intent:)) no se dispara con toques sintéticos en el simulador, y `simctl spawn defaults write group.…` no escribe en el App Group de la app
metadata:
  type: reference
---

Medido el 2026-11-03 (barrido QA 2.2 C, iPhone 17 Pro, iOS 27.2, axe 1.8, «Ya lo pagué» del widget de Pagos):

- **El ✓ de un `Button(intent:)` en un widget de la pantalla de inicio no responde** a `axe tap`, `axe touch --down --up`
  ni `--tap-style physical`: el log de `YalaWidgetsExtension` no registra nada. El toque en el cuerpo del widget sí
  abre la app (sin `-uitest`: sale el Welcome y se reescribe la foto del widget). `snapshot_ui` ve el widget como un
  único botón, sin los de dentro.
- **Para probar la cadena sin el dedo**, mete la petición en la cola como la deja el intent: `simctl spawn … defaults
  write group.com.jurgenschmidt.yala.dev` escribe en las preferencias del USUARIO del simulador, no en el App Group (la
  app no ve nada). Lo que funciona: matar el `cfprefsd` del runtime y escribir con `plistlib` el plist de
  `…/data/Containers/Shared/AppGroup/<id>/Library/Preferences/group.com.jurgenschmidt.yala.dev.plist`
  (el id sale de `simctl get_app_container <U> <bundle> groups`). Ver [[forzar-preferencias-en-el-simulador]].
- **Bajo `-uitest` el arranque no drena las colas** (Apple Pay, Siri, widget): lo hace la vuelta a primer plano
  (`simctl launch` de otra app y después la de Yala). Los stores de `-uitest` (`*-UITest.store`) son otros que los
  de Yala Dev a secas (`*-Dev.store`): se leen con `sqlite3` para comprobar el registro.

**How to apply:** un barrido que pida probar una acción de widget en el simulador: añade el widget por galería
([[capturar-widgets-por-galeria]]), comprueba que se pinta el botón, y prueba el efecto con la cola escrita a mano; el
dedo sobre el botón, si importa, es lo único que queda para el iPhone.
