---
description: Gate único antes de commitear — build, unit, XCUITest de las áreas tocadas, audit de calidad y validación del índice de QA
allowed-tools: Bash(git:*), Bash(xcodebuild:*), Bash(bash qa/scripts/sim-lock.sh:*), Bash(bash qa/scripts/sim-libre.sh:*), Bash(bash qa/validate-coverage.sh:*), Bash(bash qa/scripts/gate-ci-checks.sh:*), Bash(python3 -I qa/scripts/suites-de-fichero.py:*), Bash(touch:*), Bash(bash qa/scripts/worktree-stamp.sh:*), Bash(python3 qa/qa-sync.py:*), Bash(grep:*), Bash(jq:*), Read, Glob, Grep
---

Verificación completa de los cambios actuales. Sustituye a `/verify-ios` + `/test-smart` + `/swift-audit` corridos por separado. Un solo informe; el commit se apoya en él.

Alcance = archivos modificados (staged + unstaged + sin trackear):

```bash
git status --porcelain | grep -v '^D ' | awk '{print $NF}' | sort -u
```

**Los pasos 1-3 corren si hay `.swift` MODIFICADOS o si cambió algo que altera cómo se construye o se verifica el proyecto**: `*.xcscheme`, `*.pbxproj`, `*.xcconfig`, `Package.resolved`, `qa/scripts/*.sh`, o los hooks de `.claude/settings.json`.

Esa segunda mitad no es teórica: la primera corrida de este comando iba a saltarse build y tests ante un cambio de `parallelizable` en los dos schemes — justo el fichero que decide cómo se ejecutan los tests. Un gate que no verifica su propia infraestructura no es un gate.

Si solo cambió documentación o markdown, salta al paso 5.

## 1 · Build

Las dos schemes, porque `Yala Dev` compila con `DEV_BUILD` y `Debug-Dev` y ha ocultado errores que solo salían en producción.

**Antes de cada build, `touch` de los `.swift` del alcance.** El build es incremental: un fichero que no se recompila en esta corrida no vuelve a imprimir sus warnings, y si se compiló en una corrida anterior de la sesión el gate lo daba limpio sin haberlo medido (2026-09-10: dos warnings de ficheros tocados llegaron así hasta el commit). El `touch` obliga a recompilarlos y cuesta segundos; un `clean build` costaría minutos por scheme.

```bash
git status --porcelain | grep -v '^D ' | awk '{print $NF}' | grep '\.swift$' | xargs touch
xcodebuild -scheme Yala -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 \
  | grep -E "(error:|warning:|BUILD SUCCEEDED|BUILD FAILED)"
```

Idem con `-scheme "Yala Dev"` (con su `touch` delante). **Criterio: cero warnings NUEVOS en los archivos tocados.** Los warnings preexistentes de otros archivos no bloquean; menciónalos solo si son de los tuyos.

**Este build no compila `YalaTests` ni `YalaUITests`** (medido: 0 líneas de esos targets en los dos logs). Los warnings de los ficheros de test tocados se leen en los pasos 2 y 3, que sí los compilan.

Build en rojo → para aquí. Lo demás no informa de nada.

## 2 · Unit tests

Primero, los **ficheros** de test que tocan el cambio:

- cada `.swift` modificado fuera de `Views/` y de los targets de test: `YalaTests/**/<Clase>Tests.swift` y `grep -rl "<Clase>" YalaTests/`. Un nivel de transitividad, no más;
- cada `.swift` modificado **dentro** de `YalaTests/`: él mismo. Un test tocado es lo primero que hay que correr.

Después, de ficheros a **suites**, con el ayudante y nunca por el nombre del fichero:

```bash
python3 -I qa/scripts/suites-de-fichero.py --only-testing YalaTests <fichero> [<fichero> …]
```

`-only-testing` casa por el nombre del TIPO, y si no casa `xcodebuild` sale con `TEST SUCCEEDED` sin avisar. Medido el 2026-11-04 en `YalaTests`: 107 ficheros no declaran ninguna suite con su nombre y 201 declaran más de una, así que pedir el nombre del fichero o no corre nada o corre solo la primera (`Groups/GroupsOrganizerBranchTests.swift` declara cinco, ninguna `GroupsOrganizerBranchTests`), y un `grep "@Suite"` tampoco basta: `LocalizationParityTests.swift` declara tres suites sin `@Suite`. El ayudante da cada tipo de columna 0 con `@Suite` delante o algún `@Test` dentro; exit 1 si un fichero no declara ninguna (es un gap, regístralo). Su banco: `qa/scripts/suites-de-fichero-test.sh`.

```bash
git status --porcelain | grep -v '^D ' | awk '{print $NF}' | grep '\.swift$' | xargs touch
bash qa/scripts/sim-lock.sh -- \
  xcodebuild -scheme Yala -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test -only-testing:YalaTests/<Suite> [-only-testing:...] > "$LOG" 2>&1     # LOG=$(mktemp -t gate-unit)
grep -E "(Test run with|passed|failed|error:)" "$LOG"
grep "warning:" "$LOG" | grep -F -f <(git status --porcelain | awk '{print $NF}' | grep '\.swift$' | sed 's|.*/||; s|^|/|; s|$|:|')
```

El `touch` vuelve a hacer falta aquí: este `test` es el primero que compila `YalaTests`, y sin él un fichero de test compilado en una corrida anterior no imprime sus warnings. El segundo `grep` lee esos warnings, filtrados a los ficheros del alcance (por `/<Fichero>.swift:`, para que `Foo.swift` no cace `BarFoo.swift`) — **mismo criterio que el paso 1: cero warnings nuevos en lo tocado, también en los tests**. El grep de antes filtraba fuera toda línea `warning:` y un warning de un test tocado no salía en ningún sitio (2026-09-10: una llamada `@MainActor` desde un closure `@Sendable`, que en Swift 6 es un error).

**Criterio del conteo: `Test run with N tests in M suites` con M ≥ el número de suites pedidas** (M cuenta también las anidadas). Si M es menor, algún filtro no casó: no es verde.

**El `sim-lock.sh` de delante no es decorado: es la cola del simulador** (ver paso 3). Los unit
tests también se instalan y corren *dentro* del simulador, así que dos sesiones aquí compiten por
la misma máquina — y si una hace cola y la otra no, el centinela del paso 3 canta contra la que se
portó bien. Si otra sesión lo tiene tomado, esto **espera** y lo dice; no falla.

**Sin `-quiet`, y no es cosmético: `-quiet` SUPRIME la línea `Test run with N tests in M suites`** (medido el 2026-08-02: aparece 1 vez sin el flag, 0 con él). Esa línea es justo la que `.claude/rules/testing.md` obliga a verificar contra el número de suites pedidas, porque el modo de fallo «cero casos» de Swift Testing sale con **exit 0 y `TEST SUCCEEDED`** — un array de filtros mal expandido, o un nombre de suite inexistente, dan una corrida verde que no ejecutó nada. Con `-quiet` esa comprobación es imposible y el gate se convierte en un sello de goma. Los marcadores `Test Suite`/`Test Case` del grep son de XCTest y este repo es Swift Testing entero: sin `Test run with` no queda nada que contar.

Si un archivo no tiene ninguna suite, **regístralo como gap** en el informe. No lo tapes.

## 3 · XCUITest de las áreas tocadas

Esto es nuevo y es el punto del gate: la fase de UI ya no espera a CI.

**El XCUITest no se lanza a pelo: se lanza haciendo cola.** En esta máquina hay UN simulador y
conviven ~14 worktrees, todos con el mismo `-destination name=iPhone 17 Pro`. Dos corridas a la vez
se derriban entre sí —comparten bundle id, la segunda mata al runner de la primera— y, peor, la
segunda **instala su `.app` encima**, así que la primera acaba tapeando un binario ajeno y produce
rojos **con** su línea de fallo, idénticos a una regresión. Decisión de Jürgen (2026-09-11, opción 2
del ticket `diez-worktrees-comparten-un-simulador`): **lock de fichero, la segunda espera**.

Cruza los archivos modificados contra `codeGlobs` de `qa/coverage-index.json`; para las áreas que casen y tengan `coverage: "xcuitest:<File>#<test>"`, corre esas suites:

```bash
bash qa/scripts/sim-lock.sh -- \
  xcodebuild -scheme "Yala Dev" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test -only-testing:YalaUITests/<Suite> 2>&1 \
  | grep -E "(Test run with|Test Case|Executed|passed|failed|warning:|\*\* TEST)"
```

Las líneas `warning:` cuentan igual que en el paso 2, solo las de los ficheros del alcance: los de `YalaUITests` no los compila ningún otro paso, así que o se leen aquí o no se leen (con el `touch` del paso 2 ya hecho, si tocaste alguno). `YalaUITests` es XCTest y sus suites son clases: medido el 2026-11-04, sus 66 clases se llaman como su fichero, así que aquí el nombre del fichero que trae `coverage` sí casa. Si un día deja de ser así, `-only-testing` no avisa: compara el `Executed N tests` con los casos que esperabas.

Si otra sesión lo tiene tomado, `sim-lock.sh` **espera** y dice a quién (`[cola] … lo tiene: pid …`).
Eso no es un fallo y no se reintenta con prisa: una corrida de XCUITest dura entre 3 y 40 min y el
turno llega solo. `bash qa/scripts/sim-lock.sh --estado` contesta «¿hay cola?» sin entrar en ella.

**No hace falta pasar `-parallel-testing-enabled NO`**: desde el 2026-07-24 ambas schemes llevan `parallelizable = "NO"` en sus `TestableReference`. Si alguna vez vuelves a ver `Simulator device failed to launch … xctrunner` con `RequestDenied`, no es el test: es que se está clonando el simulador y el disco está lleno. Corre `bash qa/scripts/disk-report.sh`.

**Y si lo que ves es `Restarting after unexpected exit` con casos en `Failing tests` que no imprimieron ninguna línea de fallo, tampoco es el disco**: es otra corrida pisándote el simulador — una que no hizo cola. `bash qa/scripts/sim-libre.sh` lo dice en un segundo.

**El lock no sustituye al centinela, porque el lock vive en el árbol de trabajo.** Un worktree con una rama anterior al 2026-09-12 no trae `sim-lock.sh` y por tanto no hace cola; un `xcodebuild` lanzado a mano, tampoco. Esos son justo los que no puedes ver, así que la corrida se sigue vigilando entera:

```bash
bash qa/scripts/sim-lock.sh -- \
  xcodebuild -scheme "Yala Dev" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test -only-testing:YalaUITests/<Suite> > /tmp/gate-ui.log 2>&1 &
bash qa/scripts/sim-libre.sh --vigilar $!     # exit 1 ⇒ el veredicto NO vale, repetí
wait; grep -E "(Test Suite|Test Case|Executed|warning:|\*\* TEST)" /tmp/gate-ui.log
```

**`$!` sigue siendo el PID correcto con el lock puesto**: `sim-lock.sh` encadena `exec` hasta el `xcodebuild`, así que no añade un proceso envoltorio — y el centinela, que exige el PID del `xcodebuild` y rechaza el de un shell, lo acepta. Mientras la corrida hace cola el centinela **no mide**: empieza cuando tu `xcodebuild` arranca de verdad, para no contar como intruso al que tiene el turno legítimamente.

Tres salidas del centinela y qué significan: **0** = estuviste solo, el veredicto vale · **1** = alguien corrió encima, la corrida no da veredicto (ni verde ni rojo): repetila · **2** = no se vigiló nada (el PID murió sin llegar a ejecutar un test), que tampoco es un ✓.

Si el centinela sale 1, **la corrida no da veredicto**. Repetila aislada. Esto no es celo: el 2026-09-11 un rojo de una corrida pisada —con su línea de fallo y su mensaje de aserto, o sea con la pinta exacta de una regresión— se archivó como ticket `high` y costó una sesión entera refutarlo (`.claude/rules/testing.md`, la regla de `L124`).

## 4 · Audit de calidad

Aplica los checks de `/swift-audit` **solo sobre las líneas añadidas** del diff. Críticos que bloquean: credenciales hardcodeadas, `try?` que silencia, force unwrap sin guard previo, `print` fuera de `#if DEBUG`, `@Attribute(.unique)` en un `@Model`. El resto es informativo.

## 5 · Índice de QA y lo que bloquea el CI

```bash
bash qa/scripts/gate-ci-checks.sh
```

Corre **todos** los pasos del job `coverage-index` de `.github/workflows/qa.yml`, leídos del propio YAML: el ratchet del índice (`validate-coverage.py`), el aislamiento de tests (`check-test-isolation.sh`: quien llame a `makeTestContext(` tiene que ser `@Suite(.serialized)`) y los bancos de los scripts del CI y del gate. Es un check que el ruleset exige para mergear, y con el commit directo desde el árbol principal no hay CI antes de aterrizar. Hasta el 2026-11-04 este paso corría solo el ratchet: el 2026-09-08 una suite sin `.serialized` pasó el gate entero y el CI la tumbó a los 17 segundos. Leer la lista del YAML es para que no vuelva a divergir: un paso nuevo del job entra aquí solo.

Bloqueante si algún paso sale en rojo (exit 1). **Exit 2 también bloquea**: el job trae algo que el script no sabe replicar (un `run:` multilínea, un `if:`, un `env:`), y un paso saltado sería el mismo hueco de antes. Si tocaste código bajo `Yala/`, actualiza el `lastVerified` de las áreas afectadas **antes** de correrlo.

Tarda entre 1,5 y 5 min (medido el 2026-11-04: 95 s y 300 s), casi todo `sim-lock-test.sh`, que pide el turno real del simulador mientras dura (sus procesos se llaman `xcodebuild` y el centinela de otra sesión los cazaría): si otra sesión lo tiene, **espera** como el paso 2. Corre también cuando el diff es solo documentación: el CI corre este job en cada push, sea cual sea el diff.

Lo que el gate **no** replica del CI, a propósito: el job `tests` corre `YalaTests` entero, y el paso 2 solo las suites del alcance (con un choke-point tocado, corre la suite entera: ~60 s). Los jobs `mcp` y `gateway` corren solo si se tocan `mcp/` o `gateway/`, y esos tienen su propio `npm test`.

## 6 · Sellar

Solo si **todo lo bloqueante está verde**:

```bash
bash qa/scripts/worktree-stamp.sh > .claude/sessions/tests-passed
```

Si algo bloqueante falla:

```bash
rm -f .claude/sessions/tests-passed
```

El sello es la huella del árbol de trabajo. El hook `PreToolUse` de `git commit` la recalcula y bloquea si cambió: pasar el gate y luego editar código ya no cuela. `git add` no invalida el sello (la huella se toma contra HEAD, no contra el índice).

## Informe

```
## Gate

Build         Yala ✓ / Yala Dev ✓   — 0 warnings nuevos
Unit          N tests, M suites — ✓
XCUITest      N tests en <áreas> — ✓        (o "sin áreas con XCUITest")
Audit         ✓ limpio  (o: N críticos, N avisos)
CI local      ✓ N/N pasos de coverage-index  (ratchet, aislamiento, bancos)

Gaps: <archivo> → sin tests    (o "ninguno")

Veredicto: LISTO PARA COMMIT | BLOQUEADO por <qué>
```

## Reglas

- **No declares verde nada que no hayas corrido.** «Debería pasar» no es un resultado.
- Un test en rojo se arregla o se registra en la Lista Negra con dueño y fecha. «Preexistente» no es excusa.
- Este comando no commitea ni edita código de la app. Solo verifica y sella.
