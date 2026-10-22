---
name: no-editar-un-script-en-marcha
description: Bash lee el script a trozos mientras corre; editarlo a medias desplaza bytes y rompe una línea que estaba bien.
metadata:
  type: feedback
---

Si un script mío está corriendo (una medida larga en segundo plano), lo que lanzo es una COPIA congelada en el
scratchpad, y edito el original sin miedo.

**Why:** el 2026-10-06 (#373) añadí 5 líneas de cabecera a `ci-reintentar-rojos.sh` mientras su corrida local de
35 min seguía viva. Bash lo lee por bloques: tras la vuelta 3 leyó a mitad de una línea desplazada, dio
`syntax error near unexpected token '('` y salió con exit 2 sin publicar el resultado. Parecía un bug del script y
era mi edición. Costó repetir la medida.

**How to apply:** antes de lanzar en segundo plano algo que dure más de un par de minutos, `cp` al scratchpad y
lanza la copia. Si un script sale con un error de sintaxis en una línea que el banco cubre, piensa primero si lo
editaste mientras corría. Relacionado: [[mutantes-sin-diagnose-y-con-copia]].
