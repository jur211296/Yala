---
name: auto-merge-en-2-2-no-espera-al-ci
description: `gh pr merge --auto` contra la base 2.2 fusiona en el acto: 2.2 no exige checks, así que «esperar CI verde» se vigila a mano
metadata:
  type: feedback
---

El 2026-10-14, `gh pr merge 493 --auto --merge` devolvió `MERGED` al instante con el CI del último commit aún corriendo:
el ruleset que exige `tests` y `coverage-index` es el de `2.1`, no el de `2.2`.

**Why:** el encargo pedía «esperar CI verde y fusionar»; el auto-merge lo fusionó antes de que el CI dijera nada.

**How to apply:** en un PR contra `2.2`, si el encargo pide CI verde antes del merge, espera al run
(`gh run view <id>`) y fusiona después; si ya entró, vigila el run hasta el final y dilo en el cierre.
