---
description: Arranca la sesión — lee solo el set fijo, contrasta contra git y entrega el estado accionable
allowed-tools: Bash(git:*), Bash(gh:*), Bash(date:*), Bash(ls:*), Bash(tablero listar:*), Read, Glob, Grep
---

Arranque de **Yala — app iOS de finanzas personales**. No narres los pasos: entrega el briefing.

> **Yala no tiene fichero de estado desde el 2026-09-30** (ADR-053 de casa; `docs/DECISIONS.md`,
> «El estado de Yala se lee de donde se escribe solo»). El hook de arranque dirá que no lo
> encuentra: es deliberado. El estado se reconstruye de tres fuentes que se escriben solas al
> trabajar.

## 1 · Leer, en este orden, y nada más

- `CLAUDE.md` de este repo
- **Lo último que aterrizó en `2.1`**:
  - `gh pr list --state merged --base 2.1 -L 5 --json number,title,mergedAt,body` — el cuerpo de
    cada PR es su crónica. Lee su «Necesita de ti» y su «Qué quedó fuera»; lo demás, solo si hace
    falta. Los PRs anteriores al 2026-09-30 no tienen «Necesita de ti»: ahí lo que espera de
    Jürgen está en «Qué quedó fuera».
  - `git log origin/2.1 --no-merges --first-parent -10 --format='%h %ad %s' --date=short` — los
    commits directos a `2.1`, sin PR. Su crónica es el cuerpo del commit (`git show -s <sha>`).
- **Lo que está en curso**: `ls tickets/in-progress/` y, de cada uno, su cabecera.
- **Lo que espera de Jürgen**: `tablero listar --proyecto yala --asignado jurgen`. Los device-QA
  no van uno a uno al tablero: su registro es el ticket en `tickets/qa/` (`ls tickets/qa | wc -l`).
- El **índice** de `docs/DECISIONS.md` — son 250 KB, **no lo cargues entero**: localiza la entrada
  por el índice y salta a ella
- `docs/TICKETS.md` si vas a tocar la cola; el ticket concreto en `tickets/<estado>/`
- `docs/EXECUTION-RULES.md` solo si vas a ejecutar builds o tests

**No leas `docs/sessions/` ni `docs/modo-nube/_archive/`**: son archivo, no fuente.
Las reglas de `.claude/rules/` se cargan solas al tocar sus ficheros — no las leas por adelantado.

El número de build de TestFlight no está escrito en ningún sitio a propósito: Jürgen lo mira al
subir. Si hace falta, `asc` lo dice.

## 2 · Comprobar la realidad, no solo los papeles

`git status --porcelain`, `git log -1 --oneline`, rama actual, y `git log @{u}..HEAD`.

Dos discrepancias que se dicen **siempre** en el briefing:

- **Un PR abierto con auto-merge que no avanza**: `gh pr list --state open --json
  number,title,autoMergeRequest,mergeStateStatus`. Uno en `DIRTY` (conflicto) o `BLOCKED` sin CI
  en marcha no va a mergear solo, y nadie más lo mira.
- Una ruta del `CLAUDE.md` que no resuelve. Es el fallo más caro que existe aquí.

## 3 · Briefing — máximo 12 líneas

- Dónde quedó — rama, último PR mergeado y de qué iba, ticket en curso
- Qué sigue: **un** ítem, el siguiente de verdad
- Qué está bloqueado esperando a Jürgen: sus tarjetas y lo que diga el «Necesita de ti» reciente
- Discrepancias entre lo que dicen los documentos y lo que hay

No propongas trabajo antes de haber leído los PRs mergeados y el tablero. No resumas el histórico
de decisiones.
