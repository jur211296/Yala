---
name: grabaciones-del-iphone-14-llevan-notificaciones
description: Los vídeos y capturas del iPhone 14 por Device MCP recogen notificaciones personales de WhatsApp de Jürgen; no van a entregas sin revisarlas
metadata:
  type: feedback
---

El iPhone 14 de pruebas es también un teléfono con WhatsApp de Jürgen: medido el 2026-11-13, una grabación de 10 min con
Device MCP recogió tres notificaciones con nombres de contactos y de grupos de clientes, y una captura de Grupos salió
con una encima.

**Why:** lo que se deja en `~/Claude/entregas/<sesión>/evidencia/` lo sube `publicar_cierre.py` al hilo de Slack. Un
vídeo con notificaciones de clientes ahí es una filtración de datos ajenos, y nadie lo revisa fotograma a fotograma.

**How to apply:**
- Antes de guardar una captura, mira que no haya un banner arriba; si lo hay, recórtalo (`magick … -crop`) o repítela.
- Los vídeos del iPhone 14 se quedan en el scratchpad y no se entregan, salvo que se revisen enteros. En el cierre se dice
  dónde están y por qué no van.
- Relacionado: [[conducir-el-iphone-real-con-device-mcp]], [[el-iphone-de-pruebas-es-el-14-por-cable]].
