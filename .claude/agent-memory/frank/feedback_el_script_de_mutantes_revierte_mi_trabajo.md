---
name: el-script-de-mutantes-revierte-mi-trabajo
description: Un runner de mutantes que restaura con `git checkout --` borra el cambio sin commitear que está midiendo; el 22-sep perdí el fix entero en la primera vuelta. Se restaura desde una COPIA del scratchpad.
metadata:
  type: feedback
---

**El runner de una tanda de mutantes restaura desde una COPIA del scratchpad, nunca con
`git checkout -- <fichero>`.**

**Why:** el 2026-09-22 escribí el bucle con `git checkout --` al principio de cada vuelta —para dejar
el árbol limpio antes de aplicar el mutante siguiente— y **la primera vuelta se llevó el fix entero**,
que todavía no estaba commiteado. `git checkout --` restaura desde el índice, y si el fichero no está
en el índice, desde HEAD: o sea, el trabajo de la sesión. Tuve que rehacer la edición completa.

Ya tenía escrita [[revertir-sin-commit-destruye]] y reincidí, porque ahí el gesto era manual y aquí
iba **dentro de un script**: el bucle lo repite sin que nadie lo lea otra vez.

**How to apply:**

- Antes de la tanda: `cp <ficheros> $SCRATCHPAD/limpio/`. El runner restaura con `cp` desde ahí, al
  empezar cada vuelta **y al terminar la tanda**.
- Si prefieres git, `git add -A` antes de empezar: entonces `git checkout --` restaura desde el
  índice, que ya es tu versión. Pero la copia es más barata de leer y no depende de que el `add` esté
  puesto.
- **El runner imprime el conteo de fallos por mutante y los nombres**, y los nombres se sacan con
  `grep -o '✘ Test "[^"]*"'` — con el patrón sin comillas salen truncados a `✘ Test` y no dicen nada.
- Y mide el **control positivo** al final: el árbol restaurado tiene que volver a dar verde. Si no,
  la tanda te dejó un mutante puesto.
