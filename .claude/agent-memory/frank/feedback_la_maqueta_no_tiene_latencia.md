---
name: la-maqueta-no-tiene-latencia
description: El servidor de maqueta de Yala web responde al instante; lo que llega por una segunda llamada (resúmenes, sugeridas) solo se ve saltar en producción, en el iPhone.
metadata:
  type: feedback
---

En Yala web, una cifra que llega por su propia llamada después de la lista la empuja hacia abajo, y el recorrido
contra `servidor-maqueta.mjs` no lo ve: responde en milisegundos. En el lote 4 (16-nov) «Te queda» de Registros llegó
1,4 s tarde en producción y movió la lista; se arregló con un esqueleto que reserva su hueco.

**Why:** la maqueta sirve para capturas y gestos, no para tiempos; el salto solo apareció al probar con sesión real.
**How to apply:** todo bloque que dependa de una llamada aparte lleva su hueco reservado desde el primer pintado, y la
prueba de punta a punta en producción se hace antes de dar el lote por cerrado, no como trámite. Las sugeridas de
Nuevo registro tienen el mismo patrón (aparecen al llegar `/api/categorias`), menos visible porque van abajo.
Relacionado: [[probar-un-artifact-en-el-iphone-14]].
