---
name: cierre-espera-el-merge-real
description: Desde el 19-nov, el auto-merge se deja en cola pero la sesión no cierra hasta ver su PR MERGED en 2.3; conflictos y CI rojo los arregla ella
metadata:
  type: feedback
---

Regla de Jürgen (2026-11-19, 12:55): deja `gh pr merge --auto --merge` activado, pero **no cierres hasta ver el PR
mergeado en 2.3** (`gh pr view <n> --json state` = `MERGED`). Si aparece un conflicto o el CI falla, haz el rebase o
el arreglo tú y vuelve a esperar. Si tras 45 min el CI sigue sin pasar por algo ajeno al PR, anótalo en el cierre con
el motivo y cierra.

**Why:** «en cola» no es «dentro»: un PR en cola puede quedarse colgado por un conflicto o un rojo que nadie retoma.

**How to apply:** sustituye el «el CI no se espera» del modo cola de `/cerrar-total` (ADR-054) y de
[[no-esperar-ci-ajeno]] para el cierre propio. Espera con Monitor o chequeos espaciados, nunca con sleeps largos.
