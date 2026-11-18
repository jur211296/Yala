---
name: reference-captura-girada-por-xcuitest
description: En horizontal, app.screenshot() de XCUITest sale con media pantalla en negro; XCUIScreen.main.screenshot() sale bien pero el PNG lleva orientación EXIF y hay que pasarlo por magick -auto-orient.
metadata:
  type: reference
---

Medido el 2026-11-17 (iPhone 17 Pro, iOS 27.2, encargo registros-estadisticas-identica): con
`XCUIDevice.shared.orientation = .landscapeLeft`, `app.screenshot().pngRepresentation` dio una imagen con la mitad en
negro y el contenido cortado. `XCUIScreen.main.screenshot()` captura la pantalla entera bien, pero el PNG se guarda en el
búfer vertical (1206×2622) con orientación EXIF `LeftBottom`: los visores que la respetan la enseñan bien y `magick`
no. Rotarla a mano lió tres vueltas; lo que funciona es `magick f.png -auto-orient f.png` (queda 2622×1206, `TopLeft`).

**How to apply:** conductor de capturas en horizontal → `XCUIScreen.main.screenshot()` + `-auto-orient` antes de
montar la evidencia. Molde: `YalaUITests/RegistrosEstadisticasIguales/RegistrosEstadisticasCapturasUITests`. Relacionado:
[[reference-maqueta-de-variantes-por-xcuitest]].
