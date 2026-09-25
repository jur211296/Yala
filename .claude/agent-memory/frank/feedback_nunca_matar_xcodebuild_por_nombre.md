---
name: nunca-matar-xcodebuild-por-nombre
description: Para parar MIS mutantes maté con `pkill -x xcodebuild` y eso alcanza las corridas de otras sesiones de la Mac. Se mata por PID propio.
metadata:
  type: feedback
---

Para parar un runner de mutantes, mata **su** proceso (el PID que lanzaste, o `pkill -f <ruta de tu script>`)
y deja que su `xcodebuild` muera con él. **Nunca `pkill -x xcodebuild` ni `killall xcodebuild`.**

**Why:** el 2026-09-25 (#247) lo hice para cortar mis mutantes y el comando alcanzó todo `xcodebuild` vivo en la
Mac, que comparte un simulador con ~14 worktrees. Si otra sesión estaba en su gate, le rompí la corrida sin que lo
sepa, y su rojo parecerá del código. Es la misma familia que `killall "Google Chrome"` en el CLAUDE.md global.

**How to apply:** antes de matar algo, pregúntate si el patrón casa con procesos de otras sesiones. Si lo hiciste,
dilo en el resumen de cierre. Y al restaurar tras un kill, restaura desde las copias del scratchpad y verifica el md5
([[el-script-de-mutantes-revierte-mi-trabajo]]).
