---
id: open-worktrees-lack-the-attribution-hook
status: backlog
priority: very-low
area: "proceso"
created: 2026-09-09
updated: 2026-10-08
source: salió de camino al cerrar el-hook-que-prohibe-atribuir-a-una-ia-no-corre-en-este-repo
---

# Los worktrees abiertos antes del 9-sep no tienen el candado

## Qué pasa

`core.hooksPath` apunta a `.githooks`, una ruta **relativa al árbol de trabajo**. Medido en
laboratorio: se resuelve bien desde subdirectorios y dentro de un worktree, pero **usa el
`.githooks` de ESE worktree**. Una rama que no traiga `.githooks/commit-msg` no tiene
candado, y git no dice nada — simplemente no ejecuta ningún hook.

El fichero se añadió el 2026-09-09. Los worktrees abiertos antes de esa fecha siguen sin él
hasta que su rama incorpore el commit. En el momento de medirlo había **9 worktrees de Yala
vivos**.

## Por qué importa

Es exactamente el escenario donde más se commitea: una sesión larga en su worktree. El
candado del árbol principal no la alcanza.

## Qué haría falta

Alguna de estas, y elegir es de Jürgen:

1. Que `lanzar-sesion` compruebe `test -x .githooks/commit-msg` al crear el worktree y avise
   si falta (la rama nace de `origin`, así que en cuanto `2.1` lo tenga, los nuevos lo
   heredan; el problema es solo el de los ya abiertos).
2. Que el `/abrir` lo compruebe y lo diga en el arranque, como hace con el disco.
3. Nada: los worktrees vivos se cierran en días y el problema se extingue solo.

## Criterio de hecho (AC)

- [ ] Decidido cuál de las tres.
- [ ] Si es 1 o 2: un worktree sin el fichero produce el aviso, y uno con él no.

## Medido en 2.1 (triage 2026-10-08)

- **En la Mini, la premisa ya no se cumple.** `core.hooksPath` vale hoy `/Users/jur/Yala/.githooks`, una ruta **absoluta**, en `/Users/jur/Yala/.git/config`. Todos los worktrees comparten esa config.
- Así, los 3 worktrees de antes del 9-sep (2026-09-05 x2, 2026-09-09) no tienen `.githooks/commit-msg` en su árbol, pero `git rev-parse --git-path hooks` devuelve `/Users/jur/Yala/.githooks`, que sí lo tiene.
- Lo que queda: nadie lo ha documentado (`.claude/rules/git-hooks.md:34` sigue diciendo `.githooks` relativo). Si el árbol principal hace checkout de una rama sin el fichero, el candado se cae para todos los worktrees a la vez. En el otro Mac no está medido.

## Pregunta para Jürgen (triage 2026-10-08)

- **A** (recomendada): adoptar la ruta absoluta como receta y documentarla en `.claude/rules/git-hooks.md`, con su trampa. Medirla también en el otro Mac.
- **B**: la opción 1 del ticket, que `lanzar-sesion` avise si el worktree no tiene el fichero.
- **C**: nada, y cerrar el ticket.

Con A, la prioridad es `very-low`.

Triage 2026-10-08: abierto · medium → very-low · en la Mini `core.hooksPath` es absoluto (`/Users/jur/Yala/.githooks`) y los worktrees viejos ya tienen el candado; queda documentarlo y medir el otro Mac.
