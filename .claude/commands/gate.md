---
description: Gate único antes de commitear — build, unit, XCUITest de las áreas tocadas, audit de calidad y validación del índice de QA
allowed-tools: Bash(git:*), Bash(xcodebuild:*), Bash(bash qa/validate-coverage.sh:*), Bash(bash qa/scripts/worktree-stamp.sh:*), Bash(python3 qa/qa-sync.py:*), Bash(grep:*), Bash(jq:*), Read, Glob, Grep
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

Las dos schemes, porque `Yala Dev` compila con `DEV_BUILD` y `Debug-Dev` y ha ocultado errores que solo salían en producción:

```bash
xcodebuild -scheme Yala -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 \
  | grep -E "(error:|warning:|BUILD SUCCEEDED|BUILD FAILED)"
```

Idem con `-scheme "Yala Dev"`. **Criterio: cero warnings NUEVOS en los archivos tocados.** Los warnings preexistentes de otros archivos no bloquean; menciónalos solo si son de los tuyos.

Build en rojo → para aquí. Lo demás no informa de nada.

## 2 · Unit tests

Mapea cada `.swift` modificado (excluyendo `Views/` y `Tests/`) a sus suites: por convención `<Clase>Tests.swift` y por `grep -rl "<Clase>" YalaTests/`. Un nivel de transitividad, no más.

```bash
xcodebuild -scheme Yala -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test -only-testing:YalaTests/<Suite> [-only-testing:...] 2>&1 \
  | grep -E "(Test run with|Test Suite|Test Case|Executed|passed|failed|error:)"
```

**Sin `-quiet`, y no es cosmético: `-quiet` SUPRIME la línea `Test run with N tests in M suites`** (medido el 2026-08-02: aparece 1 vez sin el flag, 0 con él). Esa línea es justo la que `.claude/rules/testing.md` obliga a verificar contra el número de suites pedidas, porque el modo de fallo «cero casos» de Swift Testing sale con **exit 0 y `TEST SUCCEEDED`** — un array de filtros mal expandido, o un nombre de suite inexistente, dan una corrida verde que no ejecutó nada. Con `-quiet` esa comprobación es imposible y el gate se convierte en un sello de goma. Los marcadores `Test Suite`/`Test Case` del grep son de XCTest y este repo es Swift Testing entero: sin `Test run with` no queda nada que contar.

Si un archivo no tiene ninguna suite, **regístralo como gap** en el informe. No lo tapes.

## 3 · XCUITest de las áreas tocadas

Esto es nuevo y es el punto del gate: la fase de UI ya no espera a CI.

Cruza los archivos modificados contra `codeGlobs` de `qa/coverage-index.json`; para las áreas que casen y tengan `coverage: "xcuitest:<File>#<test>"`, corre esas suites:

```bash
xcodebuild -scheme "Yala Dev" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test -only-testing:YalaUITests/<Suite> 2>&1 \
  | grep -E "(Test run with|Test Case|Executed|passed|failed|\*\* TEST)"
```

**No hace falta pasar `-parallel-testing-enabled NO`**: desde el 2026-07-24 ambas schemes llevan `parallelizable = "NO"` en sus `TestableReference`. Si alguna vez vuelves a ver `Simulator device failed to launch … xctrunner` con `RequestDenied`, no es el test: es que se está clonando el simulador y el disco está lleno. Corre `bash qa/scripts/disk-report.sh`.

## 4 · Audit de calidad

Aplica los checks de `/swift-audit` **solo sobre las líneas añadidas** del diff. Críticos que bloquean: credenciales hardcodeadas, `try?` que silencia, force unwrap sin guard previo, `print` fuera de `#if DEBUG`, `@Attribute(.unique)` en un `@Model`. El resto es informativo.

## 5 · Índice de QA

```bash
bash qa/validate-coverage.sh
```

Bloqueante si el ratchet salta. Si tocaste código bajo `Yala/`, actualiza el `lastVerified` de las áreas afectadas **antes** de correrlo.

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
Índice QA     ✓ ratchet OK

Gaps: <archivo> → sin tests    (o "ninguno")

Veredicto: LISTO PARA COMMIT | BLOQUEADO por <qué>
```

## Reglas

- **No declares verde nada que no hayas corrido.** «Debería pasar» no es un resultado.
- Un test en rojo se arregla o se registra en la Lista Negra con dueño y fecha. «Preexistente» no es excusa.
- Este comando no commitea ni edita código de la app. Solo verifica y sella.
