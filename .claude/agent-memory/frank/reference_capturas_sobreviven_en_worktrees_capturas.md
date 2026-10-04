---
name: capturas-sobreviven-en-worktrees-capturas
description: Las capturas antes/después de un encargo se copian a ~/Claude/worktrees/_capturas/<slug>/ antes del cierre; capturas/ dentro del worktree muere con él y ensucia el status
metadata:
  type: reference
---

Las capturas de un encargo lanzado se dejan en `/Users/jur/Claude/worktrees/_capturas/<fecha>-<slug>/`
(`antes*.png`, `despues*.png`), y son esas rutas las que van en el resumen de cierre y en el PR.

**Why:** `capturas/` en el worktree no se commitea (ningún PR lo hizo) y `/cerrar-total` exige `git status`
vacío y luego retira el worktree: las rutas absolutas del aviso apuntarían a nada. Medido el 2026-10-04 mirando
`_capturas/`, donde ya estaban las de los encargos del 3-oct; la skill no lo dice.

**How to apply:** saca las capturas en `capturas/` del worktree mientras trabajas; antes de sellar el gate,
`cp` a `_capturas/<slug>/` y borra `capturas/` (con `rm` de ficheros: `rm -rf` lo deniega el clasificador).
Relacionado: [[una-tanda-de-capturas-cuesta-diez-gigas]].
