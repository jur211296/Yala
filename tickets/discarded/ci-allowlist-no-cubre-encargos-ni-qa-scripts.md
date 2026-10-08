---
id: ci-allowlist-no-cubre-encargos-ni-qa-scripts
status: discarded
priority: low
area: ci
created: 2026-09-07
updated: 2026-10-08
source: medido de camino en rojo-xcuitest-runner-muere-tras-el-primer-caso (PR #96)
---

Why: Discarded 2026-10-08. Duplicado de `encargos-markdown-triggers-the-whole-ios-suite` (mismo hueco: `encargos/*` fuera del `case` del job `changes`, `qa.yml:203-216`, medido hoy). Sus mediciones de los PR #96 y #120 y su comprobación por `grep` se fusionaron allí; su propuesta de `qa/scripts/` no, porque `qa.yml` la descarta a propósito.

# Un fichero de texto de `encargos/` dispara 1,5 h de suite en `macos-26`

## Lo observado (PR #96, 2026-09-07)

El PR no tocaba **ni una fuente Swift** — solo tickets, reglas, un script de shell y el fichero del
encargo. Aun así el job `changes` decidió correr la suite completa, y lo dijo con nombre y apellido:

```
- CORRE — toca encargos/lanzados/2026-09-07-rojo-xcuitest-runner-muere-tras-el-primer-caso.md
```

El allowlist inerte de `.github/workflows/qa.yml` cubre hoy
`docs/` · `tickets/` · `marketing/` · `Web/` · `.claude/` · `gateway/` · `qa/cloud/` + `README.md` ·
`CLAUDE.md` · `LICENSE*`. **No cubre `encargos/` ni `qa/scripts/`**, y los dos son inertes.

## La comprobación que el propio workflow exige, hecha

El comentario del allowlist dice: «Al añadir una ruta nueva, repetir la comprobación, no asumirla», y
deja el método. Repetida:

```
grep -c 'encargos'                  Yala.xcodeproj/project.pbxproj  → 0
grep -cE 'qa/scripts|path = qa'     Yala.xcodeproj/project.pbxproj  → 0
grep -c 'Utils'                     Yala.xcodeproj/project.pbxproj  → 2   ← control positivo
```

Ninguna de las dos es input de `xcodebuild`. El control positivo está para que el 0 signifique algo:
sin él, un grep mal escrito da 0 y parece una respuesta.

## Por qué es `low` y no más

No rompe nada: el CI acaba en verde igual y el gate duro (`coverage-index`) corre siempre y no
depende de esto. Lo que cuesta es **reloj de runner** — el comentario del workflow cita el PR #41,
que con 3 ficheros `.md` esperó **1 h 45 min**. Con sesiones autónomas dejando su fichero de encargo
en cada PR, esto se paga en casi todos.

## Cuidado al arreglarlo

- El diseño es **deny-by-default a propósito** («fail closed: 1,5 h de más sale más barato que un
  verde que no probó nada»). Añadir rutas va en contra de esa dirección, así que solo entran las que
  se midan — no se amplía «por si acaso».
- `qa/scripts/` es más discutible que `encargos/`: hoy no entra en el build, pero es donde viven los
  scripts del gate. Si mañana uno se invoca desde una fase de build, deja de ser inerte y el
  allowlist mentiría. `encargos/` es texto y no tiene ese riesgo.
- Tocar `.github/` **dispara la suite a propósito** (para que el CI pruebe sus propios cambios), así
  que el PR que arregle esto pagará el 1,5 h una vez. Es correcto que sea así.

## Re-comprobado el 2026-09-09 (PR #120)

Sigue vigente, y visto en vivo: un PR de **once ficheros markdown** (`tickets/` + `docs/`) disparó
la suite de simulador entera por un solo fichero, `encargos/lanzados/2026-09-09-ideas-backlog-*.md`.
La allowlist medida en el YAML de ese día es `docs/*|tickets/*|marketing/*|Web/*|.claude/*`,
`README.md|CLAUDE.md|LICENSE*`, `gateway/*|qa/cloud/*` — `encargos/` no está.

El PR se mergeó igual sin esperar: el propio workflow declara la suite **advisory**
(«2026-06-04 — TODO advisory; gate duro = coverage-index») y `coverage-index` pasó en 17 s.

## Relacionados

- [[rojo-xcuitest-runner-muere-tras-el-primer-caso]] — el PR donde se observó

Triage 2026-10-08: duplicado · low → — · se conserva `encargos-markdown-triggers-the-whole-ios-suite`, que recibe la fusión; `encargos/*` sigue fuera del allowlist de `qa.yml:203-216`.
