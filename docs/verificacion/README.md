# Verificación en Yala — comparación con el equipo de Claude Code (17-nov-2026)

Fuente de la propuesta publicada en https://claude.ai/artifact/RTWfBUbDi4tbW1eKbEA81d
(`propuesta-2026-11-17.html` es esa misma página). Artículo de referencia:
https://claude.dev/blog/how-the-claude-code-team-thinks-about-verification/

**Cómo leer el voto de Jürgen:** `ArtifactData list` sobre esa URL, colección `votos`, un documento
por propuesta (`p1`…`p6`) con `voto` (`si` · `no` · `despues`), `nota` y `ts`. Solo el dueño
escribe (regla `votos: read view, write admin`).

## Las seis propuestas (orden por impacto y costo)

| Id | Propuesta | Impacto | Costo | Recomendación |
|---|---|---|---|---|
| P1 | Un rojo rescatado no es verde: arreglar la caché de divisas y cuarentena con dueño leída de 2.3 | alto | bajo | Sí |
| P2 | Interfaz de lo tocado en cada PR, elegida por script; observar → obligatorio | alto | medio | Sí |
| P3 | Línea `Verificado:` en cada commit, también «ninguno» | medio | bajo | Sí |
| P4 | Checklist de confiabilidad con disparadores + un revisor con rondas, leídos de 2.3 | alto | alto | Sí, tras P1-P3 |
| P5 | Revisión mensual de escapes (`Origen:` en los arreglos) y poda de reglas | medio | bajo | Sí |
| P6 | Property tests y diferenciales en fechas, divisas, divididos y migración a la nube | medio | medio | Después |

El texto completo de cada una (hoy, con el cambio, evidencia, sesión, riesgo) está en el array
`PROPUESTAS` de la página.

## Inventario (medido en el árbol de este commit)

- **`/gate`** (`.claude/commands/gate.md`): build de las dos schemes, unit del alcance con
  `qa/scripts/suites-de-fichero.py`, XCUITest de las áreas tocadas **cruzando a mano** el diff con
  `codeGlobs` de `qa/coverage-index.json` (paso 3, l. 86; no hay script), audit de líneas añadidas,
  `gate-ci-checks.sh` (réplica del job `coverage-index`) y sello.
- **Sello**: huella del árbol en `.claude/sessions/tests-passed` (ignorado por git). El hook
  `PreToolUse` de `git commit` → `qa/scripts/precommit-gate.sh` bloquea si hay `.swift` en staging y
  la huella no coincide (l. 26-46). Sin modo observar. Nada llega al mensaje del commit.
- **CI** (`.github/workflows/qa.yml`): `coverage-index`, `changes`, `tests` (unit, bloqueantes desde
  el 10-oct, con `ci-reintentar-rojos.sh --vueltas 3`, l. 654 y 684), `ui-build` + `ui` (9 tandas,
  **solo `schedule`/`workflow_dispatch`**, `continue-on-error`, `-retry-tests-on-failure`, l. 852,
  904, 911, 933), `aviso` («¿Se ha enterado alguien de los rojos de test?», l. 985), `mcp`,
  `gateway`, `panel`, `webapp`. `nocturna-vigilante.yml` vigila que la nocturna se lance.
- **Ruleset de 2.3** (`gh api repos/jur211296/Yala/rulesets/26615514`): exige `tests`,
  `coverage-index` y `gateway`; ninguna prueba de interfaz; el rol admin lo salta siempre.
- **Revisión**: no hay `REVIEW.md`. La review adversarial con varias lentes es recomendación de
  `CLAUDE.md` (l. 73), sin nada que la exija. Workflows `full-review.js` y `ui-audit.js` invocables.
- **Reglas**: `.claude/rules/` suma 5.445 líneas; `swiftdata-cloudkit.md` 2.097 (263 entradas
  fechadas), `testing.md` 296 (73). Sin mecanismo de poda. `testing.md` l. 72 cita una «Lista
  Negra» en `docs/TESTING-STRATEGY.md`, que no existe.
- **Tests**: 262 clases `XCTestCase` en `YalaUITests`. En `YalaTests`, 0 usos de
  `RandomNumberGenerator`; 113 ficheros con `@Test(arguments:)` de lista fija; 61 ficheros de
  paridad y 66 de ida y vuelta con ejemplos a mano. Goldens del backend en `qa/cloud/`.
- **Inestables**: 1 `XCTExpectFailure` en `YalaUITests` (`IPhoneLandscapeUITests.swift:160`), 28
  `XCTSkip`, 10 `sleep(`. Sin lista de cuarentena ejecutable.

## Mediciones de 2.3, del 2026-11-03 al 2026-11-17

| Dato | Valor | Cómo se midió |
|---|---|---|
| PRs mergeados a 2.3 | 206 (180 con auto-merge) | `gh pr list --base 2.3 --state merged --search "merged:>=2026-11-03"` |
| PRs con interfaz en su CI | 0 | job `ui` con `if: schedule \|\| workflow_dispatch` |
| Días sin corrida completa de interfaz sobre 2.3 | 9 (primera: 12-nov, con 117 PRs ya dentro) | `gh run list` del workflow QA por rama y evento |
| Rescates de unit | 65 en 60 de 503 corridas (12 %); 12 casos; 60 de la familia `CurrencyConverter*` | anotación «Rescatado al repetirlo» de `ci-reintentar-rojos.sh` en los jobs `tests` |
| Verdes tras reintento en interfaz | 35 (28 distintos) en 7 corridas completas | «Test Case … failed» seguido de «passed» del mismo caso por corrida |
| Pruebas de interfaz rotas que llegaron a 2.3 | 11 en dos tandas (7 del 12 al 14-nov; 4 el 16-nov) | logs de tandas; tickets `2026-11-14-qa-ui-tandas-rojas` y `2026-11-16-ui-tests-rojos-tandas` |
| El PR que rompió las 4 del 16-nov | categorías a un toque (#920): su gate corrió 6 clases y 16 casos, ninguna de las rotas; su CI dejó la interfaz `skipped` | cuerpo del PR y `gh pr checks` |
| Ficheros de interfaz que abren el formulario de registro | ≈33 | `grep -rlE "transactionForm\|TransactionForm\|openNewTransaction\|addTransactionButton\|\"Nuevo registro\"" YalaUITests` |
| Reverts | 0 | `git log origin/2.3 --since=2026-11-03 \| grep -ic revert` |
| Arreglos que nombran su PR de origen | 1 de 11 | títulos y cuerpos de los PRs de arreglo |
| Commits con alguna marca de verificación | 13 de 572 | `git log --no-merges --format=%B` buscando `Gate:`, «Verificado», «sello» |

**Inferido, no medido:** que P2 habría parado las dos tandas de rojos (depende de cómo el script
mapee las pantallas); el PR exacto de cada uno de los 7 rojos del 12 al 14-nov (atribución por fechas).

## Lo que no se propone

Más revisores en paralelo (el artículo y nuestro dato del 14-nov dicen que rinde peor que uno bien
informado); SwiftCheck u otra dependencia (Swift Testing con semilla alcanza); evals formales con
«answer key» (no a nuestro volumen); bloquear por no haber corrido `/verify` (el sello de huella
ya lo cubre mejor).
