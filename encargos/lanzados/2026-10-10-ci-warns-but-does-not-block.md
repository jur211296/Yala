---
esfuerzo: high
---
# El CI avisa de los tests en rojo pero no los bloquea, y el auto-merge mergea con unit en rojo

**Card:** `tablero-el-ci-avisa-de-los-tests-en-rojo-pero-no-e90b` · **Ticket:** `tickets/backlog/ci-warns-but-does-not-block.md`

## Decisión (delegada por Jürgen, 2026-10-10)
Lo más robusto: **el auto-merge nunca mergea con unit tests en rojo**, sin bajar la velocidad de los PR verdes. Jürgen delegó las decisiones técnicas en Frank y prefiere siempre lo más robusto.

## Estado (del triage)
El paso 4 del ticket ya está hecho (UI a la nocturna, `6a9df9898`). El paso 3 sigue vivo: los tres pasos de test del workflow siguen con `continue-on-error` y el check `tests` del ruleset sale verde aunque fallen.

## Que se pide
1. Quitar `continue-on-error` de los pasos de unit tests (pure-logic y los que corran en PR) para que el check `tests` salga rojo si fallan. Los UI tests advisory y la nocturna se quedan como están.
2. Comprobar que `tests` es check requerido del ruleset de `2.1` (léelo con `gh api repos/jur211296/Yala/rulesets`; si falta, deja el cambio exacto anotado en el PR y en el cierre para que Frank lo aplique: no cambies rulesets ni protección de rama desde la sesión).
3. No bajar la velocidad de los PR verdes: sin pasos nuevos en serie que alarguen el job; si hay flakies conocidos que pasarían a bloquear, márcalos con su ticket y reintento acotado (no `continue-on-error` global).
4. Mientras arreglas, si algún unit test ya está en rojo en 2.1, arréglalo o abre ticket (no lo silencies).
5. Prueba: un PR de prueba (o rama) con un unit test roto a propósito ⇒ `tests` rojo y el auto-merge no mergea; revertido ⇒ verde. Deja los enlaces de las corridas en el PR. Borra la rama de prueba al terminar.
6. Actualiza el doc o regla de CI que describa el comportamiento (`.claude/rules/` o `docs/`).

## Reglas de siempre
- Arranca sobre `origin/2.1`. Lee primero el ticket entero y comprueba que el problema sigue vivo en 2.1 (mídelo); si ya no lo está, dilo en el PR y cierra el ticket.
- Test que falle con el código viejo y pase con el nuevo (control rojo), en las dos direcciones; mutante verificado.
- `/gate`: builds `Yala` y `Yala Dev`, unit de las áreas tocadas y XCUITest solo de las pantallas tocadas, con un solo simulador.
- Rebase al final, sin esperar a nadie: justo antes de abrir el PR, `git fetch` y rebase sobre `origin/2.1`, resolviendo ahí cualquier conflicto (strict=false). Si el rebase trae cambios que tocan lo tuyo, vuelve a compilar y repetir los tests afectados.
- Tickets nuevos al tablero (antes del `/cerrar-total`): por cada ticket nuevo que abra esta sesión en `tickets/`, mira primero con `tablero listar --proyecto Yala --todas` que no tenga ya card y, si no la tiene, créala: `tablero crear --proyecto Yala --agente frank --asignado frank --estado backlog --prioridad <la del ticket> --titulo "<título claro en español neutro>" --contexto "<una línea>" --enlace "Ticket|https://github.com/jur211296/Yala/blob/2.1/tickets/backlog/<slug>.md" --enlace "PR #<N>|<url del PR>"`. Lista esas cards (título e id) en el aviso de cierre. Va SIN --fecha (la fecha de las cards es opcional desde el ADR-068; no pongas fecha de relleno).
- Cierre: `/cerrar-total` autónomo (PR a 2.1 con auto-merge, card tablero-el-ci-avisa-de-los-tests-en-rojo-pero-no-e90b a «in qa» con jurgen si queda device-QA o a «done» con frank si no; limpiar worktree, tmux, DerivedData y cachés; ningún simulador encendido). Antes/después en el PR (capturas si hay cambio visible).
- Decisiones técnicas: Jürgen las delegó; elige siempre la opción más robusta y anótala en el Paso 0 del encargo.

## Carga de la Mini (OBLIGATORIO)
El puente de Grok Bot se cae con los picos de carga de Xcode (llegó a 17). Por eso:
- Todo `xcodebuild` (build y test) va como `nice -n 10 xcodebuild -jobs 2 ...`.
- Nunca corras dos builds o tests a la vez (ni en paralelo ni en segundo plano).
- Antes de cada build o test, espera a que la carga de 1 minuto baje de 8: `while [ $(sysctl -n vm.loadavg | awk '{print int($2)}') -ge 8 ]; do sleep 30; done`.
- No filtres la salida de xcodebuild con `| head` (corta la tubería y mata el build): escribe a un log y busca en él.
- En zsh, los `-only-testing:` van en un array, no en una variable de texto.

## Paso 0 — decisiones (resueltas en autónomo (bypass))

1. **¿Sigue vivo?** Sí, medido en `origin/2.1` (59ae96b54): `continue-on-error: true` en los pasos `unit_pure` y `unit_context` de `qa.yml`, y el ruleset `2.1 exige tests y coverage-index` pide `tests`, `coverage-index` y `gateway` (leído con `gh api …/rulesets/24270515`). No hay que tocar el ruleset.
2. **Qué se promueve.** Los dos pasos de unit del job `tests` (pure-logic y context-based), que son los únicos que corren en PR. La UI (job `ui`, solo nocturna) sigue advisory, como pide el encargo.
3. **Flakies conocidos.** Pure-logic ya repite solo sus rojos (`ci-reintentar-rojos.sh`, 3 vueltas). Context-based usaba `-retry-tests-on-failure`, que con Swift Testing repite la selección entera: pasa al mismo script. Es el reintento acotado del encargo y no añade ningún paso. `SpikeR3ContainerReleaseTests` (ticket `spike-r3-eje-4b-flaky-en-suite-completa`) queda nombrado en el comentario del paso como flaky conocido que cubre ese reintento.
4. **Context-based corre aunque pure-logic falle** (`if: !cancelled() && build ok`). Sin eso, el rojo de pure-logic lo saltaría y el aviso lo leería como «la suite no llegó a correr». Solo cuesta minutos en las corridas que ya están en rojo.
5. **El aviso se queda** como canal a Grok, con el texto corregido: un rojo de unit ya pone `tests` en rojo y frena el auto-merge; solo la UI sigue sin frenar.
6. **Red contra la regresión.** Banco nuevo `qa/scripts/ci-unit-bloqueante-test.sh` en el job `coverage-index` (también requerido, corre en paralelo): falla si un paso de test del job `tests` vuelve a llevar `continue-on-error` o `-retry-tests-on-failure`. Mutantes dentro del propio banco.
7. **Prueba de punta a punta.** PR borrador de una rama `prueba/…` con un unit roto a propósito y auto-merge pedido: `tests` rojo y sin merge; revertido, verde. Se cierra sin mergear y se borra la rama.
8. **El EXC_BREAKPOINT de SwiftData** que justificaba lo advisory: se mide en el historial de Actions, no se supone. Los comentarios de `qa.yml` que lo daban por vivo y citaban `TESTING-STRATEGY.md` (que no existe) se reescriben con lo medido.
