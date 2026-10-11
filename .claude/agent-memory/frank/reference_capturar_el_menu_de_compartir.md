---
name: capturar-el-menu-de-compartir
description: Cómo se saca la captura del menú de compartir real de iOS (Fotos → Compartir) en el simulador para un antes/después de la extensión YalaShare.
metadata:
  type: reference
---

El menú de compartir de Fotos no se conduce con `tap` de XcodeBuildMCP: las celdas de foto no salen como objetivos.
Lo que funcionó el 2026-10-11:

- Fotos con `xcrun simctl addmedia <udid> <png…>` (los recibos de `Assets.xcassets/ExampleImages` sirven).
- `axe tap -x <pt> -y <pt> --udid <udid>` (CLI en `/opt/homebrew/bin/axe`) en PUNTOS, no en píxeles de la captura:
  la captura de `axe screenshot` viene a 3× (1206 px de ancho en el iPhone 17 Pro = 402 pt).
- Seleccionar → tocar fotos → botón compartir abajo a la izquierda (~52, 820 pt). Con la hoja abierta, los círculos de
  selección del carrusel cambian cuántas van.
- Para ver qué escribió la extensión: `xcrun simctl get_app_container <udid> <bundle> groups` y vigilar
  `PendingImages/` en bucle mientras se toca la app en el menú (la app los consume en segundos).

**How to apply:** cualquier encargo que toque `YalaShare` y pida antes/después. Ver [[el-antes-sale-del-build-del-rojo]].
