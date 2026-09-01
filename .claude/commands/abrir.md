---
description: Arranca la sesión — lee solo el set fijo, contrasta contra git y entrega el estado accionable
allowed-tools: Bash(git:*), Bash(gh:*), Bash(date:*), Read, Glob, Grep
---

Arranque de **Yala — app iOS de finanzas personales**. No narres los pasos: entrega el briefing.

## 1 · Leer, en este orden, y nada más

- `CLAUDE.md` de este repo
- `docs/ESTADO.md` — la foto de hoy (es el `STATE.md` de este repo, con otro nombre)
- El **índice** de `docs/DECISIONS.md` — son 234 KB, **no lo cargues entero**: localiza la entrada
  por el índice y salta a ella
- `docs/TICKETS.md` si vas a tocar la cola; el ticket concreto en `tickets/<estado>/`
- `docs/EXECUTION-RULES.md` solo si vas a ejecutar builds o tests

**No leas `docs/sessions/` ni `docs/modo-nube/_archive/`**: son archivo, no fuente.
Las reglas de `.claude/rules/` se cargan solas al tocar sus ficheros — no las leas por adelantado.

## 2 · Comprobar la realidad, no solo los papeles

`git status --porcelain`, `git log -1 --oneline`, rama actual, y `git log @{u}..HEAD`.

Tres discrepancias que se dicen **siempre** en el briefing:

- **El sello `updated:` de `docs/ESTADO.md` contra git.** Es un sello a mano: miente en cuanto
  alguien se olvida, y ese olvido es justo lo que buscamos. El hook de arranque ya lo compara.
- `docs/ESTADO.md` fechado antes del último commit: hubo trabajo después del último cierre.
- Una ruta del `CLAUDE.md` que no resuelve. Es el fallo más caro que existe aquí.

**¿Entró trabajo sin bitácora?** `git log --merges --oneline -10`. Un merge de una rama
`encargo/…` trae una sesión que se cerró en un worktree, y **esas sesiones no escriben bitácora ni
estado a propósito**: dos ramas tocando la misma foto chocan siempre, así que se escribe aquí,
después de mergear. Si el merge no tiene su entrada, ese trabajo entró sin registro — **es lo
primero que se arregla.** El parte está en el cuerpo del PR: `gh pr view <n>`.

## 3 · Briefing — máximo 12 líneas

- Dónde quedó — rama, build en TestFlight si aplica, ticket en curso
- Qué sigue: **un** ítem, el siguiente de verdad
- Qué está bloqueado esperando a Jürgen
- Discrepancias entre lo que dicen los documentos y lo que hay

No propongas trabajo antes de haber leído `docs/ESTADO.md`. No resumas el histórico de decisiones.
