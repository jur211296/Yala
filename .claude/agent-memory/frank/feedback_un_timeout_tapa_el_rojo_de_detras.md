---
name: un-timeout-tapa-el-rojo-de-detras
description: Dar plazo a un test que moría por timeout puede destapar otro rojo que el timeout escondía; el mensaje del rojo nuevo debe nombrar su causa
metadata:
  type: feedback
---

Al quitarle el timeout a un test que «solo tardaba», mide qué devuelve cada llamada antes de darlo por verde: el golden 20
del gateway (lote 12.7, 2026-10-25) llevaba semanas muriendo a los 5 s y, con plazo, salió rojo por OTRA causa —el Merkle
de staging devolvía 502 porque faltaba aplicar g24_01—. El timeout cortaba antes de llegar a esa aserción.

**Why:** un timeout no da veredicto; mientras dura, todo lo que hay detrás del primer `await` lento queda sin comprobar,
y el ticket hablaba solo del tiempo.

**How to apply:** al subir un timeout, instrumenta cada paso (tiempo y estado) en una corrida, y pon el cuerpo de la
respuesta en el mensaje de la aserción para que el rojo siguiente diga su causa. Si la causa es de otro (un DDL
pendiente), anótalo en SU card, no en un ticket nuevo. Relacionado: [[instrumentar-gana-a-razonar]].
