---
name: fx-pnl-card
description: La tarjeta de ganancia/pérdida cambiaria del Panel (PR #92, 7-sep). Qué falta, y por qué el cálculo es FIFO y no un promedio — con los dos escenarios que invertían el signo.
metadata:
  type: project
---

**La tarjeta de ganancia/pérdida por tipo de cambio está en código y mergeada** (PR #92, 2026-09-07).
Free, por decisión de Jürgen del 6-sep. Lo único que falta es **device-QA**, y no es simulable.

**Why:** el usuario multi-divisa ve un saldo que no cuadra con lo que recuerda haber ingresado. Las
hojas informativas explicaban el porqué; faltaba el cuánto.

**How to apply:**

- **El device-QA está bloqueado por datos, no por tiempo.** Hace falta una cuenta multi-moneda con
  histórico real, y **ningún seed de UI test la produce** (son todos PEN). La tarjeta no aparece en
  XCUITest y su cobertura de UI es cero por construcción. No prometas cubrirlo con un XCUITest sin
  crear antes un perfil de seed multi-divisa.
- **Si alguien propone «simplificar» el FIFO a un promedio ponderado, es una regresión con dos
  escenarios medidos que la refutan**, y están fijados como tests: un gasto intermedio arrastra el
  coste de entrada (comprar 1.000 USD a 3,00 y revenderlos mueve el coste de 100 dólares comprados a
  4,00 → la tarjeta anuncia GANANCIA a quien perdió) y un traspaso entre cuentas propias empuja el
  número de +300 a +33. Los dos cambian el **signo**, no la magnitud.
- **El umbral se mide contra la exposición a divisa, no contra el balance.** Con el balance
  degenera: un saldo cercano a cero, o posiciones que se cancelan, hacen que el 0,5 % sea ~0 y la
  tarjeta no se va nunca. El AC del ticket proponía el balance; está desviado a propósito y escrito.
- **La condición de visibilidad vive DENTRO de la card, no en el callsite del Panel**, y hay dos
  razones medidas: con el `if` fuera, cruzar el umbral mientras el usuario lee el detalle destruye la
  hoja abierta en su cara; y leer ahí la propiedad `@Observable` invalida `PanelView` entero. Si
  alguien la «limpia» devolviendo el `if` al callsite, el source-scan `FXPnLWiringTests` se pone
  rojo — está puesto para eso.

**Lo que salió de camino y tiene ticket propio** (no se arregló aquí, son tres preexistentes y uno de
otro widget): `panel-no-recalcula-al-llegar-tasas-nuevas`, `reparacion-de-tasas-no-avisa-al-panel`,
`hoja-del-saldo-vivo-ignora-los-filtros-de-sesion` y `widget-de-tc-no-localiza-separadores`.

Relacionado: [[review-adversarial-caza-lo-mio]] (aquí cazó diez, todos míos) ·
[[mi-fix-hereda-la-forma-del-bug]] (el `if` sin su `else`) ·
[[la-premisa-del-encargo-tambien-se-mide]] (la sección «Para ti» del ticket no existe).
