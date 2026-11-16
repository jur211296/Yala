---
name: feedback-la-memoria-no-se-mueve-a-mano-al-principal
description: En un worktree, la nota de memoria se escribe donde la declara Claude Code (el worktree) y viaja en el PR con scripts/memoria_al_pr.py; no se copia a mano a ~/Yala
metadata:
  type: feedback
---

La nota se queda en el worktree. Al cerrar, `python3 scripts/memoria_al_pr.py llevar` la commitea en el PR y, tras el push, `limpiar` deja limpio el principal. Moverla a mano a `~/Yala` es lo que ensuciaba el checkout principal.

**Why:** el 9-nov-2026 Jürgen eligió la opción (a) del ADR-095 de casa: la memoria viaja con el PR de la sesión que la escribió. Medido ese día en ~100 transcripts: Claude Code declara la memoria en el worktree, y las notas sueltas del principal las habían movido sesiones a mano (`cp … /Users/jur/Yala/$F` + `printf >> …/MEMORY.md`). Esas notas frenaron el `git pull --ff-only` de `lanzar-sesion` el 6 y el 9 de noviembre.

**How to apply:** escribe la nota y su línea de `MEMORY.md` en el worktree. Si una nota tuya ya está en el principal, no la toques a mano: el paso la atribuye por tu transcript y la lleva. Lo que marque «en duda» se queda donde está y va al cuerpo del PR. Relacionada: [[feedback-push-solo-lo-de-la-sesion]].
