---
name: time-profiler-de-un-test-en-el-simulador
description: Cómo grabar Time Profiler de una prueba unitaria que corre en el simulador (attach por pid con --device) y separar antes/después en la traza
metadata:
  type: reference
---

Para perfilar código puro (sin el iPhone) con Time Profiler, medido el 27-nov-2026 en la Mini:

- La prueba corre dentro de la app anfitriona del simulador, proceso **`Yala`** (`pgrep -x Yala`, aparece segundos
  después de lanzar `xcodebuild test`).
- `xcrun xctrace record --template 'Time Profiler' --attach <pid>` **sin `--device` falla** con «Cannot find process for
  provided pid». Con `--device <udid del simulador>` graba bien.
- Un caso `@Test(.enabled(if: ProcessInfo…environment["X"] == "1"))` que repite el algoritmo viejo N s y luego el nuevo
  N s, lanzado con `TEST_RUNNER_X=1`, deja los dos tramos separados en la traza; el attach tarda ~2 s, así que 6 s por
  tramo bastan.
- Exportar: `xctrace export --input t.trace --xpath '/trace-toc/run[@number="1"]/data/table[@schema="time-profile"]'` y
  leer con `docs/qa/rendimiento-iphone14-2026-11-26/scripts/perfil_lector.py` (resuelve `id`/`ref` de frames y
  backtraces); un ElementTree a mano devolvió 0 muestras.

Relacionado: [[perfilar-ciclos-en-el-iphone-con-xctrace]].
