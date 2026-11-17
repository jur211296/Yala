Yala
# Cuarentena de pruebas inestables con dueño y línea «Verificado:» en cada commit
---
toca: qa/scripts/ci-reintentar-rojos.sh,qa/scripts/ci-reintentar-rojos-test.sh,qa/cuarentena.json,qa/scripts/cuarentena-test.sh,qa/scripts/precommit-gate.sh,qa/scripts/verificado-en-commit.sh,qa/scripts/verificado-en-commit-test.sh,qa/scripts/gate-ci-checks.sh,.github/workflows/qa.yml,.claude/commands/gate.md,.claude/settings.json,.claude/rules/ci-qa.md,.claude/rules/git-hooks.md,tickets/done/2026-11-17-verificacion-cuarentena-y-sello.md
esfuerzo: high
cierre: cierra-sola
---

## Qué hay que hacer
Dos propuestas chicas en un solo lote (un PR).

### P1, segunda parte: cuarentena con dueño
- `qa/cuarentena.json`: cada entrada con prueba, dueño, ticket, fecha de entrada y motivo. El CI la lee de `origin/2.3`, nunca del PR (un PR no puede meterse en cuarentena a sí mismo).
- `ci-reintentar-rojos.sh`: un rescate solo vale si la prueba está en la cuarentena. Rescatar una prueba que no está en la lista se marca. Los arranques fallidos del simulador se siguen repitiendo (infraestructura, no prueba).
- Modo **observar** dos semanas: el rescate fuera de lista se anota bien visible en el resumen del job y en el PR, sin poner el CI en rojo. Deja un interruptor de una línea para pasar a bloquear. Pasa a bloquear el 1-dic-2026 en una sesión corta aparte (no lo hagas tú ahora).
- A los 14 días en cuarentena sin arreglo, la prueba se borra con su porqué: deja el aviso automático (lista de vencidas en el resumen del job), no el borrado automático.
- Entradas iniciales: solo lo que hoy siga rescatándose de verdad (la familia de divisas se arregla en otra sesión; no la metas si ya está arreglada en `origin/2.3`).

### P3: cada commit dice cómo se verificó
- `/gate` guarda en el sello un resumen: `Verificado: build 2/2 · unit 14 suites · interfaz 6 clases · índice ✓`.
- Un hook (`prepare-commit-msg` o el `PreToolUse` actual) añade esa línea al mensaje del commit. Sin `.swift` en staging o sin gate: `Verificado: ninguno (solo docs)` o `Verificado: ninguno`. Añade, no bloquea.
- Banco de pruebas del script en el job `coverage-index` (como los demás `*-test.sh`).
- Actualiza `gate.md` y las reglas `ci-qa.md`/`git-hooks.md` con lo justo.
- Ticket en `tickets/done/2026-11-17-verificacion-cuarentena-y-sello.md`.

## Contexto
Propuesta de verificación del 17-nov (comparación con el equipo de Claude Code), aprobada por Jürgen el 17-nov: «Apliquemos todo lo recomendado». Fuente en `origin/2.3`: `docs/verificacion/README.md` y `docs/verificacion/propuesta-2026-11-17.html` (array `PROPUESTAS`). Artículo de referencia: https://claude.dev/blog/how-the-claude-code-team-thinks-about-verification/ . Lee la propuesta correspondiente entera antes de empezar; las mediciones de ahí son tu punto de partida, pero vuelve a medir lo que cambies.

## Reglas
- Commits y PR sin firma de IA. PR hacia `2.3`. Rama desde `origin/2.3`; justo antes del PR, `git fetch` y un solo rebase.
- Dependencias: la sesión arranca sobre `origin/2.3`, sin esperar CI ni merge del PR anterior; solo espera el merge si toca los mismos archivos o necesita el código de otra sesión (se indica abajo cuando aplica).
- `toca:` acotado: si necesitas tocar un archivo fuera de la lista, anótalo en el cierre con el motivo.
- Simuladores: en la Max puedes usar un segundo simulador si otra sesión ocupa uno (tope 2); también el iPhone 14 conectado por DeviceMCP.
- Nada de reglas, scripts ni workflows del gate que se lean del propio PR cuando la propuesta dice «leído de 2.3»: se leen de `origin/2.3`.
- Lo menor y reversible lo decides con la opción recomendada y lo anotas. Lo vital (accesos, credenciales, seguridad, ruleset distinto de lo aprobado, minutos de runner fuera de lo razonable) se pregunta, no se asume. Semi 05:30–20:00: preguntas y esperas con la sesión viva. Nocturno 20:00–05:30: checkpoint recuperable y card «Espera decisión» para Jürgen, sin mergear ni desplegar lo incompleto.
- Si el trabajo queda completo y el modo lo permite, termina con `/cerrar-total`.
- Entregable: artifact visual de Claude (antes/después, qué se midió, qué queda en observar y cuándo se promueve).
- El cierre incluye «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada una con motivo o «Nada», y una sección «Lección» si hubo un error evitable.

## Paso 0 — decisiones

> Resueltas por la sesión (semi, sin nadie delante): las recomendaciones se dan por buenas. Se discuten en el PR.

**Hechos medidos antes de decidir.** Desde el 10-nov, 338 corridas con job `tests`: 50 rescates en 47 corridas, los 50 de la familia `CurrencyConverter*` (7 casos) y 1 arranque fallido. El arreglo de esa familia (PR 1026) está abierto, no en `origin/2.3`. La huella del sello incluye `HEAD`. `prepare-commit-msg` corre también con `--no-verify`.

**D1 · ¿Qué entra en la cuarentena inicial?** → Los 7 casos de divisas, dueño frank, ticket del arreglo, entrada 17-nov. Por qué: son lo único que se rescata hoy y su arreglo no está en 2.3. Si el PR 1026 mergea antes que este, se quitan en el rebase. Descartada: lista vacía (en observar daría 47 avisos por ruido conocido).

**D2 · ¿Dónde vive el interruptor observar/bloquear?** → En `_meta.modo` de `qa/cuarentena.json`, leído de 2.3. Por qué: una línea, y un PR no puede apagarlo para sí mismo. Descartada: variable en `qa.yml` (la leería del PR).

**D3 · ¿Qué pasa si la cuarentena de 2.3 no existe o no se puede leer?** → Lista vacía y modo observar, con un aviso visible. Por qué: en el CI de este mismo PR el fichero aún no está en 2.3; y en observar no cambia nada. La sesión que promueva a bloquear el 1-dic decide si «ilegible» debe bloquear. Descartada: bloquear al no leer (pondría rojo el CI durante observar).

**D4 · ¿Una entrada puede cubrir una suite entera?** → Sí: `YalaTests/Suite` cubre sus casos. Por qué: una familia rota entera se apunta sin 7 líneas. El caso suelto sigue siendo lo normal.

**D5 · «En el PR»: ¿comentario o anotación?** → Anotación de GitHub (sale en la pestaña de checks del PR) + resumen del job. Por qué: un comentario pide `pull-requests: write`, un permiso nuevo en el workflow. Descartada: comentario fijo en el PR.

**D6 · Vencidas** → Paso propio en el job `tests` que lista las vencidas (≥14 días) en el resumen del job y como aviso; no borra nada. Por qué: lo pide el encargo y no se duplica en los dos pasos de unit.

**D7 · Lógica de la cuarentena: ¿script nuevo o dentro de `ci-reintentar-rojos.sh`?** → Dentro (`--cuarentena`, `--informe-cuarentena`, `--validar-cuarentena`), con su banco en `cuarentena-test.sh`. Por qué: una sola fuente para leer el fichero; los dos están en `toca:`.

**D8 · ¿Hook de la línea `Verificado:`?** → `prepare-commit-msg` en `.githooks/` (fuera de `toca:`, se anota). Por qué: cubre los commits de terminal y de Xcode y corre incluso con `--no-verify`; el `PreToolUse` no puede reescribir el mensaje. No se toca `.claude/settings.json`.

**D9 · Formato del sello** → Línea 1 la huella (como hoy), línea 2 `Verificado: …`. `precommit-gate.sh` lee solo la línea 1; un sello viejo de una línea sigue valiendo y da `Verificado: gate ✓ (sin resumen)`. El resumen lo compone `verificado-en-commit.sh sellar --build N --unit N --interfaz N --indice si|no`, con formato fijo y contable.

**D10 · ¿Qué línea en cada caso?** → Sello que casa con el árbol: su línea. Sin sello válido: `Verificado: ninguno (solo docs)` si todo lo staged es `docs/`, `tickets/`, `*.md` o `LICENSE*`; si no, `Verificado: ninguno`. En `--amend`/`-c` con una línea ya escrita y sin sello válido, se respeta la existente (la huella se movió con HEAD). Merge y squash no se tocan. El hook nunca falla el commit.

**D11 · Varios commits tras un gate** → `verificado-en-commit.sh resellar` recalcula la huella y conserva el resumen. Por qué: la memoria ya documenta re-sellar entre commits de una tanda; sin esto el segundo commit perdería el resumen.

**D12 · ¿El script de reintento también se lee de 2.3?** → No en este lote: solo la lista. Por qué: es lo que pide el encargo; leer los scripts de 2.3 es P4. Se anota en «Encontrado».
