---
name: tablero-nota-sustituye
description: `tablero editar --nota` SUSTITUYE la nota entera; para añadir, lee la nota con `tablero ver` y concatena
metadata:
  type: feedback
---

`tablero editar <id> --nota "…"` reemplaza la nota, no la amplía. El 2026-10-05 borró la decisión de Jürgen (opción A, con
su texto) al apuntar el PR; se repuso a mano porque la salida del comando imprimió la nota vieja.

**Why:** la nota de una tarjeta suele guardar la decisión de Jürgen, y no vive en otro sitio del tablero.

**How to apply:** antes de `--nota`, `tablero ver <id>` y escribe `<nota vieja> | <fecha>: <lo nuevo>`.
