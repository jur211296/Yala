---
name: revertir-sin-commit-destruye
description: En un árbol sin commitear, `git checkout -- <fichero>` revierte a HEAD y se lleva el trabajo de la sesión. Para deshacer un experimento se usa una copia propia, no git. Me pasó el 2026-09-05 verificando mutantes.
metadata:
  type: feedback
---

**Para deshacer un cambio experimental sobre trabajo que aún no está commiteado, revierto desde una
copia mía (`cp`), nunca con `git checkout -- <fichero>`.**

**Why:** el 2026-09-05, verificando mutantes del ticket `secondary-guest-exit-lock-and-outbox`, hice
`git checkout -- Yala/Services/CloudSync/CloudSessionSignOut.swift` para deshacer el mutante. Ese
fichero llevaba **las dos piezas del ticket sin commitear**, y `checkout --` restaura desde el
índice/HEAD: se llevó por delante ~150 líneas de trabajo de una hora. No lo noté por el `git status`
sino porque el siguiente build falló con `has no member 'exitSecondaryDiscardingPending'`.

Se recuperó entero porque minutos antes había hecho `cp $F /tmp/orig_signout.swift` para *otro*
propósito. Fue suerte, no procedimiento.

Lo que hace la trampa peligrosa es que el flujo de mutantes **invita** al error: aplicar → correr →
revertir, en bucle, y «revertir» en git es lo primero que viene a la mano. El resto de la sesión usé
`cp /tmp/orig.swift $F` y no volvió a pasar.

**How to apply:**

- **Antes de empezar una tanda de mutantes**, `cp` del fichero a un fichero de la scratchpad. Ése es
  el punto de retorno, y revertir es `cp` en el otro sentido.
- **`git checkout -- <fichero>` solo cuando el trabajo bueno ya está en un commit.** Con el árbol
  sucio equivale a `rm` de lo no commiteado, sin confirmación y sin reflog que lo recupere: no hay
  objeto en la base de datos de git, nunca lo hubo.
- **Lo mismo vale para `git reset --hard`**, que sí usé después y a propósito — pero con
  `git diff HEAD --binary > patch` verificado con `git apply --check --reverse` antes de tirar nada.
  Un `reset --hard` con patch comprobado es seguro; un `checkout --` a media tanda, no.
- **Y el aviso del entorno sigue en pie:** el stash es compartido entre worktrees, así que tampoco
  es la salida. Un commit WIP en la rama o una copia en la scratchpad; nada más.

Relacionado: [[mis-mediciones-fallan-por-el-filtro]] — la verificación por mutantes es lo que le da
valor a un test, y por eso conviene que su bucle no sea el paso donde se pierde el trabajo.
