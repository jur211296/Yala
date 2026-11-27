---
name: astro-check-se-cuelga-usa-build
description: En Web/, `npx astro check` se queda colgado sin CPU (espera instalar @astrojs/check); para validar una página, `npx astro build`
metadata:
  type: reference
---

`npx astro check` en `Web/` no termina: se queda esperando una respuesta interactiva (instalar `@astrojs/check`) con 0 % de
CPU, y en una sesión en segundo plano nadie la contesta. Medido el 2026-11-26 (lote 3 de Compartido, `invite.astro`): 5 min
colgado. `npx astro build` compila la página entera en ~2 s y sí falla si el `.astro` no parsea.

**How to apply:** para validar un cambio en `Web/src/pages/*.astro`, `cd Web && npx astro build | grep -iE "error|Complete"`.
Mata cualquier `astro check` que veas parado.
