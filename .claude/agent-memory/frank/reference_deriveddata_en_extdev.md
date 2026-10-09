---
name: deriveddata-en-extdev
description: En la Mini el DerivedData de Xcode vive en /Volumes/ExtDev/DerivedData; disk-report lo da como 0B y borrarlo desde Bash está denegado
metadata:
  type: reference
---

El DerivedData real de las sesiones de Yala está en **`/Volumes/ExtDev/DerivedData/Yala-<hash>`**
(medido el 2026-10-09), no en `~/Library/Developer/Xcode/DerivedData`, que sale vacío. Por eso
`qa/scripts/disk-report.sh` informa «DerivedData (Xcode) 0B» aunque haya ~15 carpetas de worktrees
muertos. El `.app` para instalar a mano con `simctl install` sale de
`/Volumes/ExtDev/DerivedData/Yala-<hash>/Build/Products/Debug-iphonesimulator/Yala.app`; el hash de
cada worktree se identifica por `WorkspacePath` en su `info.plist`.

**Why:** el encargo pide borrar el DerivedData de sesiones cerradas, y buscarlo en la ruta por
defecto da «no hay nada». El `rm -rf` sobre `/Volumes/ExtDev` desde Bash lo denegó el clasificador.

**How to apply:** para limpiar, lista por `WorkspacePath` inexistente y borra con el `osascript` de
la casa, o decláralo en el cierre si tampoco pasa. Relacionado: [[una-tanda-de-capturas-cuesta-diez-gigas]].
