---
name: ui-tras-yalatests-entero-reinicia-el-simulador
description: Tras correr YalaTests entero, el runner de XCUITest no arranca («Timed out waiting for AX loaded notification»); reiniciar el simulador lo cura
metadata:
  type: reference
---

Medido el 2026-11-12 en la Max (iPhone 17 Pro, iOS 27.2): justo después de `YalaTests` entero (~5 min) en el mismo
simulador, dos corridas seguidas de XCUITest murieron con `YalaUITests-Runner … encountered an error (The test runner
failed to initialize for UI testing. (Underlying Error: Timed out waiting for AX loaded notification))`, exit 65 y
cero casos. El centinela dijo «estuviste solo» y el disco tenía 577 GB libres.

**Cómo aplicarlo:** ese mensaje es infraestructura, no un rojo. `simctl shutdown` + `boot` + `bootstatus -b` de TU
simulador y repetir: la tercera corrida ejecutó los 29 casos. Para no perder una vuelta, corre los XCUITest del gate
ANTES que `YalaTests` entero, o reinicia entre medias. Relacionado: [[un-timeout-tapa-el-rojo-de-detras]].
