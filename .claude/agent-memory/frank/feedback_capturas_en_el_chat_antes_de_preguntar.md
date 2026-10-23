---
name: capturas-en-el-chat-antes-de-preguntar
description: Al pedirle a Jürgen una decisión que se apoya en capturas, mándaselas al chat (SendUserFile) o en un artifact ANTES de la pregunta; nunca solo la ruta.
metadata:
  type: feedback
---

Cuando una decisión trae capturas, se le envían a Jürgen en el chat (SendUserFile, con caption que diga a qué card van) o se montan en un artifact, **antes** de hacer la pregunta. Darle la ruta de la carpeta no sirve.

**Why:** 2026-10-18, sesión de preguntas de la auditoría UX 2.2: «no puedo ir a buscar una a una a la carpeta». Lee desde el móvil muchas veces y decide mirando.

**How to apply:** en cualquier ronda de decisiones (tablero «espera decisión», propuestas visuales, QA), primero las imágenes de las cards de esa tanda, luego AskUserQuestion. Relacionado: [[ui-compleja-capturas-antes-de-cerrar]].
