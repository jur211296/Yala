---
name: el-mecanismo-existente-se-probo-con-otro-corpus
description: Reusar un barrido/reparador que ya existe sobre un corpus nuevo puede destruir datos buenos — el criterio que los selecciona es el mismo, la FORMA del daño no
metadata:
  type: feedback
---

**Cuando un ticket me manda reusar un mecanismo que ya existe, comparo la FORMA del daño del corpus
nuevo con la del corpus para el que se escribió — no basta con que el criterio de selección coincida.**

**Why:** el 2026-09-08, en `chat-rows-sealed-before-the-fix-have-no-repair-path`, el AC nombraba la
vía («si la vía elegida es un `fxOneToOneRepairSweep.v2`…») y yo la implementé del modo obvio:
rebobinar el flag y dejar que el barrido hiciera lo de siempre —marcar la fila para que el reparador
la recalculase—. Las dos poblaciones caían bajo el **mismo criterio** (`needsRepair`: tasa 1.0 +
divisa ajena), así que parecía la misma reparación. No lo era: las filas viejas tenían el monto
convertido **crudo** —recalcular solo podía mejorarlas— y las nuevas lo tenían **correcto**, con solo
la tasa falsa. Recalcular las pisaba con la conversión de hoy y, sin la tasa histórica en disco,
degradaba hasta una tabla estática congelada, con camino a pérdida permanente. **El arreglo habría
hecho más daño que el bug.** Lo destapó la review adversarial, no yo.

Y el mismo cambio de diseño cerró un segundo defecto que tampoco había visto: marcar la fila emitía
al canal nube el grupo entero con el valor envenenado **todavía puesto**, así que el barrido ganaba
por HLC y difundía el veneno en vez de curarlo.

**How to apply:** antes de reusar un reparador, barrido o migración existente sobre un corpus nuevo,
escribe **qué columna miente en cada población**. Si difieren, el mecanismo no vale tal cual, aunque
el filtro las seleccione igual. Dos preguntas que lo zanjan rápido:

- ¿El proceso al que delego **sobrescribe** algo que en este corpus ya está bien?
- Lo que se persiste al final del paso, ¿es el estado curado o el estado dañado? Si emite, viaja el
  estado final, no la intención.

Corolario: **el AC dice QUÉ, no CÓMO.** Que nombre una vía no la valida — la nombra alguien que vio
el problema, no la implementación. Ver [[feedback_mi_fix_hereda_la_forma_del_bug]] y
[[feedback_la_premisa_del_encargo_tambien_se_mide]].
