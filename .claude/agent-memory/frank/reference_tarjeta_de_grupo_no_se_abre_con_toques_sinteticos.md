---
name: tarjeta-de-grupo-no-se-abre-con-toques-sinteticos
description: En la lista de Grupos, axe y el tap de XcodeBuildMCP no abren la tarjeta (se pierde o abre el menú contextual); para recorrer Grupos con capturas, XCUITest
metadata:
  type: reference
---

En la lista de Grupos, la tarjeta (`group_card`, con `.contextMenu`) **no se abre con toques sintéticos**: el `tap` de
XcodeBuildMCP y `axe tap` se pierden, y un `touch` de 0,05-0,1 s la lee como pulsación larga y abre «Abrir grupo · Nuevo
gasto». Desde ahí, «Abrir grupo» sí entra con el `touch` de XcodeBuildMCP (el menú vive en otra ventana: `axe` no lo
alcanza). Los diálogos de confirmación se cierran tocando fuera solo con `axe touch` (0,1 s), no con `axe tap`.

**Why:** el 2026-10-16 (lote 19) perdí una docena de vueltas abriendo grupos a mano antes de pasar a un XCUITest local
(`card.tap()` sí abre), que además recorrió nueve estados con semillas distintas en tres minutos.

**How to apply:** para auditar Grupos en el simulador, escribe primero el conductor XCUITest local (molde
[[maqueta-de-variantes-por-xcuitest]]) y deja la mano para mirar una pantalla suelta. Relacionado:
[[el-tap-de-xcodebuildmcp-se-pierde-en-pantallas-vivas]], [[axe-no-toca-una-ventana-propia]].
