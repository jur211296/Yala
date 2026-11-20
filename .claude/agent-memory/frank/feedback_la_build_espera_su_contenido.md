---
name: la-build-espera-su-contenido
description: Subida a TestFlight con PRs que la deben llevar: si el plazo del encargo vence por la cola del CI (no por un rojo), se espera el contenido, no se corta
metadata:
  type: feedback
---

**Si una build debe llevar un PR y ese PR solo está atascado en la cola del CI, se espera a que entre; no se corta por el plazo del encargo ni se sube sin él.**

**Why:** 2026-11-19, build 5 de 2.3. El PR del contraste del modo claro tardó 3 h en cola (sin rojo). El encargo decía «30 min y BLOQUEANTE»; el bot, en nombre de Jürgen, eligió seguir esperando con la sesión viva (tope 18:30 Lima, revisión cada 10 min) porque él pidió la build CON el contraste.

**How to apply:** pasado el plazo, distingue cola de fallo (`gh run list --status queued`). Si es cola, pregunta con la opción «esperar» como recomendada y adelanta lo que no depende del CI: subir el número de build, archivar, dSYM y gate. Sube solo con el CI de la base en verde. Relacionado: [[upload-ok-no-es-build-aceptado]].
