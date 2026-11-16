---
id: gate-stamp-changes-when-a-staged-rename-hides-the-old-path
status: backlog
priority: low
area: qa, git-hooks
created: 2026-10-25
updated: 2026-10-25
source: lote 12.4 (el commit tras un /gate verde salió BLOCKED sin cambiar ningún fichero)
---

# El sello del gate cambia al hacer `git add` si hay un fichero movido

`qa/scripts/worktree-stamp.sh` lista los ficheros con `git diff HEAD --name-only`. Con un fichero MOVIDO (aquí, nueve
tickets de `backlog/` a `done/`), antes del `git add` git ve un borrado y un fichero sin trackear y lista los dos; después
del `git add` lo detecta como RENOMBRE y `--name-only` solo lista el destino. La ruta vieja deja de entrar en la huella
como «ausente», la huella cambia y el `pre-commit` bloquea con «el codigo cambio desde que paso /gate» aunque no haya
cambiado ningún fichero (medido el 2026-10-25: ningún fichero posterior al sello). Contradice la promesa del `/gate`:
«`git add` no invalida el sello».

## Qué hacer

`git diff HEAD --name-only --no-renames` en el script (medido: con él la ruta vieja sigue saliendo), y un caso en
`qa/scripts/worktree-stamp-test.sh` con un `git mv`.
