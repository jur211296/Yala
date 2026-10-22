---
name: cola-del-simulador
description: PR #147 — el simulador se pide por turno (sim-lock.sh); la review cazó DOS llaves maestras mías, el lock destapó dos defectos del centinela que no se podían ver antes, y deja 4 tickets
metadata:
  type: project
---

**Desde el 2026-09-12 toda corrida de `xcodebuild … test` del `/gate` y de `/l10n-check` va envuelta
en `bash qa/scripts/sim-lock.sh -- …`.** La segunda sesión espera; no falla ni instala encima.
Decisión de Jürgen del 11-sep: opción (2) del ticket `diez-worktrees-comparten-un-simulador`. PR #147,
mergeado.

**Why:** catorce worktrees y un solo iPhone 17 Pro. Dos corridas a la vez se derriban, y la segunda
instala su `.app` sobre el mismo bundle id ⇒ rojos **con** su línea de fallo, indistinguibles de una
regresión. Eso ya costó el `high` falso de `welcome-chooser-uitests…` y una sesión entera.

**How to apply:**

- **`flock(1)` no existe en macOS.** El lock es `python3` + `fcntl.flock`; lo suelta el kernel al
  morir el proceso, incluso con `kill -9`. `shlock(1)` sí está y se descartó (PID-based).
- **El PID no cambia** (cadena de `exec`), así que `sim-lock.sh … & sim-libre.sh --vigilar $!` sigue
  valiendo. Es lo que hace compatibles las dos piezas.
- **`--estado` no es una puerta**: toma el lock un instante y lo suelta, así que `--estado && correr`
  es una carrera. Para correr, se hace cola.
- El banco es `bash qa/scripts/sim-lock-test.sh` (37 casos, sin tocar el simulador). **Corre también
  en Linux**: lo verifiqué en el job `coverage-index` del CI, 37/37.

## Lo que descubrí y no esperaba

- **Tener el turno NO es tener el simulador.** El runner de XCUITest cuelga de `launchd_sim`, no de
  `xcodebuild`: matar la corrida suelta el lock **al instante** y el runner sigue dentro. Medido: 1
  runner vivo a los 1, 3, 6 y 10 s, con el lock ya libre. Por eso el turno espera a que el simulador
  se quede quieto antes de arrancar.
- **El lock destapó dos defectos del centinela que antes eran invisibles**, porque hacía falta que
  alguien esperara detrás para verlos: contaba como intruso al dueño legítimo del turno, y su última
  muestra se tomaba hasta 5 s después de morir el vigilado (o sea, señalaba al siguiente de la fila).
  Con la cola habrían cantado **cada vez que dos sesiones coincidieran**.
- **`pgrep -f PATRÓN` se cuenta a sí mismo y a los pares.** Con CERO runners vivos,
  `pgrep -f 'UITests-Runner'` devolvía **1**, y dos `sim-libre.sh` simultáneos se declaraban «ocupado»
  mutuamente **6 de 6 veces** con el simulador en reposo. Era preexistente y bloqueaba gates por nada.
  Se escribe `'[U]ITests-Runner'` (medido: 0 de 6).

## Lo que deja abierto

Cuatro tickets: `prompts-de-traduccion-corren-xcodebuild-sin-cola` (seis recetas siguen a pelo),
`qa-de-producto-toca-el-simulador-sin-cola` (el `simctl install` del `/qa` es invisible a las dos
firmas del centinela: la víctima recibe un rojo con el centinela en verde),
`l10n-check-corre-13-de-17-tests` y `el-turno-del-simulador-cubre-tambien-la-compilacion` (`low`).

**Device-QA: no procede** — no toca ninguna superficie de la app.

Relacionado: [[dos-corridas-un-simulador]] · [[review-adversarial-caza-lo-mio]] ·
[[la-review-y-los-mutantes-no-comparten-arbol]]
