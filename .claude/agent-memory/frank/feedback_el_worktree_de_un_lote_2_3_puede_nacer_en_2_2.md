---
name: el-worktree-de-un-lote-2-3-puede-nacer-en-2-2
description: un encargo con «Base: origin/2.3» aterrizó en un worktree cuya rama apuntaba a origin/2.2; se comprueba y se reapunta antes de tocar nada
metadata:
  type: feedback
---

El 10-nov (lote 05 de las necesarias 2.3) `lanzar-sesion` dejó la rama `encargo/…` sobre `origin/2.2`
(`git rev-list --count origin/2.3..HEAD` = 13, `HEAD..origin/2.3` = 221) aunque el encargo decía «Base: origin/2.3».
Se reapuntó con `git reset --keep origin/2.3` (el `--hard` lo bloquea el permiso de la sesión).

**Why:** la rama nace de la rama por defecto del remoto (ADR-017 de casa) y en Yala hoy es `2.2`; el encargo nombra su
base en texto y nadie la aplica. Trabajar encima habría metido 2.2 en el PR a 2.3 o al revés.

**How to apply:** en todo encargo de 2.3, antes del primer cambio, mira `git log --oneline -1` contra la `Base:` del
encargo y, si no casa, `git reset --keep origin/<base>` y apúntalo en el Paso 0. Relacionado: [[bug-de-otra-rama-va-en-su-pr]].
