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

**Dos más del 2026-09-23, del mismo runner:**
- Si entre tandas cambias un fichero de producción, **refresca la copia pristine** antes de la segunda tanda: el runner
  restaura desde ella y se llevaría el cambio nuevo igual que `git checkout --`.
- Un `xcodebuild test` puede **no salir** después de imprimir `Test run with … failed` (6 min colgado en un mutante).
  El veredicto ya está en su log: mátalo por su PID y el runner sigue. Mejor aún, dale un techo en el propio runner.

**2026-09-25: lánzalo con `nohup … & disown`, no como tarea en segundo plano del harness.** Esas tareas
tienen tope de 10 min; la tanda dura más, y al pararla con `TaskStop` el `finally` no corrió: quedó un
mutante puesto en `CloudSyncRuntime.swift`. Lo cazó el `cmp` contra la copia. Y un ancla que aparece
más de una vez sale `NO APLICA`: dos de siete la primera vez. Ancla con la línea de contexto vecina.

**2026-09-27: el ancla ÚNICA al aplicar no lo es al REVERTIR.** Un mutante que BORRA una línea (`a` = línea + `}`,
`b` = `}`) comprueba que `a` es única al aplicar, pero revertir busca `b`, y `        }` aparece cien veces: el
`replace(b, a, 1)` metió la línea en la primera llave del fichero y el mutante siguiente salió `BUILD FAIL`. Lo cazó el
`diff` contra la copia. ⇒ el mutante que borra deja un **marcador** en su lugar (`// MUTANTE-Mn`) y se revierte por él,
o se restaura siempre desde la copia en vez de invertir el reemplazo.

**2026-09-27 (noche): reincidí DOS veces en la misma sesión con la regla de arriba escrita.** Lancé la tanda como tarea
del harness, la paré con `TaskStop` al cambiar el diseño y dejó un mutante puesto; la relancé igual y volvió a pasar. La
regla estaba aquí y no la leí antes de lanzar. ⇒ **antes de escribir el runner, abre este fichero**; y tras cualquier
parada, `cmp` contra la copia antes de tocar nada. El tope por corrida (`timeout 150` delante del `test-without-building`)
es lo que hace que un mutante muerto no cueste 10 min: tras un rojo `xcodebuild` no sale.

**2026-09-28: tercera reincidencia, y esta vez por el DISCO.** Escribí el runner sin abrir este fichero. Paré el colgado
a mano (bien, restaurando desde la copia), pero la tanda de 31 llenó el disco: cada corrida deja ~400 MB en `Dead/` del
simulador (`docs/aprendizajes-tecnicos.md`, escrito EL DÍA ANTES). Con 121 MB libres la restauración del `finally` falló
con ENOSPC y dejó `DataWipeService.swift` mutado; lo cazó el `cmp`. ⇒ **el runner vacía `Dead/` al empezar cada vuelta**
(`find <device>/data/Library/Caches/com.apple.containermanagerd/Dead -mindepth 1 -delete`; `rm -rf` con glob lo deniega
el permiso), y un `INFRA` sin `Test run with` se lee con `df -h /` antes que como veredicto.
