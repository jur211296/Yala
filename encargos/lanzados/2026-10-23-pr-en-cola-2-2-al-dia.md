# Poner al día los cuatro PR a 2.2 que quedaron atascados por el CI y resolver los conflictos de #576 y #571

## Contexto
Anoche el job `tests` del CI no podía crear el simulador (imagen nueva de GitHub con iOS 27.1). El PR #603 lo arregló y ya está mergeado en 2.2 (10-23 05:08 Lima). Pero los PR que estaban en cola no recogen el arreglo con un rerun: GitHub reusa su merge viejo con la base (lo documenta el PR #604, en cola). Estado ahora:
- #602 «Formulario de registro: textos y visual (lote decidido 2.2 · 02, sesión B)» y #601 «fix(pro): renovar desde «Tu suscripción terminó» deja Pro a la primera»: BLOCKED, sin conflictos; necesitan traer 2.2 a su rama para que el CI corra con el arreglo.
- #576 «Lote decidido 2.2 · 08 — widgets, iPad, teclado…» y #571 «Yala IA con un solo nombre… (lote decidido 2.2 · 07)»: DIRTY, tienen conflictos con 2.2 además del CI viejo.
Son cuatro entregas ya hechas y aprobadas que no entran a 2.2. La próxima sesión de la cola (Grupos) no debe empezar sobre una 2.2 a la que le faltan estos lotes.

## Qué se pide
1. #602 y #601: `gh pr update-branch` (merge de 2.2 en la rama, sin force-push) y vigilar que su CI pase con el arreglo y entren por su auto-merge. Si el CI falla por otra razón, arreglar lo mínimo en esa rama si es claro; si no, anotarlo en el cierre.
2. #576 y #571, uno detrás de otro (primero el que menos choque, y el segundo sobre la 2.2 que ya incluya al primero si entró): traer origin/2.2 a la rama del PR con merge (sin reescribir historia ni force-push, salvo que CLAUDE.md del repo diga otra cosa), resolver los conflictos de Swift, traducciones (Localizable / xcstrings) y tests respetando lo que ya está en 2.2 y lo que trae el PR. Build y tests en el simulador, push, y que entren por su auto-merge.
3. Si un conflicto pide una decisión de producto (dos textos o diseños distintos aprobados para lo mismo), no inventarla: elegir lo que está en 2.2 si es lo más reciente aprobado, y listar el caso en «Necesita de ti».
4. Cards: si encuentras cards de esos lotes cuyo estado cambia por esto, moverlas con `tablero` (`--agente frank`); no crear trabajo nuevo fuera de esto salvo tickets de lo que encuentres.

## Qué NO hay que tocar
- No cambiar el alcance de ninguno de los cuatro PR ni meterles mejoras.
- No desactivar tests, no marcar checks como no requeridos, no saltarse protecciones de rama.
- No tocar la sesión viva «pendientes-de-jurgen-2-2» ni su worktree.

## Cómo se sabe que está bien
Los cuatro PR están mergeados en 2.2 (o, el que no, con la causa concreta en el cierre) y 2.2 compila y pasa los tests.

## Mini
La Mini va justa (~22 GB libres, umbral 32 GB): al arrancar, limpiar sin preguntar sims muertos, DerivedData de sesiones cerradas y cachés de XcodeBuildMCP de worktrees que ya no existen. Pipeline serial de Yala: build con `xcodebuild -jobs 2` sin sim booteado, luego un solo simulador para tests, y al cerrar apagar y borrar ese sim. Al cerrar, borrar el DerivedData de esta sesión. No tocar los de la sesión viva «pendientes-de-jurgen-2-2».

## Paso 0

Decisiones tomadas sin preguntar (ninguna era de producto):

- **Orden de los dos con choque: #571 primero.** 19 ficheros en conflicto frente a 20, y un solo commit. #576 se hizo después sobre la 2.2 que ya traía #571 (y #601).
- **Choques de texto: unión clave a clave, 3-way contra la base.** Donde los dos lados cambiaban la misma clave distinto habría ganado 2.2 y se listaría; no hubo ninguno.
- **`DraftDiscardUndoNotice`**: 2.2 y #571 añadían cada uno su marca del aviso visible; se queda la de 2.2 y la retirada por id de #571 la usa. En #576, el ⌘Z solo se arma si el aviso tiene «Deshacer» (2.2 lo hizo opcional).
- **#602 cayó en el CI por otra razón, clara y mínima**: tres tests suyos exigían que la divisa principal no fuera USD, y en el runner lo es. Se arregla fijando PEN en esos tests, sin tocar la app. Reproducido en local antes y después.
- **Cards**: las de esos lotes ya están en «in qa» con Jürgen; el merge no les cambia el estado y no se mueven.
- **Simulador propio** para los tests («Yala PR al dia»), creado y borrado en la sesión, para no pisar el de la sesión viva.

/cerrar-total
