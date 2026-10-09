---
id: widget-de-tc-no-localiza-separadores
status: backlog
priority: low
area: panel/currency
created: 2026-09-07
source: review adversarial de fx-pnl-education-card (2026-09-07)
---

# El widget de tipos de cambio escribe «3.8000» a un usuario que lee «3,8»

## Qué le pasa al usuario

En español el separador decimal es la coma. El widget «Tipos de cambio» del Panel pinta
«1 USD = 3.8000 PEN» con un punto, porque construye el número con `String(format: "%.4f")`
(`ExchangeRateWidget.swift:320` y `:495`), que **no localiza**. La hoja de detalle de ganancia
cambiaria, en la misma pantalla, escribe «3,8» con `NumberFormatter`.

Dos escrituras del mismo dato, a un scroll de distancia.

## Criterio de hecho (AC)

- [ ] El widget formatea la tasa con `NumberFormatter` localizado, como el resto de la app.
- [ ] Comprobado en un locale con coma decimal (es) y en uno con punto (en).
