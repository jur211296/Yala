---
name: feedback_el_sello_cubre_el_encargo
description: El sello de /gate es la huella de TODO el árbol, markdown sin trackear incluido: el Paso 0 del encargo se escribe antes de sellar.
metadata:
  type: feedback
---

`worktree-stamp.sh` hashea todo lo que difiere de HEAD, incluidos los ficheros sin trackear. Añadir el cierre del
Paso 0 al encargo (`encargos/lanzados/*.md`, sin trackear) después de `/gate` hizo que el hook de commit
bloqueara por «el código cambió». Y un heredoc SIN comillas (`<<EOF`) con nombres entre comillas invertidas los
ejecuta como comandos: vació media sección del ticket.

**Why:** 2026-09-22, dos tropiezos seguidos en el cierre de `apply-overwrites-…`.

**How to apply:** orden de cierre: Paso 0 y notas → `/gate` → commit de código → docs. Todo heredoc con markdown
va con `<<'EOF'`.
