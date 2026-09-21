---
id: indice-readme-barre-worktrees-anidados
status: backlog
priority: low
area: "tooling, docs"
created: 2026-09-21
updated: 2026-09-21
source: "medido al correr los regeneradores en el cierre de `restore-says-no-data-when-the-icloud-import-never-settled`, 2026-09-21"
---

# `indice_readme.py` mete en el README los ficheros de un worktree anidado

## Medido (2026-09-21)

Al correr `python3 scripts/indice_readme.py --repo . --apply` desde `/Users/jur/Yala`, la lista de
«ficheros de más de 60 KB» pasó de 11 entradas a 12, y **la mitad de las nuevas son duplicados con
prefijo `.claude/worktrees/elastic-ritchie-9f2188/`**:

```
✓ docs/DECISIONS.md (256 KB) · ✓ .claude/worktrees/elastic-ritchie-9f2188/docs/DECISIONS.md (243 KB)
✓ docs/aprendizajes-tecnicos.md (207 KB) · ✓ .claude/worktrees/…/docs/aprendizajes-tecnicos.md (192 KB)
…
```

Ese directorio es un **worktree de git anidado dentro del propio repo** (sale en
`git worktree list` como `/Users/jur/Yala/.claude/worktrees/elastic-ritchie-9f2188`, detached HEAD).
Su contenido es una copia de otra rama, es efímero, y no es documentación de este árbol.

El cambio **no se commiteó**: se revirtió en el cierre, porque escribir esas rutas deja el README
apuntando a ficheros que desaparecen con el worktree. El efecto secundario es que las dos cifras que
sí cambiaron de verdad (`aprendizajes-tecnicos.md` 205→207 KB, `groups-consent-door-spec.md` 96→98)
se quedan desfasadas hasta que alguien corra el script sin worktrees anidados.

## Qué hay que mirar

- `scripts/indice_readme.py` debería excluir `.claude/worktrees/` al barrer, igual que presumiblemente
  ya excluye `.git/`.
- **Y los hermanos**: `frescura.py`, `glosario.py` y `reorg_docs.py` corren en el mismo paso del
  cierre. En esta corrida no ensuciaron nada, pero conviene comprobar si es por diseño o por suerte
  (¿miran solo `docs/`?).
- Un worktree anidado dentro del árbol principal es raro de por sí; si no hace falta, retirarlo cierra
  el caso por el otro lado. Pero el script debería aguantarlo igual.

## Criterios de aceptación

- [ ] `indice_readme.py --apply` con un worktree anidado presente no mete sus ficheros en el README.
- [ ] Medido si los otros tres regeneradores tienen el mismo hueco.
