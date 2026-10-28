---
name: feedback-gate-globs-ancho-subconjunto
description: Tocar ContentView o PanelView hace que el cruce de codeGlobs del gate pida ~90 suites de XCUITest; se corre el subconjunto que ejerce el cambio y se declara
metadata:
  type: feedback
---

El paso 3 del `/gate` cruza los ficheros tocados con `codeGlobs`, y `ContentView.swift` / `PanelView.swift` están en
casi todas las áreas: el 2026-10-28 (S12k) pidió 92 suites, horas de simulador. Se corrió el subconjunto que ejerce lo
tocado (los XCUITest nuevos + las suites de esas pantallas) y se dijo en el PR; el CI corre la batería de UI entera en
tandas.

**Why:** la cola de auto-merge y el CI completo existen; bloquear la sesión horas no añade red.
**How to apply:** lista el subconjunto y el porqué en el informe del gate y en el PR, nunca lo calles. Si el cambio es de
lógica de arranque o presentaciones del shell, mete las suites de Welcome y cierre de sesión en el subconjunto.
