---
name: deriveddata-fuera-del-worktree
description: Un -derivedDataPath dentro del worktree mete ~26.000 ficheros en el sello del gate (worktree-stamp hashea lo no versionado) y lo cuelga; el info/exclude del worktree no lo arregla.
metadata:
  type: feedback
---

El DerivedData de una sesión va FUERA del worktree (`~/Library/Developer/Xcode/DerivedData/<nombre>`), nunca en `./.dd`.

**Why:** el 24-nov puse `-derivedDataPath $PWD/.dd`; `verificado-en-commit.sh sellar` llama a `worktree-stamp.sh`, que
hace `shasum` de cada fichero sin trackear (`git ls-files --others --exclude-standard`): con 26.000 ficheros pasó de 2 min
sin terminar. Y el script de interfaz contaba «26.304 ficheros tocados». Añadir `.dd/` a `$(git rev-parse --git-dir)/info/exclude`
NO sirve en un worktree: git lee el `info/exclude` del directorio COMÚN, no el de `.git/worktrees/<x>/`.

**How to apply:** al compilar en un worktree, `-derivedDataPath` a una ruta fuera del árbol. Si ya está dentro, `mv` fuera y
resella (0,4 s). Relacionado: [[gate-en-disco-local-no-extdev]].
