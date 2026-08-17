---
description: Cierra la sesión — verifica que nada quedó abierto, sincroniza el ticket y libera el disco que dejaron los simuladores y los builds
allowed-tools: Bash(git:*), Bash(bash qa/scripts/disk-report.sh:*), Bash(bash qa/scripts/session-cleanup.sh:*), Bash(xcrun simctl:*), Bash(pgrep:*), Read, Edit, Glob, Grep
---

Cierre de sesión de Yala. Cuatro bloques, en este orden. Preséntalos como un solo informe al final; no narres cada paso.

## 1 · Nada quedó abierto

- Procesos de build vivos (`pgrep -f "xcodebuild"`), simuladores arrancados, tareas en background de esta sesión.
- `git status --porcelain` y `git log @{u}..HEAD --oneline`.

Si hay cambios sin commitear, **pregunta**: commitear con `/commit-one`, o dejarlos como WIP declarado. Nunca commitees por tu cuenta en el cierre. El hook `Stop` ya pushea lo que esté commiteado — no lo dupliques.

## 2 · Documentación mínima

Solo dos superficies. Si ya están al día, dilo en una línea y sigue.

- **El ticket** en `$VAULT/Backlog/` o `$VAULT/Bugs/` del trabajo de esta sesión: ¿refleja lo hecho y su estado? Si pasó a QA, prefijo `qa_` + `status: needs-testing`.
- **`qa/coverage-index.json`**: obligatorio solo si se tocó código bajo `Yala/`. Actualiza `lastVerified` de las áreas afectadas y corre `bash qa/validate-coverage.sh`.

Una regla nueva y duradera va a `.claude/rules/` o a CLAUDE.md — pero eso pasa una vez cada muchas sesiones, no en cada cierre. No inventes una para tener algo que escribir.

## 3 · Disco

**Esto es lo que evita el fallo que cuesta horas.** Con el disco casi lleno CoreSimulator no consigue lanzar apps en los clones de `xcodebuild`, y los XCUITest fallan con errores que no mencionan el disco (`RequestDenied (SBMainWorkspace)`). Ese síntoma ya se diagnosticó mal una vez durante 11 días — ver la entrada cerrada del 2026-07-24 en TESTING-STRATEGY.md.

1. `bash qa/scripts/disk-report.sh`
2. `bash qa/scripts/session-cleanup.sh` — dry-run, enumera y mide sin borrar.
3. Muestra al usuario **qué se recuperaría y cuánto**, agrupado por destino.
4. Aplica **solo lo que confirme**, con los flags correspondientes:
   `bash qa/scripts/session-cleanup.sh --apply --clones --derived --scratch --worktrees --sims-off`

Notas que el script ya respeta pero conviene decir en el informe:
- Los scratchpads con actividad reciente se conservan — puede haber **otra sesión tuya abierta** en paralelo.
- Los worktrees con rama (no detached) se conservan.
- Borrar DerivedData cuesta un recompilado completo (~8 min) la próxima vez. Si vas a seguir trabajando en un rato, ofrécelo pero no lo empujes.

Si tras limpiar siguen quedando menos de 25 GB, dilo explícitamente y señala al simulador más pesado (`simctl erase <udid>` lo devuelve a cero, perdiendo apps y datos sembrados).

## 4 · Traspaso

Tres líneas, no más: **dónde quedó**, **qué sigue**, **qué está bloqueado esperando algo tuyo** (device-QA pendiente, decisión sin tomar, cola de tickets en `qa_`).

## Reglas

- Nada se borra sin confirmación explícita del usuario, ni siquiera lo obvio.
- No commitees, no pushees, no cambies el estado de un ticket sin decirlo.
- Si la sesión no tocó código (fue exploración o conversación), salta los bloques 2 y 4: informe de disco y cierre.

## 5 · Escribir planning/NOW.md

Reescribir el archivo entero (no append). Tope 40 líneas.

Campos:
- Fecha (hoy, Lima)
- Rama y HEAD (`git rev-parse --abbrev-ref HEAD`, `git rev-parse --short HEAD`) + sujeto del último commit
- Tema de esta sesión (una línea, lenguaje de usuario)
- Abiertos: máx. 3 tickets que siguen vivos
- Siguiente: un item
- Bloqueo: uno, o “ninguno”

Si el archivo pasaría de 40 líneas, recortar Abiertos. No copiar STATE. No listar el diff.

En el informe de /cerrar, una línea: `✓ NOW.md <fecha> <HEAD>`
