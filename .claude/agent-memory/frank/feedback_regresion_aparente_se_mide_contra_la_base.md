---
name: regresion-aparente-se-mide-contra-la-base
description: Si un cambio parece romper algo vecino (iPad, otra pestaña), se compila origin en un worktree aparte y se mide igual antes de arreglarlo o de culparse
metadata:
  type: feedback
---

Cuando un arreglo deja a la vista un fallo vecino que no buscaba —aquí, en el iPad, cambiar de chip en Planificación
con algo abierto dejaba el triángulo amarillo—, **antes de «arreglarlo» se mide la base**: `git worktree add --detach`
de `origin/<rama>` en el scratchpad, `Secrets.xcconfig` copiado, build con otro `-derivedDataPath`, y los mismos toques.
Si la base hace lo mismo, es previo: ticket propio y fuera del PR. Si no, es tuyo.

**Why:** 2026-10-14, lote 9. Mi primer «arreglo» (`.id(selectedTab)` en la pila) no cambiaba nada y lo daba por
bueno un test que yo mismo había añadido; la base de `origin/2.2` dio el mismo triángulo. Sin medirla, o metía un
cambio inútil o perseguía una regresión que no existía. Coste: ~15 min de build.

**How to apply:** útil sobre todo en iPad y en flujos vecinos al lote. Retira el worktree al acabar
(`git worktree remove --force`). Relacionado: [[el-antes-sale-del-build-del-rojo]].
