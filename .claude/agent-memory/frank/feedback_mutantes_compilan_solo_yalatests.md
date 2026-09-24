---
name: mutantes-compilan-solo-yalatests
description: Un mutante con `build-for-testing` a secas tardaba ~15 min (compila también YalaUITests); con `-only-testing:YalaTests` en el build, ~1 min.
metadata:
  type: feedback
---

En una batería de mutantes, el `build-for-testing` lleva **`-only-testing:YalaTests`**, igual que la corrida.

**Why:** el 2026-09-23 lancé 16 mutantes con `xcodebuild … build-for-testing` sin filtro: cada uno recompilaba también
`YalaUITests` y tardaba ~15 min, así que la batería iba a durar cuatro horas. Con el filtro en el build, el mismo cambio
en `MigrationRunner.swift` compiló en 54 s. Los 20 mutantes cupieron en media hora.

**How to apply:** si solo vas a correr unit tests, el build también se filtra. Y si tienes que parar una batería a mitad,
mata el script **y** el `xcodebuild`, y restaura los ficheros desde la copia del scratchpad (el `finally` no corre si
matas el proceso): compara con `cmp` antes de tocar nada más. Relacionado: [[el-script-de-mutantes-revierte-mi-trabajo]].
