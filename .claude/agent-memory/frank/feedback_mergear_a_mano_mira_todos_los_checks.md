---
name: mergear-a-mano-mira-todos-los-checks
description: Al mergear PR a mano (sin auto-merge), mirar TODOS los checks, no solo los que exige el ruleset; un webapp rojo se coló el 17-nov.
metadata:
  type: feedback
---

Al mergear a mano, antes de `gh pr merge` lista los checks en rojo de verdad (`gh pr checks <n> --json name,bucket` y filtra `fail`), no solo `tests`/`coverage-index`/`gateway`, que son los que exige el ruleset de 2.3.

**Why:** 17-nov, sesión «Dejar 2.3 perfecta»: miré solo `tests` y mergeé los filtros rápidos con `webapp` en rojo (un intermitente de «eyJ» en base64). GitHub no lo frena porque no es requerido; Jürgen pidió 2.3 con todo el CI en verde.

**How to apply:** en sesiones sin auto-merge (las de «dejar 2.3 en verde»), el filtro `fail` va ANTES del merge, y un rojo no requerido se arregla o se explica en el cierre. Ver [[merge-corto-que-falta-lo-hace-la-sesion]].
