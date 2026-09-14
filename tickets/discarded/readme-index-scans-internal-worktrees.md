---
id: readme-index-scans-internal-worktrees
status: discarded
priority: low
area: "docs, tooling"
created: 2026-09-14
updated: 2026-09-14
source: "cierre de `cloud-signout-collapses-every-groups-transient-into-permanent` (2026-09-14)"
---

# El índice del README lista ficheros de worktrees temporales, y cambia en cada corrida

## Lo medido (2026-09-14)

`python3 scripts/indice_readme.py --repo . --apply` en el árbol principal reescribió la línea «Ficheros
de más de 60 KB» con esto dentro:

```
✓ `.claude/worktrees/bridge-cse_01SgM6eek2Y57C3KCsjhopKs/docs/DECISIONS.md` (256 KB) ·
✓ `.claude/worktrees/bridge-cse_018cPCaGmuz2ToSzLHoYfRQL/docs/DECISIONS.md` (256 KB) ·
✓ `.claude/worktrees/bridge-cse_0181xwKTB8jR3XCBrYfRDWWq/docs/DECISIONS.md` (256 KB) · …
```

Son **copias** de los mismos ficheros dentro de worktrees internos que van y vienen (`git worktree
list` los da como `locked`). El README ya arrastra una tanda anterior (`elastic-ritchie-9f2188`), así
que el ruido está commiteado desde antes.

**El efecto práctico:** cada sesión que corra el generador produce un diff distinto según qué worktrees
existan en ese momento, y ninguno dice nada útil — la lista existe para avisar de ficheros gordos que
hay que leer por su índice, y una copia en un worktree efímero no es un fichero que nadie vaya a abrir.

## Lo que se espera

Que el escáner excluya `.claude/worktrees/` (y cualquier worktree bajo el árbol). De paso, comprobar si
otros generadores del repo tienen el mismo agujero: `glosario.py` e `indexar_doc.py` recorren rutas
parecidas.


## Descartado el 2026-09-14 — duplicado

Mismo defecto y misma causa que `readme-index-duplicates-internal-worktree-files` (2026-09-09), que es
el más antiguo y el único con criterio de hecho. Lo medido aquí se conservó allí; este no se reabre.
