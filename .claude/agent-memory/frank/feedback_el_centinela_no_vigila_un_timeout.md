---
name: el-centinela-no-vigila-un-timeout
description: `sim-libre.sh --vigilar` sale 2 si le pasas el PID de `timeout`/subshell en vez del xcodebuild; lanza sim-lock sin `timeout` delante cuando vigilas
metadata:
  type: feedback
---

Con `timeout N bash qa/scripts/sim-lock.sh -- xcodebuild … &` y `pgrep -f "xcodebuild …"`, el pgrep casa también con la
línea de `timeout` (lleva el mismo texto) y el centinela vigila ese PID: sale **2** («murió sin ejecutar tests») aunque
la corrida pase entera. Medido el 2026-11-05 en el lote N4, dos veces.

**Why:** un 2 no es un veredicto; hubo que justificarlo en el PR con «sin reinicios y única sesión».

**How to apply:** para vigilar, lanza `bash qa/scripts/sim-lock.sh -- xcodebuild … &` sin `timeout` delante y pasa
`$!`; o filtra el pgrep a `^/Applications/Xcode.app/.*/xcodebuild`.
