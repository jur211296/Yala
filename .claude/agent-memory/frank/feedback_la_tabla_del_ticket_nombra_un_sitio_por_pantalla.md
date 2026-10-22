---
name: la-tabla-del-ticket-nombra-un-sitio-por-pantalla
description: Una tabla de «dónde pasa» lista un sitio por pantalla, no todos; el patrón se cuenta en el fichero entero, y aparecen pantallas que la tabla no nombra — a veces en ficheros que un ticket anterior ya arregló.
metadata:
  type: feedback
---

Cuando un ticket trae una tabla «superficie → fichero:línea», trátala como el **índice**, no como el
inventario. Cuenta el patrón tú, fichero por fichero.

**Why:** el 9-sep las 7 superficies de la tabla eran **21 sitios**. Flujo de caja citaba dos y tenía
cinco importes de período más la etiqueta de VoiceOver del gráfico; Registros citaba uno y tenía
tres; Estadísticas, uno y tenía tres. Y aparecieron **dos pantallas que la tabla no nombra**, las dos
en ficheros que el ticket anterior ya había tocado. La peor: en `HeroMonthView` el MISMO
`periodSummary.expense` se pintaba **dos veces en la misma vista** —con la marca en el hero de Solo
Gastos, sin ella en la píldora de gasto—, así que el mismo número del mismo mes salía marcado o
exacto según el modo. Es el corolario del `CLAUDE.md` otra vez: que un fichero esté en la lista de
arreglados no significa que lo estén todas sus ramas.

**How to apply:** por cada fila de la tabla, `grep -n` del componente que pinta (aquí `AmountText(`)
en el fichero ENTERO y clasifica cada ocurrencia: la lleva, o no la lleva y **por qué** queda escrito
ahí mismo. Después, el barrido transversal: `grep -rn "value: summary\.\|value: periodSummary\."` en
`Views/` encuentra las pantallas que la tabla no nombra. Las dos que aparecieron el 9-sep salieron
de ese segundo grep, no del primero.

Y **la premisa de aplazamiento también se mide** — es la familia de
[[la-premisa-del-encargo-tambien-se-mide]]. Ese ticket aplazaba el widget de inicio citando
`fx-widget-drops-missing-currency`, pero ese ticket habla de otro fichero (el widget de TASAS): el
de inicio no esperaba ninguna decisión y se cerró el mismo día. En el mismo repaso, el docblock que
justificaba un campo retirado apuntaba a un ticket que **no existe en `tickets/`**. Los punteros a
tickets dentro de docblocks caducan como cualquier otra coordenada: compruébalos con un `ls`.
