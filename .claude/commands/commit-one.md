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

LIMPIEZA DE COMMITS WIP:
- Antes de inspeccionar cambios, revisa git log --oneline -10
- Si detectas commits con prefijo "wip:" que corresponden al trabajo actual, pregunta al usuario:
  "Detecté N commits wip: previos relacionados. ¿Quieres que los combine en este commit final?"
- Si el usuario confirma, ejecuta: git reset --soft HEAD~N (donde N es el número de commits wip)
- Luego procede normalmente con el análisis de diff y creación del commit atómico final

POST-COMMIT: ACTUALIZACIÓN AUTOMÁTICA DE STATE:
1. Después de crear el commit exitosamente, lee el archivo STATE.md actual
2. Localiza la sección "Recent Progress" (créala si no existe)
3. Agrega una nueva entrada con este formato:
   - [timestamp ISO] [commit-hash corto] [mensaje del commit]
   - Ejemplo: "2025-01-16T14:30 a3f8b2c feat: Add category filtering to transaction list"
4. Mantén solo las últimas 10 entradas en Recent Progress (borra las más antiguas)
5. Si el commit completa un item de la sección "Next Steps", muévelo a "Completed in Current Phase"
6. Informa al usuario: "STATE actualizado automáticamente con este commit"

FORMATO DE STATE.md ESPERADO:
```markdown
# Project State

## Recent Progress
- [timestamp] [hash] [mensaje]
...

## Completed in Current Phase
- [item completado]
...

## Next Steps
- [item pendiente]
...

## Parking Lot
- [ideas para después]
...
```
