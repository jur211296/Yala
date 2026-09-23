---
id: the-gate-stamp-hides-the-deleted-side-of-a-staged-rename
status: backlog
priority: low
area: "qa, gate"
created: 2026-09-23
updated: 2026-09-23
source: "cierre de `dangling-ref-repair-is-lost-when-its-row-cannot-be-read` (2026-09-23), medido al commitear"
---

# El sello del gate cambia si mueves un renombrado dentro o fuera del índice, y no ve el fichero borrado

## El problema

`qa/scripts/worktree-stamp.sh` promete en su cabecera que la huella describe **lo que hay en disco**, nunca cómo está
repartido entre índice y árbol, y que cubre «los dos lados de un rename». No es así con un renombrado en el índice:
`git diff HEAD --name-only` detecta el rename (git 2.54, `diff.renames` por defecto) y **solo lista el lado nuevo**. El
viejo, que en disco ya no existe, no entra en la huella.

## Medido (2026-09-23, sin tocar el disco entre medias)

- `git mv tickets/in-progress/X.md tickets/done/X.md` → sellar → `git restore --staged` de las dos rutas → el hook de
  pre-commit bloquea: «el codigo cambio desde que paso /gate». Huella `d7838…` frente a `7a797…`.
- Con el rename en el índice, `git diff HEAD --name-only` da solo `tickets/done/X.md`; sin él, da `tickets/in-progress/X.md`
  (y el nuevo sale por `ls-files --others`). Volviendo a poner el rename en el índice, la huella vuelve a `d7838…`.

Dos efectos: un falso «el código cambió» que obliga a re-sellar (molesto, no peligroso), y una BAJA que no entra en la
huella mientras forme parte de un rename en el índice (lo que se sella no describe todo el disco).

## Qué habría que hacer

- `git diff HEAD --name-only --no-renames -z` en el script, y un caso nuevo en `qa/scripts/worktree-stamp-test.sh`
  (rename en el índice vs fuera: misma huella; y el lado viejo presente como `ausente`).

## Criterios de aceptación

- [ ] Mover un rename entre índice y árbol no cambia la huella.
- [ ] El lado borrado de un rename aparece en la huella.
