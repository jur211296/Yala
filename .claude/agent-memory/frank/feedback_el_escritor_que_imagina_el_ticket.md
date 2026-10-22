---
name: el-escritor-que-imagina-el-ticket
description: El ticket imaginaba al líder escribiendo a diario sin marcador; medido, eso no existe. El escritor real era un adoptador, y eso cambió la solución entera.
metadata:
  type: feedback
---

Antes de diseñar la señal que desbloquea un caso, mide **quién** produce el estado del ticket en el camino real.

**Why:** en #247 el ticket decía «mi iPhone ya usa la nube a diario» y pedía otra señal para el corte global.
El paso 4 del líder no apaga el espejo sin exportar el marcador, así que un líder que escribe a diario siempre
dejó marcador. El caso solo existía con un ADOPTADOR como escritor, en una cuenta cuyo líder nunca exportó. Con
eso la salida dejó de ser una señal nueva, que era frágil, y pasó a ser que el adoptador releve el marcador. Tres
alternativas descartadas (HLC, registro en servidor, mover el corte) salían de la premisa sin medir.

**How to apply:** en un ticket del tipo «X queda bloqueado mientras Y hace Z», enumera los caminos de código que
producen Y+Z y descarta los que una puerta ya impide. Enlaza con [[la-premisa-del-encargo-tambien-se-mide]].
