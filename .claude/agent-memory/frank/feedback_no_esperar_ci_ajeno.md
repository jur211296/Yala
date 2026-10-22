---
name: no-esperar-ci-ajeno
description: No esperar al CI de un PR anterior (aunque el encargo lo diga): seguir sobre lo que hay y rebasar una vez antes de abrir el PR propio
metadata:
  type: feedback
---

No se espera al CI de ningún PR ajeno, ni siquiera «justo antes del gate». Se trabaja sobre el `origin/2.1` que haya,
y solo antes de abrir el PR propio: `git fetch && git rebase origin/2.1`; si el rebase toca lo mío, recompilar y
repetir una vez los tests afectados.

**Why:** 2026-10-16, barrido de QA 2.1 (2): me puse a esperar el CI del #527 porque la línea GATE del encargo lo pedía;
Jürgen corrigió dos veces («¿no es que ya no esperamos a que entren los CI?») y dijo que esa línea estaba
desactualizada. Esperar ~25 min dejaba la sesión parada para nada.

**How to apply:** si un encargo trae «espera a que entre el PR anterior», trátalo como obsoleto y sigue. Lo que dependa
del PR ajeno (capturas, pruebas) se saca de su propia evidencia.
