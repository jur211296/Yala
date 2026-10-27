---
name: el-sello-depende-del-staging-de-los-renombrados
description: Tras /gate, no partas el commit con git reset si hay tickets movidos: la huella cambia con el disco idéntico; todo el Swift en un commit y lo demás después
metadata:
  type: feedback
---

Tras sellar el gate, el Swift va en **un solo commit** con el índice tal como estaba al sellar; los commits de solo docs van después (el hook solo pide sello si hay `.swift` staged).

**Why:** 2026-10-26, PR #645. Partí el commit con `git reset -- tickets/` para separar tickets: `worktree-stamp.sh` usa `git diff HEAD --name-only`, que con rename detection lista solo el destino de un `git mv` staged y los dos lados si no. La huella cambió con el disco idéntico y el hook bloqueó. Volver a `git add` lo dejó como al sellar. Además el sello incluye HEAD: un segundo commit con Swift exigiría otro gate.

**How to apply:** decide el reparto de commits ANTES de `/gate`; si ya está sellado y bloquea, restaura el staging (no re-sellar a mano). Card de S10 sobre el sello: `tablero-el-sello-del-gate-se-invalida-al-hacer-g-uecc`.
