---
id: readme-index-generator-walks-into-claude-worktrees
status: backlog
priority: low
area: "docs, scripts"
created: 2026-09-15
source: "hallazgo del cierre de `groups-tab-does-not-say-this-phone-cannot-sync-groups` (2026-09-15)"
---

# El generador del índice del README recorre un worktree interno de Claude Code y mete sus ficheros en la lista

## El problema

`python3 scripts/indice_readme.py --repo . --apply` reescribe el bloque «Ficheros de más de 60 KB» del `README.md`
metiendo rutas como `.claude/worktrees/elastic-ritchie-9f2188/docs/DECISIONS.md (243 KB)`, que **no son ficheros del
repo**: son la copia de un worktree interno que Claude Code crea dentro del árbol principal.

El efecto es doble: la lista deja de ser útil (cada fichero grande sale dos veces, y la mitad de las entradas apuntan
a una ruta que no existe para nadie más) y el `--apply` **produce un diff nuevo en cada cierre**, así que cualquier
sesión que reindexe se lleva la basura a `2.1` sin querer.

## Lo medido (2026-09-15)

- `.claude/worktrees/elastic-ritchie-9f2188` existe en `/Users/jur/Yala` y está excluido de git por
  `.git/info/exclude:18` — o sea, git ya sabe que no es del repo.
- `scripts/indice_readme.py:90` excluye `.git`, `node_modules`, `.build` y `DerivedData`, y nada más:
  `dirs[:] = [d for d in dirs if d not in ('.git', 'node_modules', '.build', 'DerivedData')]`.
- El cierre de esa sesión descartó el cambio a mano; el `README.md` en `2.1` sigue limpio.

## Lo que hay que decidir

1. Excluir `.claude/` entero en el barrido (o al menos `.claude/worktrees`).
2. Mejor: barrer solo lo que git conoce (`git ls-files`), que cierra esta familia entera de una vez y no exige
   acordarse del siguiente directorio que aparezca.
3. Comprobar si los otros generadores (`reorg_docs.py`, `glosario.py`, `frescura.py`) tienen el mismo barrido; en esta
   corrida ninguno ensució nada, pero no se ha medido por qué.
