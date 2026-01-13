---
description: Crear 1 commit atómico, pequeño y verificable
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git add:*), Bash(git commit:*), Bash(git log:*)
---

Objetivo: crear 1 commit pequeño y enfocado.

Contexto:
- Status: !`git status --porcelain`
- Diff: !`git diff`
- Últimos commits: !`git log --oneline -5`

Reglas:
1) Si el diff tiene más de un tema, divide. Haz solo el primer commit ahora.
2) Haz git add solo de lo necesario.
3) Commit message con prefijo: feat:, fix:, refactor:, chore:

Entrega:
- Comando(s) git add exactos que ejecutarás
- Mensaje de commit propuesto
- Luego ejecuta el commit
