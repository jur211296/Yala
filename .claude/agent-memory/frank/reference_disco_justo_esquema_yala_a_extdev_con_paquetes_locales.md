---
name: reference-disco-justo-esquema-yala-a-extdev-con-paquetes-locales
description: Con la Mini por debajo de ~8 GB, el build y los unit del esquema Yala van a ExtDev reutilizando SourcePackages del DerivedData local; no se colgó (18-nov)
metadata:
  type: reference
---

En la Mini el DerivedData por defecto de un worktree apunta a `/Volumes/ExtDev/DerivedData/Yala-<hash>` (lo dice `xcodebuild -showBuildSettings | grep BUILD_DIR`), y ExtDev a veces se cuelga resolviendo paquetes ([[feedback-gate-en-disco-local-no-extdev]]). Con el disco interno en 4-7 GB no cabía otra configuración (`Yala`, Debug: ~4 GB más) junto a la de `Yala Dev` en local.

Lo que funcionó el 2026-11-18: `-derivedDataPath /Volumes/ExtDev/DerivedData/<slug>-ext -clonedSourcePackagesDirPath <DerivedData local>/SourcePackages`. Sin resolver paquetes en ExtDev no hubo cuelgue: build en ~5 min y los unit del gate en verde. `Yala Dev` (tests de interfaz, capturas) siguió en local.

**How to apply:** antes del gate, `df -h /`; si no hay ~8 GB, el esquema `Yala` va a ExtDev con los paquetes locales. Vigila igual los 3 primeros minutos.
