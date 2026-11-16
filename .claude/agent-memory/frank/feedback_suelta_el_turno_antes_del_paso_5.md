---
name: feedback-suelta-el-turno-antes-del-paso-5
description: Si sostienes el simulador con sim-lock.sh -- sleep para QA manual, suéltalo antes del paso 5 del gate; y el chequeo de seguridad de Bash rechaza rm -rf $VAR y ${(f)…} de zsh
metadata:
  type: feedback
---

Al sostener el turno del simulador con `bash qa/scripts/sim-lock.sh -- sleep 7200` para capturas y QA manual, el paso 5
del gate (`gate-ci-checks.sh` → `sim-lock-test.sh`) pide el turno real y **espera a tu propio `sleep`**: el gate se
queda parado sin decir por qué (16-nov, 10 min perdidos). Los pasos 2 y 3 entran con `YALA_SIM_LOCK_HELD`; el 5 no.

**Why:** `sim-lock-test.sh` levanta procesos que se llaman `xcodebuild` y necesita el turno de verdad, no reentrar.

**How to apply:** cuando acabes con el simulador, `TaskStop` del `sleep` ANTES de lanzar el paso 5. Y para los comandos
del gate: el chequeo de seguridad de Bash rechaza `rm -rf $VAR/...` y no entiende `${(f)"$(cat …)"}` de zsh (lo trata
como posible borrado). Escribe el comando en un script bash en el scratchpad, con arrays bash y sin borrar: un nombre de
`.xcresult` nuevo por corrida en vez de borrar el viejo. Relacionado: [[feedback-gate-en-serie-tambien-contra-ti]].
