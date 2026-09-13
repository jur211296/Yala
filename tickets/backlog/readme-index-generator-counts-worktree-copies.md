---
id: readme-index-generator-counts-worktree-copies
status: backlog
priority: low
area: "documentación, scripts"
created: 2026-09-13
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
