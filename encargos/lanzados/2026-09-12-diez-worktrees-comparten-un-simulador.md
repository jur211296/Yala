# Serializar el gate XCUITest con lock de fichero (diez worktrees, un simulador)

## Contexto
Cola autónoma bypass (Jürgen). Acaba de cerrar #146 (cloud-killswitch). El high falso de Welcome (#145) era el simulador compartido: varias sesiones del gate apuntan al mismo iPhone 17 Pro, se pisan el `.app` y salen rojos que parecen de producto. Ticket: `tickets/backlog/diez-worktrees-comparten-un-simulador.md`. Ya hay detección (`sim-libre.sh --vigilar`); falta prevención.

## Decisión de producto (Jürgen 2026-09-11)
Opción **(2)**: **lock de fichero** (`flock` sobre lockfile compartido). La segunda sesión espera; no falla ni instala encima. **No** un simulador por worktree (la Mini no aguanta varios). **No** dejarlo solo en la guardia. Déjala escrita en ticket/PR/docs.

MODO AUTÓNOMO HASTA TERMINAR: gate, commit, board, actualizar `docs/TICKETS.md` (índice = disco), merge y `/cerrar-total` sin preguntar si corre el gate o el commit. Bugs/decisiones nuevas → ticket propio (`--solo-crear`) antes de cerrar. Solo parar ante decisión/acceso real.

Avisos al bot dueño (Frank): POSTea al webhook local de la Mini (URL y key en fichero local, no en git; no las escribas en el repo) cuando:
  (1) necesitas una decisión de producto o de acceso de Jürgen;
  (2) abriste el PR o dejaste preview/artifact listo;
  (3) terminaste el ticket y vas a /cerrar-total — incluye resumen corto de cierre en lenguaje de usuario;
  (4) acabaste un tramo y no tienes siguiente paso claro — una vez, no en bucle.
NO avises por: test rojo que vas a reclasificar, build a reintentar, ni CI advisory.

No lances el siguiente: Frank encadena. No marketing/.

## Que se pide
1. Leer el ticket + `.claude/rules/testing.md` + cómo el `/gate` elige destination y lanza XCUITest.
2. Implementar (2): lockfile compartido + `flock` (o equivalente robusto) alrededor del tramo que bootea/instala/corre XCUITest, de modo que dos sesiones concurrentes serialicen sin pisarse el bundle.
3. Medir con dos sesiones/procesos simultáneos (o el harness que ya tengáis): la segunda espera; ninguna instala encima de la otra; el centinela `--vigilar` sigue útil.
4. Actualizar ticket (decisión escrita, criterio de hecho), board/`docs/TICKETS.md`, PR a `2.1`, `/cerrar-total`.

## Que NO hay que tocar
marketing/. Clonar un simulador por worktree (opción 1). Cambiar el device-QA de producto. Wipe de prod. Paso 12 (`shell-derives`) salvo mínimo de docs si el board lo exige.

## Como se sabe que esta bien
Dos corridas concurrentes del gate no se derriban ni se pisan el `.app`; la segunda espera el lock; decisión (2) escrita; tests/gate en verde; PR mergeado a `2.1`; `/cerrar-total` con board e índice al día.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.
> La opción **(2) lock de fichero** ya venía decidida por Jürgen (2026-09-11); lo de abajo es cómo
> se implementa, que es lo que el encargo dejaba abierto.

**D1 · ¿Con qué se hace el lock, si `flock(1)` no existe en macOS?** → `python3` + `fcntl.flock`,
encadenando `exec` hasta el `xcodebuild`.
Por qué: medido hoy, `command -v flock` → vacío (es de util-linux). El lock del kernel lo **suelta
el kernel** cuando el proceso muere, incluso con `kill -9`, así que no hay huérfanos que limpiar; y
medido también que sobrevive al `exec`, que preserva el PID y que `os.set_inheritable(fd, True)` es
imprescindible (sin ella el fd lleva `O_CLOEXEC`, el lock se evapora en el `exec` y corren dos a la
vez **en silencio**). Alternativa descartada: `shlock(1)`, que sí está en macOS pero es PID-based —
deja el lock puesto si el dueño muere de golpe, y los PIDs se reciclan por debajo.

**D2 · ¿Dónde vive el lockfile?** → fuera del repo: `~/Library/Caches/Yala/simulador.lock`,
sobreescribible con `$YALA_SIM_LOCK`.
Por qué: cada worktree tiene su propio árbol de trabajo, así que un lockfile versionado serían
**catorce locks distintos** y ninguna cola. Alternativa descartada: `/tmp` y `$TMPDIR`, que macOS
limpia por antigüedad — si el fichero desaparece bajo un dueño vivo, el siguiente crea otro inodo y
se acabó la exclusión mutua.

**D3 · ¿Qué tramo cubre el lock: solo el XCUITest del paso 3?** → todo `xcodebuild … test` contra el
simulador: pasos 2 **y** 3 del `/gate`, y la batería de paridad de `/l10n-check`.
Por qué: `sim-libre.sh` ya trata cualquier `xcodebuild … test` como ocupación, sin mirar el scheme.
Serializar solo el paso 3 dejaría que el paso 2 de otra sesión hiciera cantar al centinela → rojo
falso y corrida repetida, que es exactamente lo que veníamos a quitar. Alternativa descartada: solo
el paso 3 (más corto, pero incoherente con el detector que ya existe).

**D4 · ¿La espera tiene tope?** → no por defecto; `--timeout <segs>` opcional, y al agotarse sale
**75 sin ejecutar el comando**.
Por qué: una corrida de XCUITest dura entre 3 y 40 min; un timeout corto convierte la cola en el
rojo que veníamos a evitar. Se avisa por stderr al entrar en cola y cada minuto. Alternativa
descartada: timeout por defecto — «lento» y «colgado» no se distinguen por el reloj.

**D5 · ¿Y el centinela `--vigilar`, ahora que hay lock?** → se queda, y se corrige: no cuenta
intrusos mientras el vigilado **hace cola**; empieza a medir cuando el vigilado aparece él mismo
como corrida de test.
Por qué: sin eso el centinela vería al dueño del lock como intruso y cantaría rojo en el caso
normal. Y sigue haciendo falta porque el lock **vive en el árbol de trabajo**: un worktree con rama
vieja, o un `xcodebuild` a mano, no hacen cola — el centinela es quien los caza. Si el vigilado
muere sin llegar a ejecutar, sale **2** («no vigilé nada»), nunca un ✓.

**D6 · ¿Se envuelve también el `/qa` de producto?** → no.
Por qué: el encargo lo deja fuera explícitamente, y es QA a mano con un humano delante; encolarlo
detrás de un gate de 40 min no ayuda a nadie.

**D7 · ¿Qué hace el script si falta `python3`?** → sale **2** y **no ejecuta el comando**.
Por qué: un candado que se salta a sí mismo cuando le falta una pieza produce justo la corrida sin
cola que venía a impedir, y encima invisible. Falla cerrado.

**D8 · ¿Banco de pruebas?** → sí, `qa/scripts/sim-lock-test.sh`, y lo corre el CI en el job
`coverage-index`.
Por qué: el precedente es el candado anti-atribución — «un candado sin banco de pruebas se relaja
sin que nadie lo note». Lleva **control negativo** (sin lock, los dos tramos SÍ solapan), que es lo
único que prueba que el positivo mide algo.

**D9 · ¿Esto es un ADR?** → no: la decisión vive en el ticket y la regla durable en
`.claude/rules/testing.md`.
Por qué: el `CLAUDE.md` de Yala fija dos superficies de documentación, no cinco, y este repo no usa
`decisions/` con el formato de casa.
