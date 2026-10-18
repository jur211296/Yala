---
name: tablero-nota-sustituye
description: `tablero editar --nota` y `--enlace` SUSTITUYEN el campo entero; para añadir, lee con `tablero ver` y repite lo que había
metadata:
  type: feedback
---

`tablero editar <id> --nota "…"` reemplaza la nota, no la amplía. El 2026-10-05 borró la decisión de Jürgen (opción A, con
su texto) al apuntar el PR; se repuso a mano porque la salida del comando imprimió la nota vieja.

**Why:** la nota de una tarjeta suele guardar la decisión de Jürgen, y no vive en otro sitio del tablero.

**How to apply:** antes de `--nota`, `tablero ver <id>` y escribe `<nota vieja> | <fecha>: <lo nuevo>`.

**Y la nota es multilínea (2026-10-07):** `tablero ver <id> | sed -n 's/^note *//p'` solo captura el
PRIMER párrafo; los siguientes vienen sin el prefijo `note` y se pierden al concatenar. Pasó así y hubo
que reponer dos párrafos a mano. Lee el bloque `/^note/,/^<campo siguiente>/` entero, o copia la nota del
`ver` completo, antes de reescribirla.

**Y `--enlace` también sustituye (2026-10-11):** al apuntar el PR #458 con un solo `--enlace`, las dos tarjetas
perdieron el enlace al ticket y al PR #438. Se repusieron pasando los tres `--enlace` en la misma llamada (es
repetible). Antes de `--enlace`, `tablero ver <id>` y repite los que ya tenía.

**Y el formato tiene dos trampas que no avisan hasta el final (2026-10-18):** `--enlace` va como `"titulo|url"` (con `—`
lo rechaza, y `mover`/`asignar` de la misma línea sí se aplican: la tarjeta queda a medias), y `--agente frank` va DETRÁS
del subcomando (`tablero editar <id> --agente frank …`); delante, `tablero` lo lee como comando y falla.
