---
name: safari-del-iphone-14-sin-open-url
description: Device MCP open_url pide aprobación en pantalla (se cuelga 2 min sin nadie); y el teclado español rompe URLs tecleadas. Navegar la web staging en el iPhone 14 sin ellos.
metadata:
  type: reference
---

Medido el 2026-11-15 (Max, iPhone 14 por cable). `open_url` quedó esperando una aprobación de Device MCP que nadie contestó
y falló a los 2 min. Teclear la URL en la barra de Safari con `type_text` salió con `'` en vez de `-` y sin `/`: el
teclado activo era el español.

**How to apply:** `launch_app com.apple.mobilesafari` abre la última pestaña de la web staging (si hay sesión) y se navega
por la propia web (Más › …) o con el botón de recargar (≈(277,785)). Una pestaña que quedó ampliada por el zoom de Safari
se devuelve a su tamaño con `pinch` scale 0.4 en el centro. Relacionado: [[conducir-el-iphone-real-con-device-mcp]].
