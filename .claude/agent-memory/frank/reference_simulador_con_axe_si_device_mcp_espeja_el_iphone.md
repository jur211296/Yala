---
name: simulador-con-axe-si-device-mcp-espeja-el-iphone
description: Con Device MCP gratis espejando el iPhone 14, el simulador se conduce con axe (toques por coordenadas) y simctl io screenshot; las hojas no salen en el árbol de axe.
metadata:
  type: reference
---

Medido el 2026-11-14 en la Max: `take_screenshot` con el UDID del simulador falla con «Device MCP Free mirrors one device
at a time» mientras espeja el iPhone 14. Sin pedirle a Jürgen que cambie el espejo:

- Captura: `xcrun simctl io <udid> screenshot <png>` (a 3×; `magick … -resize 33%` da puntos para leerla).
- Toques: `axe tap -x <pt> -y <pt> --udid <udid>`, con las coordenadas sacadas de la captura reducida. Dentro de una hoja
  (Ajustes) `axe describe-ui` no ve nada, pero los toques sí llegan.
- `axe swipe` largo sobre una lista puede acabar en toque (abrió Tutoriales): arrastres más cortos y comprobar con captura.
- El «antes» de una pantalla tocada: copia el fichero, `git show HEAD:<ruta> > <ruta>`, compila incremental, captura y
  restaura. Relacionado: [[antes-del-iphone-con-git-archive]].
