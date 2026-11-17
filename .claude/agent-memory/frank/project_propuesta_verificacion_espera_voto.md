---
name: propuesta-verificacion-espera-voto
description: 17-nov — la propuesta de verificación (6 cambios P1-P6) espera el voto de Jürgen en su artifact; leerlo antes de encolar nada de CI o gate
metadata:
  type: project
---

La comparación con el artículo de verificación del equipo de Claude Code dejó seis propuestas en
https://claude.ai/artifact/RTWfBUbDi4tbW1eKbEA81d (fuente en `docs/verificacion/`). Ninguna se
encola sin su voto: colección `votos`, docs `p1`…`p6`, campo `voto` (`si`/`no`/`despues`) y `nota`.

**Why:** el encargo del 16-nov era solo proponer; Jürgen decide una por una. Mi recomendación fue
P1 (rescates de la caché de divisas + cuarentena), P2 (interfaz de lo tocado en cada PR) y P3
(`Verificado:` en el commit) primero; P4 después; P5 mensual; P6 después.

**How to apply:** antes de tocar el gate, `ci-reintentar-rojos.sh`, el job `ui` o las reglas de
pruebas, `ArtifactData list` de `votos`. Si siguen vacíos, no adelantes ninguna: recuérdaselo.
Relacionado: [[gate-globs-ancho-subconjunto]], [[revision-independiente-antes-del-gate]].
