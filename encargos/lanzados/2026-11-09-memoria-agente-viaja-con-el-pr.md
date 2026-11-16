---
esfuerzo: high
toca: .claude/commands/,scripts/
release: no
---

# La memoria de agente viaja con el PR de cada sesión al cerrar

## Contexto
Claude Code escribe la memoria `project` del agente (por ejemplo `.claude/agent-memory/frank/`) en el checkout PRINCIPAL de `~/Yala`, aunque la sesión corra en un worktree de `~/Claude/worktrees/Yala-…`. En Yala esa memoria está versionada (unos 444 archivos), así que el checkout principal queda sucio. El 6 y el 9 de noviembre de 2026 eso frenó el `git pull --ff-only` previo de `lanzar-sesion`. Casa ya quitó el síntoma: el pull aparta la memoria (ADR-095 de casa, punto 6, en `~/Claude/casa/decisions/0095-un-arranque-rechazado-es-un-fallido-limpio-la-memori.md`). La causa de fondo sigue: la memoria solo llega a git cuando alguna sesión la commitea a mano.

Decisión de Jürgen (9-nov-2026, registrada con la clave `chat-rob-t327u`): la opción (a) de la sección «Propuesta, no implementada» de ese ADR. Al cerrar, cada sesión copia al worktree los cambios de `.claude/agent-memory/<agente>/` del checkout principal y los commitea en su PR, pero SOLO los archivos que tocó esa sesión, para no arrastrar notas de otra sesión viva del mismo agente.

## Qué se pide
1. Lee el ADR-095 de casa completo y el `/cerrar` del repo (`.claude/commands/cerrar.md`). Ubica también dónde vive el cierre total (`/cerrar-total`) y qué paso hace el commit y el PR.
2. Implementa en el cierre un paso que:
   - detecte qué archivos de `.claude/agent-memory/<agente>/` del checkout principal creó o modificó ESTA sesión. Usa un criterio verificable, no adivinado: por ejemplo, una marca de arranque guardada al abrir la sesión (lista con huella y mtime de esos archivos) y compararla al cerrar. Elige y justifica el mejor criterio;
   - copie solo esos archivos al worktree y los incluya en el commit del PR;
   - deje intactos en el checkout principal los archivos de otras sesiones;
   - devuelva el checkout principal a limpio en esos archivos, una vez que ya estén en el PR, sin perder nada y sin `git stash`, porque la pila es compartida entre worktrees;
   - ante cualquier duda o conflicto, no copie ni borre nada: lo anote en el cuerpo del PR y siga con el cierre.
3. Agrega pruebas automatizadas del paso, al menos para tres casos: una sesión que tocó notas, una que no tocó ninguna y dos sesiones del mismo agente vivas a la vez.
4. Documenta el comportamiento donde corresponda en el repo.

## Qué NO hay que tocar
- El código de la app (`Yala/App/…`) y los tests de la app.
- `marketing/`.
- La memoria existente: no borres ni reescribas notas, solo muévelas al PR.
- Los scripts de casa (`~/.claude/scripts`, `lanzar-sesion`, el coordinador): son de otro repo. Si ves que hace falta un cambio allí, déjalo descrito en el PR.
- No hace falta simulador. Si por algo lo necesitaras, en la Mini el tope es uno.
- Commits y PR sin firma de IA.

## Cómo se sabe que está bien
- Las pruebas pasan, incluidos los tres casos.
- En un cierre de prueba, el PR incluye solo las notas que tocó la sesión, y el checkout principal queda limpio en esas rutas.
- Las notas de otra sesión viva siguen sin tocar en el checkout principal.
- El cuerpo del PR explica el criterio elegido y cómo se recupera una nota si algo falla.

## Paso 0

**Medido antes de decidir (9-nov, Claude Code 2.1.319).** En los transcripts de ~100 sesiones de
worktree de Yala, Claude Code declara la memoria de Frank **en el worktree**
(`<worktree>/.claude/agent-memory/frank/`), no en el checkout principal, y casi todas las
escrituras caen ahí. Las notas sueltas del principal llegaron porque **la propia sesión las movió a
mano** (`cp … /Users/jur/Yala/…` + `printf >> …/MEMORY.md`), o con un `Write` a la ruta absoluta del
principal. La premisa del encargo vale para el síntoma, no para la causa. El paso cubre los dos orígenes.

Decisiones (auto-contestadas, modo semi; ninguna es vital):

1. **Criterio de «la tocó esta sesión»: el transcript de la propia sesión, no una marca de arranque.**
   - Una marca de arranque dice «cambió desde que empecé», y eso incluye lo que escribió otra sesión
     viva del mismo agente: falla justo el caso 3. Además exige un hook de `SessionStart`, fuera del `toca:`.
   - Los JSONL de `~/.claude/projects/<worktree-codificado>/` los escribe Claude Code por sesión y
     traen cada `Write`/`Edit` con su ruta, y cada `Bash` con su texto y la hora de su resultado.
   - Prueba propia: `Write`/`Edit`/`MultiEdit` a esa ruta, o un `Bash` que nombra la raíz del
     principal y el nombre de la nota.
   - Guarda de concurrencia: si el transcript de **otra** sesión activa desde que empezó ésta trae
     la misma prueba sobre la nota, o el archivo cambió después de la última prueba propia → duda:
     no se copia ni se borra, se anota.
2. **Lo del worktree es de esta sesión por construcción** (worktree e índice propios): todo cambio
   bajo `.claude/agent-memory/<agente>/` del worktree entra al commit.
3. **`MEMORY.md` se lleva por líneas, no entero.** Una línea añadida al índice del principal es de
   quien es dueño de la nota a la que enlaza. Se llevan solo esas; las de otras sesiones se quedan.
4. **Dos fases.** `llevar` copia y commitea en la rama; `limpiar`, tras el push, comprueba que la rama
   remota tiene cada blob y solo entonces devuelve el principal a limpio en esas rutas
   (`git restore --source=HEAD`, borrar las no versionadas, quitar las líneas del índice).
   Antes deja respaldo en `~/Claude/flota/memoria-apartada/Yala/`. Sin `git stash`.
5. **Dónde se engancha.** `/cerrar` (bloque 0, worktree) y una línea en la cadena autónoma del
   `CLAUDE.md`, porque `/cerrar-total` es de casa y no llama a `/cerrar`. El cambio en
   `/cerrar-total` (correr el paso si el repo trae el script) queda descrito en el PR, no hecho.
   Asumido: tocar `CLAUDE.md` (una línea), fuera del `toca:`; nadie vivo lo toca.
6. **Choque avisado con la sesión de login** en `.claude/commands/`: su rama toca `gate.md` y
   `l10n-check.md`; aquí solo `cerrar.md`. Sin fichero común: se sigue.
