---
name: feedback-pgrep-f-casa-con-los-prompts-de-otras-sesiones
description: `pgrep -f '[x]codebuild'` cuenta procesos `claude` cuyo prompt menciona xcodebuild: una espera por «no hay xcodebuild» no acaba nunca
metadata:
  type: feedback
---

Para saber si hay un `xcodebuild` vivo, `pgrep -x xcodebuild`, nunca `pgrep -f`.

**Why:** 2026-11-13, en la Max: esperé a repetir `sim-lock-test.sh` hasta que `pgrep -f '[x]codebuild'` diera 0, y nunca dio
0: casaba con las sesiones `claude -n sat-lab …` y `centro-de-mando …`, cuyo argv lleva el encargo entero con la palabra
`xcodebuild`. `pgrep -x xcodebuild` dio 0 y el banco pasó 37/37 a solas.

**How to apply:** cualquier bucle de espera o conteo de procesos en una máquina con sesiones lanzadas: por nombre exacto
(`-x`) o por PID. Relacionado: [[el-paso-5-no-va-en-paralelo-con-el-3]].

**Y se casa a sí mismo (2026-11-16, Mini):** `until ! pgrep -f "only-testing:…"; do sleep 5; done` no acabó nunca: el `zsh -c`
del propio bucle lleva el patrón en su argv. Dos esperas quedaron 10 min colgadas. Con corchetes en el patrón
(`"[o]nly-testing:…"`) sí termina; o espera el PID con `wait`.
