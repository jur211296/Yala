---
name: el-motivo-que-cae-no-retira-el-mecanismo
description: Quité la petición de convergencia del receptor porque «su premisa ya no se cumple», y seguía cubriendo otros tres casos; lo cazó la lente de grupos (2026-09-28).
metadata:
  type: feedback
---

**Cuando mi arreglo hace falsa la premisa por la que se creó un mecanismo, no lo retiro por eso: primero enumero qué
otros casos cubre HOY, aunque nadie los escribiera.**

**Why:** el 2026-09-28 (vaciado tardío con corte por fecha) razoné «#284 pedía la convergencia porque el receptor se
llevaba la reposición del origen; con el corte ya no se la lleva ⇒ fuera la petición». La lente de grupos encontró tres
cosas que esa misma petición reponía de rebote: una real vieja que el bridge del origen conservó al reponer, la pata
vieja que hizo saltar una liquidación a la convergencia, y los grupos que el origen no tiene. Quitarla era una
regresión. Mi Paso 0 lo daba por decidido con un argumento limpio y falso.

**How to apply:**
- Para cada mecanismo que un arreglo deja «sin motivo», pregunta qué haría el sistema sin él en cada orden de llegada
  (antes/después, con y sin el dominio, filas mezcladas de las dos épocas), no solo en el caso que lo motivó.
- Si no lo puedo medir, lo mantengo y abro ticket; retirar es otra decisión.
- Relacionado: [[mi-arreglo-deja-el-mecanismo-sin-productor]], [[la-review-adversarial-caza-lo-mio]].
