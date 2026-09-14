---
id: readme-index-generator-counts-worktree-copies
status: discarded
priority: low
area: "documentación, scripts"
created: 2026-09-13
updated: 2026-09-14
source: "medido en el cierre del #151 al correr los generadores desde el árbol principal"
---

# El índice del README cuenta los ficheros de los worktrees vivos

## Qué pasa

`scripts/indice_readme.py` lista los ficheros de más de 60 KB recorriendo el árbol **entero**, y
`.claude/worktrees/` está dentro. Con cinco worktrees abiertos, `docs/DECISIONS.md` sale **seis veces**
en la misma línea — una por copia — y lo mismo `docs/aprendizajes-tecnicos.md`.

Medido el 2026-09-13 al cerrar el #151: el generador quería reescribir esa línea de 6 entradas a 11,
todas duplicados de dos ficheros. **Se revirtió sin commitear**, porque lo que escribe no es una
discrepancia real: es el número de worktrees que había abiertos en ese instante.

## Por qué importa

El valor de los generadores es que destapan cifras desfasadas —«9 decisiones» cuando ya son 11—. Un
generador cuya salida depende de cuántos worktrees tengas abiertos **enseña a ignorar su diff**, que es
justo lo contrario. Y como el contenido cambia en cada cierre, mete ruido en el historial de `2.1`.

## Criterio de aceptación

- [ ] `indice_readme.py` excluye `.claude/worktrees/` (y cualquier otro árbol de trabajo) del barrido.
- [ ] Correrlo con worktrees abiertos y sin ellos da **el mismo** README. Medido, no supuesto.
- [ ] Mirar de paso si `glosario.py`, `reorg_docs.py` y `frescura.py` tienen el mismo agujero: los
      cuatro recorren el árbol.


## Descartado el 2026-09-14 — duplicado

Mismo defecto y misma causa que `readme-index-duplicates-internal-worktree-files` (2026-09-09), que es
el más antiguo y el único con criterio de hecho. Lo medido aquí se conservó allí; este no se reabre.
