---
name: git-add-con-ruta-muerta-aborta-entero
description: Un `git add` con UNA ruta que ya no existe no añade NADA (3 veces, la última con git mv); añade por DIRECTORIO y encadena con &&
metadata:
  type: feedback
---

**`git add a b c` con una ruta que no existe aborta ENTERO** (`pathspec did not match`) y no añade ni `a` ni `b`. El
2026-09-25 metí en la lista la ruta vieja de un ticket que ya había movido con `git mv`, filtré la salida con
`grep -v "did not match"` —justo el error— y el commit `fix(migración)` salió con un solo rename de 0 líneas y el
mensaje del fix completo. Lo vi porque el `git status` del commit siguiente seguía listando el código.

**Why:** el hook de pre-commit sale 0 sin `.swift` en staging, así que nada protesta: un commit de «fix» sin código
pasa todos los candados.

**How to apply:** tras cada commit de código, `git show --stat HEAD | tail -1` y comprobar que lleva los ficheros que
dice el mensaje. No filtres los errores de `git add`; usa `set -e` o `&&`. Si ya pasó y no se subió:
`git reset --soft origin/<base>` + `git reset` y rehacer (el sello del gate ancla en HEAD, que vuelve a ser el mismo).
Relacionado: [[reference_gate_sello_ancla_en_head]].

**Reincidí el 2026-09-26 por otra puerta: un `git mv` hecho una hora antes.** Pasé la ruta VIEJA del ticket al `git add`,
que abortó entero; y el commit de docs de justo después se llevó el renombrado, que ya estaba en el índice por el
`git mv`. ⇒ **antes del `git add`, `git status --short`, y a `git add` solo rutas que salgan ahí.** El `git show --stat
HEAD` lo delató a tiempo.

**Tercera vez el 2026-09-26 (#272), con el mismo `git mv` y aun sabiéndolo.** La regla «mira `git status` antes» no
aguantó: escribí la lista a mano igual. ⇒ **no listes ficheros: añade por DIRECTORIO** (`git add -A -- Yala YalaTests
.claude/rules docs tickets qa`), que recoge renombrados y nuevos y no muere por un fichero movido; deja fuera solo lo que
no va (p.ej. `encargos/`). Y `&&` entre el `git add` y el `git commit`, siempre.
