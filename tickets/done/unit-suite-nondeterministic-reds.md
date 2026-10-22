---
id: unit-suite-nondeterministic-reds
status: done
priority: high
area: testing
created: 2026-09-06
updated: 2026-09-07
source: medido durante groups-owner-transfer-and-leave (2026-09-06)
---

# `YalaTests` completa da rojos DISTINTOS en cada corrida, y todos pasan aislados

## Resultado (2026-09-07)

**La suite es determinista.** Tres corridas completas sobre el mismo árbol
(`b39d3fdf`, iPhone 17 Pro · iOS 26.5, disco a 33 GB) dan el MISMO resultado, y ninguna tiene rojos.

**Y hay una causa medida de no-determinismo, pero no está en la ejecución: está en la LECTURA del
log.** El método de conteo que este mismo ticket prescribía pierde entre 43 y 50 líneas de resultado
por corrida, y **cuáles pierde cambia en cada una**. Eso es suficiente para fabricar la apariencia de
«conjuntos disjuntos» sin que nada falle.

## Lo medido

### 1 · Tres corridas, resultado idéntico

| medición | corrida 1 | corrida 2 | corrida 3 | estable |
|---|---|---|---|---|
| `Test run with N tests in M suites` | 6414 / 653 | 6414 / 653 | 6414 / 653 | ✅ |
| result bundle `failedTests` | — | — | **0** | ✅ |
| result bundle `passedTests` / `skippedTests` | — | — | 6402 / 12 | ✅ |
| conteo SIN ancla (`grep -o '✔ Test '`) | 6403 | 6403 | — | ✅ |
| **conteo CON ancla (`grep -cE '^✔ Test .* passed'`)** | **6360** | **6353** | — | ❌ |
| veredicto | TEST SUCCEEDED | TEST SUCCEEDED | TEST SUCCEEDED | ✅ |

El árbol no cambió durante las corridas (`shasum` de todos los `.swift` de `Yala/ YalaTests/
YalaUITests/ YalaWidgets/ YalaShare/`, idéntico antes y después).

La lista de NOMBRES de tests pasados de la corrida 1 vs la 2 difiere en **3 de 6330**, y las tres son
líneas partidas, no tests distintos.

### 2 · La causa: dos escritores sobre el mismo stdout, sin sincronizar

Los `print` de la app bajo `#if DEBUG` y el reporter de Swift Testing escriben en el MISMO descriptor
sin lock. Cuando un log de la app cae en medio de una línea del reporter, la línea se parte. Literal,
de la corrida 2:

```
◇ Test exact_amountGreaterThanTotal_returnsNil() started.
✔ Test exact_amountGreaterTh2026-09-07 21:44:23.948753-0500 Yala[72656:28210140] [Push] PUSH TOKEN_OK …
anTotal_returnsNil() passed after 0.001 seconds.
```

El nombre del test queda cortado a la mitad y el resultado se reparte en dos líneas, **ninguna de las
cuales casa con `^✔ Test .* passed`**. Ese test aparece como «arrancado y sin resultado».

⇒ **Todo conteo o detección anclado en `^` ve un conjunto distinto en cada corrida**, porque el punto
de corte depende del timing. Y lo que le pasa a un `✔` le puede pasar a un `✘`.

### 3 · Lo que este ticket afirmaba y la medición corrige

- **«El resumen `Test run with` no cuadra con la realidad».** Al revés: el resumen es la cifra
  ESTABLE (6414 en las tres corridas) y el conteo a mano es el que baila. `.claude/rules/testing.md`
  ya mandaba leer esa línea; este ticket desaconsejaba el método bueno y prescribía el roto.
- **«Cuatro de los cinco son source-scans».** Son **los cinco**:
  `GroupICloudIdentitySeedTests.bootSeed_doesNotDependOnTheTransportFetch` también lee el árbol por
  `#filePath` (`productionSources()`).
- **Hipótesis 3 (orden / paralelismo), refutada por medición.** Las suites NO se entrelazan en el
  log: cada `◇ Suite X started` cierra con su `✔ Suite X passed` antes de que arranque la siguiente.
  Swift Testing ya corre serializado aquí.
- **Hipótesis 1 (el escaneo falla bajo carga) no explica los rojos observados.** Los escáneres usan
  `guard let text = try? String(contentsOf:) else { continue }`: una lectura fallida SALTA el fichero,
  o sea produce MENOS offenders. En `everyTestConfiguration_declaresCloudKitDatabase` y en
  `productionConstructions_injectTheLiveProvider_neverAnExplicitNil` eso da VERDE, no rojo. Solo
  `bootSeed_…` tiene un camino lectura-fallida → rojo (su `#require` de `AppBootstrapper.swift`).
- **Hipótesis 2 (disco), no descartable pero no reproducible hoy.** El 2026-09-06 la máquina estaba
  entre 20 y 5,9 GB (umbral 25) con 23 sesiones abiertas y el OOM killer activo. Hoy, con 33 GB y una
  sesión: 3 × 6402 = **19 206 ejecuciones de test, 0 fallos**.

## Criterio de hecho (AC)

- [x] **Causa identificada con evidencia.** La del no-determinismo OBSERVABLE: entrelazado de stdout
      entre los logs de la app y el reporter, que parte 43-50 líneas de resultado por corrida y
      distintas cada vez. Evidencia arriba, reproducible en cualquier corrida completa.
- [x] **La suite completa da el mismo resultado en dos corridas consecutivas.** Tres, no dos.
- [x] **Flaky residual → Lista Negra.** No hay ninguno que registrar: 0 rojos en tres corridas
      completas. Los cinco casos del 2026-09-06 **no se reprodujeron** y no se declaran «arreglados»:
      se declaran *no reproducibles con el entorno sano*. Si vuelven, el primer dato que hace falta es
      el disco (`bash qa/scripts/disk-report.sh`) y el `-resultBundlePath`, no el log.

## Lo que queda abierto, y dónde

- **`tests-borran-el-store-sqlite-abierto`** — de camino salieron 554-556 violaciones
  `BUG IN CLIENT OF libsqlite3.dylib … vnode unlinked while in use` por corrida. Ticket propio.

## Relacionados

- [[groups-owner-transfer-and-leave]] — la sesión que lo midió (y que pagó el coste).
- [[tests-borran-el-store-sqlite-abierto]] — hallazgo de camino.
