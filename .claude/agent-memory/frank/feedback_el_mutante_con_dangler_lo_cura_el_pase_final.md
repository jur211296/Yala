---
name: el-mutante-con-dangler-lo-cura-el-pase-final
description: Un mutante que hace fallar una ref en el apply sobrevive porque el pase final de danglers la re-adjunta; para probar «el apply rompe la relación», nil sin dangler.
metadata:
  type: feedback
---

Al validar una guardia de relaciones del pull (2026-10-08, `cloud-tx-epoch-orphan-relations`), el mutante «la búsqueda
de la cuenta devuelve nil» salió VERDE: deja un dangler y el pase final del mismo `pullAndApplyOnce` lo re-adjunta. El
que mata es `m.account = nil` sin dangler.

**Why:** el primer mutante parecía probar el test y no probaba nada; lo delató un breadcrumb `danglingRef` en el log.
**How to apply:** en tests del apply, elige un mutante que esquive las redes del mismo ciclo, y léelo como información:
para que una pérdida dure, tiene que fallar en el apply Y en el pase final. Relacionado: [[la-asercion-que-no-puede-fallar]].
