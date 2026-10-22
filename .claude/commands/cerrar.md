---
description: Cierra la sesión — verifica que nada quedó abierto, sincroniza el ticket, deja el parte donde se lee y libera el disco sin preguntar
allowed-tools: Bash(git:*), Bash(gh:*), Bash(tablero:*), Bash(python3 scripts/indice_readme.py:*), Bash(python3 scripts/glosario.py:*), Bash(bash qa/scripts/disk-report.sh:*), Bash(bash qa/scripts/session-cleanup.sh:*), Bash(xcrun simctl:*), Bash(tmutil:*), Bash(pgrep:*), Read, Edit, Glob, Grep, Bash(bash ~/.claude/scripts/limpiar-cowork.sh:*)
---

Cierre de sesión de Yala. Cinco bloques, en este orden. Un solo informe al final; no narres cada paso. No preguntes. Tras reportar, ejecuta y listo.

## 0 · ¿Corre esta sesión en un worktree? — **compruébalo antes de escribir nada**

`git rev-parse --git-common-dir` distinto de `.git` significa que sí: la lanzó `lanzar-sesion`
en `~/Claude/worktrees/`, sobre una rama `encargo/<slug>`. **El árbol principal es de Jürgen.**

- **El ticket va aquí** — es un fichero por ticket y no colisiona.
- **Pushea tu rama y abre PR** con `gh pr create`, con el parte del bloque 5 en el cuerpo. Es lo
  que leerá el próximo `/abrir`: no hay otro sitio donde quede.
- El hook `Stop` respeta el worktree desde el 1-sep (`CLAUDE_PROJECT_DIR`), pero comprueba que
  pusheó tu rama y no otra.

## 1 · Nada quedó abierto

- Procesos de build vivos (`pgrep -f "xcodebuild"`), simuladores arrancados, tareas en background de esta sesión.
- `git status --porcelain` y `git log @{u}..HEAD --oneline`.

Si hay cambios sin commitear: decláralos WIP en el informe y sigue. Nunca preguntes. Nunca commitees en el cierre. El hook `Stop` ya pushea lo commiteado — no lo dupliques.

## 2 · Documentación mínima

Solo dos superficies. Si ya están al día, dilo en una línea y sigue.

- **El ticket** en `tickets/` del trabajo de esta sesión: ¿refleja lo hecho y su estado? Si pasó a QA, muévelo a `tickets/qa/` y `status: qa`.
- **`README.md`**: solo si esta sesión creó o movió un documento de `docs/`. `python3 scripts/indice_readme.py --repo . --apply` regenera el índice de entrada; si no existe el fichero que enlazaba, la fila pasa a **pendiente** en vez de quedarse rota.
- **`docs/glosario.md`**: solo si esta sesión añadió decisiones. `python3 scripts/glosario.py --repo . --apply` reescribe el bloque generado (término → dónde se decide) y deja intacta la cabecera a mano. Si no se tocó `DECISIONS.md`, no hay nada que hacer.
- **`qa/coverage-index.json`**: obligatorio solo si se tocó código bajo `Yala/`. Actualiza `lastVerified` de las áreas afectadas y corre `bash qa/validate-coverage.sh`.

Una regla nueva y duradera va a `.claude/rules/` o a CLAUDE.md — una vez cada muchas sesiones, no en cada cierre. No inventes una para tener algo que escribir.

## 3 · Disco (fire-and-forget)

**Esto es lo que evita el fallo que cuesta horas.** Con el disco casi lleno CoreSimulator no lanza apps en los clones de `xcodebuild` y los XCUITest fallan con errores que no mencionan el disco (`RequestDenied (SBMainWorkspace)`). Ver TESTING-STRATEGY.md, 2026-07-24.

No preguntes. No hagas dry-run de espera. Informa en el cierre qué se borró y cuánto se recuperó.

Orden, alineado al teardown del puente (YalaAgent `session_teardown.py`):

1. Snapshots locales de Time Machine — **esto es lo que MÁS debe borrar**.
   - `tmutil listlocalsnapshots /` lista nombres completos: `com.apple.TimeMachine.2026-09-01-073242.local`
   - **`deletelocalsnapshots` NO acepta ese nombre**: quiere solo la fecha. Pasarle el nombre
     entero falla con `is not a valid disk` (POSIX 22) en todos, y una sesión que siga la receta
     al pie de la letra se queda sin borrar nada creyendo que borró. Medido el 2026-09-01.
   - Por cada uno, recortando el prefijo y el sufijo:

     ```bash
     for s in $(tmutil listlocalsnapshots / | grep com.apple.TimeMachine | sed -E 's/com\.apple\.TimeMachine\.(.*)\.local/\1/'); do tmutil deletelocalsnapshots "$s"; done
     ```

   - Cada borrado responde `Deleted local snapshot '<fecha>'`. Si dice otra cosa, no borró.
   - No uses `thinlocalsnapshots`. El script `session-cleanup.sh` no cubre TM.
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

## 5 · El parte, donde se lee

**Yala no tiene fichero de estado desde el 2026-09-30** (ADR-053 de casa). Un fichero que toda
sesión reescribe no sobrevive al auto-merge: la sesión cierra antes de su merge, la siguiente nace
sin su cambio y los dos PRs chocan en él. Cada cosa va a donde ya se escribe sola:

| Qué | Dónde |
|---|---|
| La crónica de la sesión | **Worktree:** el cuerpo del PR. **Árbol principal:** el cuerpo del commit a `2.1` |
| Lo que espera de Jürgen (decisión, tarea, credencial) | Una tarjeta: `tablero crear --proyecto Yala --asignado jurgen --titulo "…" --fecha hoy --nota "…" --agente frank` |
| Un device-QA | El ticket en `tickets/qa/` con su guion. **No** lleva tarjeta: el ticket ya es su registro |
| Un aviso que toda sesión debe saber | `CLAUDE.md` o la regla de `.claude/rules/` de su área |

El cuerpo del PR lleva estas secciones, **en este orden**, para que `/abrir` las encuentre:

1. `## Necesita de ti` — lo que queda en Jürgen, o «nada». Cada punto con su tarjeta o su ticket.
2. `## Qué cambia para el usuario` — en lenguaje de usuario.
3. `## Qué toqué`
4. `## Qué probé`
5. `## Qué quedó fuera` — con el ticket de cada residual.

El número de build de TestFlight no se escribe en ningún sitio: Jürgen lo mira al subir.

En el informe: `✓ parte en PR #N` (o `en el commit <sha>`) y `✓ N tarjeta(s) para Jürgen`, o «ninguna».

## 6 · La fila de actividad

Lo último: la sesión **deja su fila en el panel** (ADR-037 de casa), con el mismo resumen que
acabas de escribir:

```bash
python3 ~/.claude/hooks/emitir_actividad.py --cerrar \
  --titulo "Una línea de qué se hizo" --resumen "Las mismas dos o tres frases" --estado hecho
```

`--estado fallido` si la sesión termina sin lo que venía a hacer, y `esperando-a-jurgen` si cede a
medias. **El hook no lo deduce**: aquí es el único sitio donde eso se sabe.

**En el título y el resumen no van datos de cliente**, igual que en cualquier entregable: la fila
cuenta qué se hizo, no con qué.

**Terminado cuando el comando contesta `actividad: encolada`**; el `POST` sale en un proceso
aparte y su resultado va a `~/.claude/logs/actividad.log`. Saltarse este paso deja la fila igual
—la escribe el `SessionEnd`— pero con el primer prompt de título y sin resumen.

## Reglas

- Disco: ejecuta y listo. No pidas confirmación. El puente (YalaAgent) ya corre el mismo teardown al terminar cada orden, sin Claude; este comando es para cuando Claude sí lo corre.
- No commitees, no pushees, no cambies el estado de un ticket sin decirlo.
- Si la sesión no tocó código, salta el bloque 2: disco + parte + cierre.
