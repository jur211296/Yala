---
name: dos-chrome-conectados-frena-el-artifact-publico
description: Con dos Chrome conectados a la cuenta, Claude in Chrome no actúa hasta que Jürgen elige uno; el paso a público de un artifact queda en privado y se anota.
metadata:
  type: reference
---

Medido el 2026-11-20 en la Mini (sesión de maquetas de cuenta automática): `tabs_context_mcp` contestó «Multiple Chrome
browsers are connected… none has been selected» con dos navegadores macOS, y exige preguntar a Jürgen cuál usar antes
de cualquier acción.

**How to apply:** el paso a público de un artifact es un intento (ADR-123 de casa). Si sale este aviso en una sesión
que no tiene a Jürgen delante, no se pregunta solo por eso: el artifact queda privado y el cierre lo dice en «Necesita
de ti» con el enlace. Relacionado: [[artifact-publico-lo-frena-el-clasificador]].
