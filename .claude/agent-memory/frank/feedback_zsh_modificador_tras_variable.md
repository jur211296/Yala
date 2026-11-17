---
name: zsh-modificador-tras-variable
description: En zsh, `$REF:qa/…` aplica el modificador `:q` a la variable y rompe `git show $REF:ruta`; usa `"${REF}:ruta"`
metadata:
  type: feedback
---

`git show $B:qa/checklist.yaml` con `B=origin/rama` falló el 2026-11-17 con «ambiguous argument
'origin/ramaa/checklist.yaml'»: zsh leyó `:q` como modificador de `$B` (y `:h`, `:t`, `:r`, `:e`, `:a` hacen lo mismo).

**Why:** el shell de Bash en estas sesiones es zsh; en bash el mismo texto funciona, así que no se ve venir.

**How to apply:** con una ruta pegada a una variable tras `:`, escribe siempre `"${B}:ruta"`. Ver también
[[feedback_zsh_no_divide_variables]].
