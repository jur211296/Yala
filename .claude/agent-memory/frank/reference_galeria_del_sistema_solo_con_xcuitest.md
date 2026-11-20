---
name: reference-galeria-del-sistema-solo-con-xcuitest
description: La galería de PhotosPicker no se conduce con axe ni con XcodeBuildMCP; con XCUITest sí, por coordenadas. Y simctl recordVideo puede quedarse «ocupado»: graba con record_sim_video.
metadata:
  type: reference
---

Medido el 2026-11-20 (logo propio de pagos planificados, iPhone 17 Pro, iOS 27.2, en la Mini).

- **La galería de `PhotosPicker` corre en otro proceso**: sus fotos no salen en `snapshot_ui` ni en el árbol de la app
  que ve XCUITest (un predicado por `label BEGINSWITH 'foto'` casó con otra imagen y no eligió nada).
- **`axe tap` no elige foto** y un `axe touch --down/--up` la deja en la vista previa (pulsación larga) sin salida.
  Device MCP no sirve si está espejando el iPad de Jürgen (la versión Free espeja uno).
- **XCUITest sí**: `app.coordinate(withNormalizedOffset: CGVector(dx: 0.17, dy: 0.42)).tap()` cae en una foto con el
  aviso de «Acceso privado» arriba y sin él; reintentar hasta ver el efecto en la app. Molde:
  `YalaUITests/Flows/PagoLogoPropioUITests.pickAPhoto`. Una foto propia entra con `xcrun simctl addmedia <udid> f.jpg`
  (se pone la primera); `magick` en la Mini no rasteriza SVG (falta `gs`): `qlmanage -t` sí, y `magick` recorta el PNG.
- **`simctl io recordVideo` matado con SIGTERM deja el simulador en «A recording is already in progress»** y la grabación
  siguiente no arranca. `record_sim_video` de XcodeBuildMCP (start/stop con `outputFile`) graba igual; con el XCUITest en
  `test-without-building` el vídeo sale sin el tramo de compilación.

Relacionado: [[reference-video-de-un-xcuitest-en-verde]].
