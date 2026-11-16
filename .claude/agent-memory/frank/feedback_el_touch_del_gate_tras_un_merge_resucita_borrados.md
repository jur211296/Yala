---
name: el-touch-del-gate-tras-un-merge-resucita-borrados
description: En un merge, sacar el alcance del gate con `git diff --cached --name-only` incluye lo que la base BORRÓ; el `touch` lo recrea vacío y tumba un source-scan.
metadata:
  type: feedback
---

El alcance del `touch` del gate sale de `git status --porcelain | grep -v '^D '`, con el filtro de borrados. El 15-nov, en el
merge de 2.3 sobre la rama de «Cambiar de cuenta», lo saqué con `git diff --cached --name-only HEAD` (506 ficheros) y el
`touch` recreó vacío `TransactionAmountInputView.swift`, que 2.3 había borrado. Los builds pasaron igual; cayó
`FullModeActivationWiringTests` («una sola puerta», `!text.isEmpty`) en la suite completa, 7 min después.

**Why:** un fichero vacío compila, así que el build no lo delata; solo lo ve un escáner que lee el árbol.

**How to apply:** tras un merge, usa el comando del gate tal cual, o `--diff-filter=d`. Si cae un source-scan por un fichero
vacío, mira `git status --porcelain | grep '^??'` antes de culpar al merge. Relacionado: [[gate-globs-ancho-subconjunto]].
