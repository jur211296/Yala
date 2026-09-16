---
id: indice-readme-cuenta-los-ficheros-de-los-worktrees-anidados
status: backlog
priority: low
area: "documentación, tooling"
created: 2026-09-16
updated: 2026-09-16
source: "cierre de `cloud-tab-does-not-say-this-phone-cannot-sync-personal-data` (2026-09-16): el generador metió copias en el índice y el diff se revirtió"
---

# `indice_readme.py` lista los ficheros grandes de los worktrees anidados como si fueran del repo

Esto no lo ve nadie que use la app: lo paga quien lee el README, y **lo paga cada cierre**, porque el generador
corre en el paso de reindexar y deja un diff que hay que decidir si se commitea.

## Lo medido (2026-09-16)

`python3 scripts/indice_readme.py --repo . --apply` reescribió la línea de «Ficheros de más de 60 KB» duplicando
cada entrada con su copia bajo `.claude/worktrees/elastic-ritchie-9f2188/`:

```
✓ docs/DECISIONS.md (256 KB) · ✓ .claude/worktrees/elastic-ritchie-9f2188/docs/DECISIONS.md (243 KB) ·
✓ docs/aprendizajes-tecnicos.md (205 KB) · ✓ .claude/worktrees/elastic-ritchie-9f2188/docs/aprendizajes-tecnicos.md (192 KB) · …
```

Once entradas reales pasaron a doce, seis de ellas del worktree. Y **expulsó del índice a las cinco últimas
reales** —entre ellas `.claude/rules/swiftdata-cloudkit.md`, que es la que más falta hace ahí— porque la lista
tiene tope y las copias ocuparon su sitio.

`/Users/jur/Yala/.claude/worktrees/elastic-ritchie-9f2188/` es un worktree anidado de este mismo repo (sale en
`git worktree list`, en detached HEAD). Sus ficheros son copias del árbol, no documentos nuevos, así que contarlos
no informa de nada: sube el ruido y **desplaza a los que sí importan**.

El diff se revirtió en el cierre en vez de commitearlo. No es una discrepancia que el generador destape —que es
para lo que existe— sino una que él mismo crea.

## Por dónde va

`scripts/indice_readme.py` recorre el árbol buscando ficheros por tamaño. Le falta excluir `.claude/worktrees/`,
igual que ya se excluyen (o habría que comprobar si se excluyen) `Build/`, `DerivedData/` y `.git/`. Conviene
mirar si el mismo barrido lo hacen `frescura.py` y `glosario.py`, que corren en el mismo paso del cierre: si
alguno cuenta esas copias, sus cifras también están infladas.

## Relación con otros tickets

- `generated-index-lands-above-yaml-frontmatter` — el otro defecto de los generadores de índice, del cierre del #176.
