---
name: yala-web-espera-decisiones
description: Yala web definida y maquetada el 2026-11-12; la construcción (lote 0 en adelante) espera las 13 decisiones de Jürgen en el artifact.
metadata:
  type: project
---

La definición de Yala web (seis lotes, 13 decisiones) está en el artifact https://claude.ai/artifact/JN7jw8J1UXBQGNNpLNErAe
y en `docs/web-app/index.html`. Las respuestas de Jürgen se guardan en la `db` del artifact, colección `decisiones`
(doc por id D1…D13, campo `opcion`); sin respuesta vale la recomendada.

**Why:** el encargo del 12-nov era solo definir; la construcción la aprueba él por lotes. El lote 0 necesita además sus
dos altas en consola (Services ID de Apple y cliente web de Google, card propia).

**How to apply:** antes de escribir el encargo del lote 0, leer la colección con `ArtifactData list` y partir de lo
elegido. Si una decisión sigue vacía, tomar la recomendada y decirlo. Relacionado: [[propuestas-como-artifact-visual]].
