---
name: xcuitest-con-chips-y-semilla-saldada
description: Con chips bajo el título, scrollViews.firstMatch es la fila de chips; y grupos-saldado deja pares cruzados con «Menos pagos» apagado.
metadata:
  type: reference
---

Dos trampas medidas el 2026-11-26 (lote 1 de Compartido, iPhone 17 Pro, iOS 27.2):

- Una pantalla con barra de chips (`navigationChipsInset`) tiene DOS scrolls: `app.scrollViews.firstMatch` es la fila
  horizontal de chips, y `swipeUp` sobre ella no mueve la lista. La captura «al bajar» salió igual que la de arriba.
  Se arrastra sobre la app (`app.swipeUp`).
- La semilla `grupos-saldado` deja tu NETO de cada grupo en cero, no cada par: en «Viaje a Cusco», con «Menos pagos»
  apagado, Ana te debe 80 y le debes 80 a Beto (la tarjeta de grupo lo enseña igual). Solo «Viaje a Lima» deja a Caro
  a mano. Un caso que espere «nadie pendiente» con esa semilla cae.

**How to apply:** al capturar o probar una pantalla con chips, y al elegir semilla para «todo saldado» por persona.
