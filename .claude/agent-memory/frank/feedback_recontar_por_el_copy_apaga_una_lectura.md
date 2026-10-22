---
name: recontar-por-el-copy-apaga-una-lectura
description: Cambié CUÁNDO se cuenta una oferta para que su texto fuera exacto, y apagué la lectura del History de la que dependía una comprobación posterior sin captura.
metadata:
  type: feedback
---

Antes de cambiar el ORDEN o el ESTADO con el que se calcula algo «para que el texto sea exacto», enumera **quién más
lee ese cálculo después** y qué deja de ver con el estado nuevo.

**Why:** el 2026-10-05 (`stuck-groups-loss-without-a-count-covers-own-edits-made-after-the-notice`) moví el recuento de
la oferta de la celda C para hacerlo con lo aceptado ya retirado: así, con la captura curada y el History ilegible, el
aviso no diría «no se pudieron preparar». Pero `groupsLossUncaptured` solo lee el History con la captura atascada **o
con lo aceptado puesto**, y la comprobación pegada al arm —que no captura— dependía de esa segunda mitad para ver un
cambio apuntado tras el aviso. Con mi recuento, cuenta vacía ⇒ `return false` ⇒ el borrado se lo llevaba. Lo cazó la
lente de datos de la review; la de copy había validado mi texto. Era la red que una review ANTERIOR había puesto a
propósito (lente 1 del mismo día), documentada en el docblock de la función que leí y no relacioné.

**How to apply:** si un ajuste es «solo de copy» pero toca qué estado ve una función de recuento, trátalo como cambio de
datos: busca los llamadores del recuento (aquí, el mismo método llamado desde dos sitios con y sin captura previa) y
pregunta qué ve cada uno. Ante la duda, gana la lectura que protege datos y el texto se queda menos preciso.
Relacionado: [[mi-arreglo-quita-la-salida-que-habia]], [[el-testigo-vive-menos-que-lo-que-describe]].
