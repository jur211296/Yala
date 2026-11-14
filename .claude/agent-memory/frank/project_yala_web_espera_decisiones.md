---
name: yala-web-espera-decisiones
description: Yala web: lotes 0 y 1 (beta) en staging desde el 14-nov; las 13 decisiones van con la recomendada (la db del artifact sigue vacía); lotes 2 y 3 también en 2.3 por decisión del 14-nov; device-QA de la beta pendiente.
metadata:
  type: project
---

Plan y decisiones en el artifact https://claude.ai/artifact/JN7jw8J1UXBQGNNpLNErAe y en `docs/web-app/index.html`. La
colección `decisiones` de su db seguía VACÍA el 14-nov (medido con `ArtifactData list`): vale la recomendada en las 13.
El 14-nov Jürgen cambió D10: los lotes 2 y 3 se hacen ya en 2.3 (`docs/DECISIONS.md`, lote del 14-nov).

Estado al 14-nov: lote 0 (entrar y sesión) y lote 1 (Panel, Registros, Bandeja, Apuntar, sesiones y «Navegadores
conectados» en el iPhone) desplegados en staging; producción, nada. El device-QA de la beta en el iPhone 14 espera la
mano de Jürgen: entrar con Apple en Yala Dev y en la web (Face ID). Guion en `tickets/done/yala-web-lote-1-beta.md`.

**Why:** la web reusa el núcleo de `shared-core` y la cola de borradores del gateway; cada lote lo aprueba él.

**How to apply:** al abrir el lote 2, lee la db del artifact por si contestó algo y parte del README de `webapp/`. Lo
que el lote 1 dejó fuera (origen «Yala web» propio en la Bandeja, cerrar sesión en el iPhone no cierra la web, la
política de privacidad) está en el README. Relacionado: [[secretos-de-staging-en-la-mini]],
[[propuestas-como-artifact-visual]].
