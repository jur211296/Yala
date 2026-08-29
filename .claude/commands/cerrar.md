---
description: Cierra la sesión — verifica que nada quedó abierto, sincroniza el ticket, escribe docs/ESTADO.md y libera el disco sin preguntar
allowed-tools: Bash(git:*), Bash(python3 scripts/glosario.py:*), Bash(bash qa/scripts/disk-report.sh:*), Bash(bash qa/scripts/session-cleanup.sh:*), Bash(xcrun simctl:*), Bash(tmutil:*), Bash(pgrep:*), Read, Edit, Glob, Grep, Bash(bash ~/.claude/scripts/limpiar-cowork.sh:*)
---

Cierre de sesión de Yala. Cinco bloques, en este orden. Un solo informe al final; no narres cada paso. No preguntes. Tras reportar, ejecuta y listo.

## 1 · Nada quedó abierto

- Procesos de build vivos (`pgrep -f "xcodebuild"`), simuladores arrancados, tareas en background de esta sesión.
- `git status --porcelain` y `git log @{u}..HEAD --oneline`.

Si hay cambios sin commitear: decláralos WIP en el informe y sigue. Nunca preguntes. Nunca commitees en el cierre. El hook `Stop` ya pushea lo commiteado — no lo dupliques.

## 2 · Documentación mínima

Solo dos superficies. Si ya están al día, dilo en una línea y sigue.

- **El ticket** en `tickets/` del trabajo de esta sesión: ¿refleja lo hecho y su estado? Si pasó a QA, muévelo a `tickets/qa/` y `status: qa`.
- **`docs/glosario.md`**: solo si esta sesión añadió decisiones. `python3 scripts/glosario.py --repo . --apply` reescribe el bloque generado (término → dónde se decide) y deja intacta la cabecera a mano. Si no se tocó `DECISIONS.md`, no hay nada que hacer.
- **`qa/coverage-index.json`**: obligatorio solo si se tocó código bajo `Yala/`. Actualiza `lastVerified` de las áreas afectadas y corre `bash qa/validate-coverage.sh`.

Una regla nueva y duradera va a `.claude/rules/` o a CLAUDE.md — una vez cada muchas sesiones, no en cada cierre. No inventes una para tener algo que escribir.

## 3 · Disco (fire-and-forget)

**Esto es lo que evita el fallo que cuesta horas.** Con el disco casi lleno CoreSimulator no lanza apps en los clones de `xcodebuild` y los XCUITest fallan con errores que no mencionan el disco (`RequestDenied (SBMainWorkspace)`). Ver TESTING-STRATEGY.md, 2026-07-24.

No preguntes. No hagas dry-run de espera. Informa en el cierre qué se borró y cuánto se recuperó.

Orden, alineado al teardown del puente (YalaAgent `session_teardown.py`):

1. Snapshots locales de Time Machine — **esto es lo que MÁS debe borrar**.
   - `tmutil listlocalsnapshots /`
   - por cada stamp: `tmutil deletelocalsnapshots <stamp>`
   - No uses `thinlocalsnapshots`. No inventes otro path. El script `session-cleanup.sh` no cubre TM.
2. `bash qa/scripts/disk-report.sh`
3. Aplica ya, sin confirmación:
   `bash qa/scripts/session-cleanup.sh --apply --clones --derived --scratch --sims-off`
   Eso borra DerivedData (`$HOME/Library/Developer/Xcode/DerivedData/*` y `$HOME/Library/Developer/XcodeBuildMCP/*`), scratchpads terminados (`/private/tmp/claude-501/*`, conserva sesión actual y mtime < 90 min), clones huérfanos, y apaga Simulator (`xcrun simctl shutdown all`).
4. Si el script no está, fallback ya medido en el puente: `xcrun simctl shutdown all` y `rm -rf` de esos dos DerivedData. No toques el repo ni `~/Secrets`.
5. `bash ~/.claude/scripts/limpiar-cowork.sh` — las carpetas de conversaciones de Cowork de más
   de 60 días y su caché. Es otro almacén, en el disco interno, que nadie recicla: en agosto había
   2 351 carpetas desde marzo, 5,9 GB. No pregunta y no falla; si no hay nada, dice «nada».

En el informe, una línea por destino (TM / DerivedData / scratch / clones / sims-off / Cowork) con GB o «nada». Si tras limpiar quedan < 25 GB, dilo. No ofrezcas saltarte DerivedData.

## 4 · Traspaso

Tres líneas, no más: **dónde quedó**, **qué sigue**, **qué está bloqueado esperando algo tuyo**.

## 5 · Escribir docs/ESTADO.md

Reescribir el archivo entero (no append). Tope 40 líneas.

Campos:
- Fecha (hoy, Lima)
- Rama y HEAD (`git rev-parse --abbrev-ref HEAD`, `git rev-parse --short HEAD`) + sujeto del último commit
- Tema de esta sesión (una línea, lenguaje de usuario)
- Abiertos: máx. 3 tickets que siguen vivos
- Siguiente: un item
- Bloqueo: uno, o “ninguno”

Si pasaría de 40 líneas, recortar Abiertos. No copiar DECISIONS. No listar el diff.

En el informe: `✓ docs/ESTADO.md <fecha> <HEAD>`

## Reglas

- Disco: ejecuta y listo. No pidas confirmación. El puente (YalaAgent) ya corre el mismo teardown al terminar cada orden, sin Claude; este comando es para cuando Claude sí lo corre.
- No commitees, no pushees, no cambies el estado de un ticket sin decirlo.
- Si la sesión no tocó código, salta el bloque 2: disco + ESTADO + cierre.
