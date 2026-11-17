---
name: web-parecida-a-la-app
description: Maqueta «Yala web como la app» (16-nov): aprobada entera a las 17:46; los 6 lotes construidos y en producción al 17-nov. Falta su prueba con sesión.
metadata:
  type: project
---

El 16-nov Jürgen dijo que Yala web «no se parece NADA» a la app y pidió maqueta antes de implementar. Quedó en
https://claude.ai/artifact/AJBG7EmuTbtiq8YzGbfkWa (pública), fuente en `docs/web-app/parecida-a-la-app/`.
Sus votos y notas van a la db del artifact: colecciones `comentarios` (doc por pantalla) y `decisiones` (doc por
decisión: tema, nav-escritorio, pestanas, voz-foto-ia, iconos, cifras, panel-widgets). Vacías al publicar.

**Why:** los lotes de implementación se encolan solo con su visto bueno; sin respuesta vale la recomendada (anotado en
docs/DECISIONS.md, 16-nov).

**How to apply:** antes de lanzar el lote 1, `ArtifactData list` de las dos colecciones y lee también lo que pegue en el
chat (la maqueta exporta un bloque de texto). Para el antes/después de cada lote, `herramientas/` de esa carpeta sirve la
web con datos inventados sin tocar producción. Relacionado: [[yala-web-espera-decisiones]], [[propuestas-como-artifact-visual]].

**Estado 17-nov:** los seis lotes hechos; el 6 (la entrada) desplegado en producción el 17-nov. Donde la maqueta y la app
de hoy difieren (fondo de la bienvenida, botón de Apple blanco), manda la app y se anota en «Decidido sin consultar».
