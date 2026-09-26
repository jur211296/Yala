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

**Y cada mutante necesita TOPE de tiempo (2026-09-25):** un mutante que convierte un corte en otro camino puede COLGAR la suite
(un test que espera una petición que ya no sale): el R6 de #253 estuvo 53 min parado hasta que lo maté por PID. Colgar cuenta
como detectado, pero sin tope la tanda entera se para. Pon `timeout=` al `subprocess.run` (p. ej. 15 min).

**Y el cuelgue de salida de `xcodebuild` cuesta ~5 min POR MUTANTE (2026-09-26):** la corrida imprimía `Test run with … failed after
1 s` y el proceso tardaba cinco minutos en salir; 13 mutantes eran una hora. Tope de 240 s en el `subprocess.run` de la corrida y,
en el `TimeoutExpired`, leer el veredicto de `e.stdout` (sin `Test run with` = sin veredicto). Y si la review trae arreglos mientras
la tanda corre, **para la tanda y relánzala UNA vez sobre el código final** con los mutantes nuevos: las ediciones no pueden
tocar el árbol mutado, y dos tandas cuestan el doble.
