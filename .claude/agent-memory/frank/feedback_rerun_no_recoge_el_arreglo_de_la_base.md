---
name: rerun-no-recoge-el-arreglo-de-la-base
description: gh run rerun de un PR reusa su commit de merge original; un arreglo de CI mergeado en la base después no le llega
metadata:
  type: feedback
---

Un `gh run rerun --failed` sobre un `pull_request` corre el MISMO `refs/pull/N/merge` del evento
original. Si el arreglo del CI entró en la base después, el rerun usa el script viejo y cae igual.

**Why:** 2026-10-23, encargo del simulador iOS 27.1 (PR #603). El encargo pedía relanzar los checks
de #602/#601/#576/#571 tras el merge; los cuatro volvieron a dar el mismo 403. El log lo dice:
`HEAD is now at … Merge <head> into 7b783537` (base anterior al arreglo).

**How to apply:** cuando un encargo diga «arregla el CI y relanza los de la cola», avisa en el
Paso 0 de que el rerun no basta: hace falta un evento nuevo (`gh pr update-branch <n>`), y eso es
tocar PR ajenos — se deja a Jürgen salvo que el encargo lo autorice. Ver [[no-esperar-ci-ajeno]].
