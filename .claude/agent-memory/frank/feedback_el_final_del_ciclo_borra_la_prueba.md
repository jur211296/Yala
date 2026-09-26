---
name: el-final-del-ciclo-borra-la-prueba
description: Una sonda que lee estado DESPUÉS de un ciclo tiene que mirar qué hace el FINAL del ciclo con ese estado; la purga del History borraba la edición y caducaba el token que la sonda leía.
metadata:
  type: feedback
---

**Antes de leer un estado al terminar un ciclo para decidir algo, lista qué le hace a ese estado la COLA del ciclo.**

**Why:** el 2026-09-26 (ticket `personal-sign-out-reads-an-unfinished-drain-as-nothing-pending`) diseñé «tras el ciclo,
pregunta a la sonda del History» tal como pedían ticket y encargo. El primer test lo tumbó dos veces: la purga del final
del ciclo (`purgeHistoryOnce`, corte en `now`) **borraba la edición del drain abortado** —la sonda decía «nada pendiente»,
el criterio 1 era imposible— y **caducaba el token** del cursor, así que tras un ciclo sano la sonda devolvía `nil` y
habría bloqueado TODOS los cierres en la nube. Ni el ticket ni el encargo sabían de la purga; la leí porque el log del
test decía `historyPurged count=6`.

**How to apply:**
- Si el diseño es «haz X y luego lee Y», lee el cuerpo entero de X hasta su último paso y busca quién BORRA o
  REESCRIBE Y (purgas, compactaciones, reanclajes de cursor, limpiezas «por si acaso»).
- El primer test de punta a punta va con el ciclo REAL, no con la sonda aislada: la sonda sola pasaba en verde.
- Relacionado: [[la-premisa-del-encargo-tambien-se-mide]], [[el-testigo-vive-menos-que-lo-que-describe]].
