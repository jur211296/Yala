---
id: worktree-stamp-depends-on-whether-a-rename-is-staged
status: backlog
priority: low
area: qa, tooling
created: 2026-10-22
updated: 2026-10-22
source: encargo «bugs de cifras y de entrada» (2026-10-22), al commitear tras /gate
---

# La huella del gate cambia según si un rename está staged, aunque el disco sea el mismo

## Qué pasa

`qa/scripts/worktree-stamp.sh` promete que la huella describe lo que hay en disco y no cómo está repartido entre el
índice y el árbol. No es verdad con un rename: con el rename staged (`git mv`), `git diff HEAD --name-only` detecta el
rename y lista solo el destino; con el rename sin stagear salen las dos rutas (el origen borrado y el destino sin
trackear). Medido el 2026-10-22: `git restore --staged tickets/` tras sellar cambió la huella y el `pre-commit` bloqueó
con «el codigo cambio desde que paso /gate» sin que cambiara un byte del disco. `git commit -- <rutas>` (índice
temporal) también lo bloquea.

## Qué hacer

Listar con `git diff HEAD --name-only --no-renames -z` y añadir el caso al banco `qa/scripts/worktree-stamp-test.sh`
(sellar con el rename staged, desstagearlo, la huella no cambia).
