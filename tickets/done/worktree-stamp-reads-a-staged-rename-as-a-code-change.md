---
id: worktree-stamp-reads-a-staged-rename-as-a-code-change
status: done
priority: low
area: tooling
created: 2026-10-21
updated: 2026-10-26
source: sesión «lote decidido 2.2 · 09» (2026-10-21), commit bloqueado tras un /gate verde
---

# El sello del gate cambia al hacer `git add` de un fichero movido

`qa/scripts/worktree-stamp.sh` lista los ficheros con `git diff HEAD --name-only`. Con un fichero movido (aquí, un ticket
de `tickets/backlog/` a `tickets/qa/`, con el cuerpo casi igual), sin `git add` salen las dos rutas —la vieja como
`ausente` y la nueva como untracked—; tras `git add`, git detecta el renombre y `--name-only` solo da la nueva. La huella
cambia sin que cambie nada en disco, y el `pre-commit` bloquea con «el codigo cambio desde que paso /gate».

Medido el 2026-10-21: huella `d1bc6…` con el movimiento en staging frente a `dbc4e…` sin él, mismo disco.

## Arreglo propuesto

`git diff HEAD --name-only --no-renames -z` en el script, y un caso nuevo en `qa/scripts/worktree-stamp-test.sh` (mover un
fichero y hacer `git add`). Mientras tanto: commitear el movimiento aparte, sin `.swift` en staging.

## Cerrado 2026-10-26 (encargo ci-gate-reintentos-sello)

`--no-renames` en `qa/scripts/worktree-stamp.sh` (y en el filtro de `.swift` de `precommit-gate.sh`). Casos H e I nuevos en
`qa/scripts/worktree-stamp-test.sh`: movido a mano = movido y staged = `git mv`; copiar ≠ mover (el lado viejo cuenta como
`ausente`); mover y editar cambia la huella. 11/11 con el arreglo; contra el script viejo, 2 rojos. De punta a punta en
un repo desechable: mover un `.swift`, sellar, `git add` → el pre-commit pasa (en la base, «el codigo cambio desde que
paso /gate»).
