---
name: el-guion-de-ciclos-dispara-tirar-para-actualizar
description: El guion de ciclos del análisis del calor (6 abajo + 6 arriba) llega al tope del Panel y dispara «tirar para actualizar»: un recálculo de 7,5 s que parece de la vuelta
metadata:
  type: feedback
---

Midiendo el lote 1 de eficiencia (26-nov-2026, iPhone 14, 16 k movimientos), el «después» seguía con un cuelgue de ~7,5 s
en 8 de 10 vueltas y parecía que la vuelta aún recalculaba. No: el guion `ciclos.sh` desliza 6 veces hacia abajo y 6
hacia arriba, el sexto hacia arriba llega al tope y dispara `PanelView.refreshData` («tirar para actualizar»). La consola
decía «volver al Panel → sin cambios, no recarga» y aun así corría `performCalculation`; una copia instrumentada con
`Thread.callStackSymbols` en `scheduleRecalculation` nombró al llamador.

**Why:** costó una pasada entera y casi un diagnóstico falso («la firma no funciona»). El informe del calor ya lo había
visto en su pasada H, pero no corrigió el guion.

**How to apply:** para medir la vuelta, `SUBE=3` (la copia con esa variable está en
`docs/qa/rendimiento-iphone14-2026-11-26/despues-eficiencia-1-volver-sin-recalcular/scripts/ciclos.sh`), y antes y
después con el mismo guion. Ante un recálculo que «no debería estar», instrumenta la COPIA de perfilado (nunca el árbol)
con la pila del que pide, no adivines por la traza: el recálculo corre en una `Task` y su pila no dice quién lo pidió.
Los cuelgues se cuentan con Yala delante (vuelta → siguiente salida), o los ~280 ms de la foto de widgets al irse se
atribuyen a la vuelta anterior. Ver [[medir-release-en-el-iphone-con-semilla]], [[el-iphone-14-se-mide-desde-la-max]].
