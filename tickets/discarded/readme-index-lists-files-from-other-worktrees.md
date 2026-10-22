---
id: readme-index-lists-files-from-other-worktrees
status: discarded
priority: low
area: "docs, tooling"
created: 2026-09-13
updated: 2026-09-14
source: "cierre del PR #152 — el generador cambió la línea y el cambio era ruido"
---

# El índice del README enumera ficheros que viven dentro de otros worktrees

## Lo medido (2026-09-13)

`python3 scripts/indice_readme.py --repo . --apply` recorre el árbol SIN excluir
`.claude/worktrees/`, así que la línea «Ficheros de más de 60 KB» lista las copias de
`docs/DECISIONS.md`, `docs/aprendizajes-tecnicos.md` y `qa/cloud/README.md` que hay dentro de cada
worktree vivo, como si fueran ficheros del repo.

El contenido de esa línea **depende de qué worktrees existan en el momento de correr el script**: en el
cierre del #152 pasó de citar uno (`elastic-ritchie-9f2188`, ya commiteado) a citar cuatro
(`bridge-cse_*`), y desplazó fuera de la lista entradas reales del repo. El cambio se revirtió a
propósito: sustituía un ruido por otro, y el nuevo caduca en cuanto se retire un worktree.

## Lo que se espera

Excluir `.claude/worktrees/` —y cualquier otro directorio de worktree— del recorrido del generador, y
limpiar la entrada de `elastic-ritchie-9f2188` que ya está commiteada en `README.md`.

**Comprobación**: correr el script con varios worktrees vivos y con ninguno tiene que dar el MISMO
resultado. Hoy no lo da.


## Descartado el 2026-09-14 — duplicado

Mismo defecto y misma causa que `readme-index-duplicates-internal-worktree-files` (2026-09-09), que es
el más antiguo y el único con criterio de hecho. Lo medido aquí se conservó allí; este no se reabre.
