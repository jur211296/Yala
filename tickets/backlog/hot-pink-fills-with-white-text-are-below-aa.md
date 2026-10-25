---
id: hot-pink-fills-with-white-text-are-below-aa
status: backlog
priority: very-low
area: "design-system, accesibilidad"
created: 2026-10-25
updated: 2026-10-25
source: "lote 12.3 (card lbcr), visto al barrer el texto sobre rellenos"
---

# Dos rellenos rosa de marca llevan texto blanco por debajo de AA

`hotPink` (#FF0080) con blanco encima da 3,77:1 (AA pide 4,5 para texto normal). Quedan dos sitios que no dependen del
tema y no entraron en el lote 12.3:

- Los chips de porcentaje elegidos de la calculadora de reparto (`SplitCalculatorSheet.percentagePresets`).
- La etiqueta de ahorro del plan elegido en la compra de Pro (`ProPurchaseComponents`, `subscription_save_badge`).

El molde ya existe: `Color.emphasisPinkFill` (#D6006B, 5,2:1 con blanco), el rosa profundo de la tarjeta «¿No sabes tu
saldo?». Cambiarlo es cambiar el rosa de esos dos chips; por eso no se tocó sin decisión.
