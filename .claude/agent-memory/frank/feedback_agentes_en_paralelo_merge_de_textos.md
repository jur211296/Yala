---
name: agentes-en-paralelo-merge-de-textos
description: Agentes en paralelo y textos: no con merge union; mejor que entreguen JSON y aplicarlo con script (17-oct). Y el barrido cazó seis defectos que los tests no ven
metadata:
  type: feedback
---

Repartir un encargo grande en agentes con worktree propio (solo compilan; yo integro, pruebo y uso el único
simulador) funcionó el 2026-10-17: 46 cards en ~4 h. Lo que **no** funcionó fue el plan de integrar los
`Localizable.strings` con merge `union`. Los agentes no solo añadían al final: también borraban claves sin uso y
cambiaban valores en su sitio, y `union` deja las dos líneas, o sea, duplicados. La salida fue un merge a tres
bandas clave a clave (base, la mía y la del agente; los `.stringsdict` con `plistlib`), que aplica altas, cambios
y bajas, y lista los choques.

Dos detalles que también mordieron:
- El agente de terminología (L7-18) va **el último**: en una clave que tocaron él y un lote, manda la del lote, que
  ya usa el término nuevo.
- Con autopush, la rama remota recibe los commits wip. Para dejar un solo commit hay que hacer `git push
  --force-with-lease=<rama>:<sha wip>`, y un PR abierto antes apunta a los wip hasta ese push.

**How to apply:** al lanzar agentes que toquen textos, diles que pueden cambiar y borrar claves, y prepara el
merge clave a clave antes de integrar. Pídeles además que no toquen el índice de QA ni el tablero: esos los
escribe quien integra.

**Lo que funcionó el 2026-10-17 (lote 8, 17 cards con dos agentes):** que los agentes NO toquen los `.strings` y
entreguen sus textos como JSON (clave → idioma → valor, más plurales) que yo aplico con un script a los 16 idiomas.
Cero conflictos de textos. Dos detalles del script: las cuatro variantes no tienen `.stringsdict` y necesitan la forma
`other` como línea plana, y `es`/`pt` se copian de `es-419`/`pt-BR`. El código se integró con `git merge-file` en
los dos ficheros compartidos, sin conflictos, porque cada agente tenía su lista de ficheros vetados.

Y lo que no ven: los agentes solo compilan, y el barrido en el simulador cazó **seis** defectos visuales que ningún
test veía (una hoja vacía, un aviso bajo el teclado, una barra translúcida que cortaba sus textos, un contorno tapado
por el cristal…). Con agentes, el barrido no es opcional.
