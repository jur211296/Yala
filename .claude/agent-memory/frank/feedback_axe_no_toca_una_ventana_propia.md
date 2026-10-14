---
name: axe-no-toca-una-ventana-propia
description: Un aviso en una UIWindow aparte (DraftDiscardUndoNotice) se ve con `axe describe-ui` pero `axe tap/touch` no le llega; XCUITest sí lo toca
metadata:
  type: feedback
---

`axe tap` y `axe touch` no alcanzan un botón que vive en una `UIWindow` propia de la escena (el aviso «Lo moviste a
Archivados · Deshacer», 2026-10-14): `axe describe-ui` lo lista con su marco y el toque no lo acciona, tres intentos.
`snapshot_ui` de XcodeBuildMCP ni lo ve. El XCUITest (`app.buttons[id].tap()`) sí lo acciona y el borrador vuelve.

**Why:** perdí tres relanzamientos culpando al botón; con el aviso a 5 s, el temporizador lo retiraba y parecía que
«Deshacer» se había comido el toque sin hacer nada.

**How to apply:** si un control vive en una ventana aparte, el veredicto lo da un XCUITest, no `axe`; y el guion de
device-QA pide tocarlo con el dedo. Relacionado: [[capturar-el-menu-de-compartir]], [[el-tap-de-xcodebuildmcp-se-pierde-en-pantallas-vivas]].
