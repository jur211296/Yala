---
id: fx-widget-drops-missing-currency
status: backlog
priority: low
area: currency
created: 2026-09-03
updated: 2026-10-08
source: 5.ª instancia del patrón, hallada al barrer fx-partial-rate-rows-silent-1to1 (2026-09-03)
---

# El widget de tasas descarta en silencio la divisa que le falta

## Qué le pasa al usuario

`ExchangeRateWidgetHelper:134` decide por que la fila de tasas EXISTA, no por que traiga la divisa que
necesita. Es la quinta instancia del mismo patrón que arregló
`fx-partial-rate-rows-silent-1to1`, pero **falla distinto y mejor**: en vez de convertir 1:1, omite la
divisa. El usuario no ve un número falso; ve que su divisa desapareció del widget, sin explicación.

## Por qué es `low` y por qué existe el ticket igualmente

No persiste nada y no envenena el disco: el daño es de presentación y reversible en cuanto llegan las
tasas. Se dejó fuera del ticket madre **por decisión explícita**, no por descuido — y ésa es la razón
de anotarlo: sin ticket, el próximo barrido del patrón lo encuentra otra vez y lo trata como
hallazgo nuevo.

Nota de diseño que conviene no perder: su comportamiento —omitir en vez de inventar— es el
**precedente honesto** del repo, el que `fx-presentation-still-shows-1to1` va a necesitar como molde.
No hay ni un test que lo fije, así que hoy nada impide que alguien lo "arregle" convirtiéndolo a 1:1.

## Medido en 2.1 (triage 2026-10-08)

- `ExchangeRateWidgetHelper.getAverageRatesForBucket` sigue eligiendo por la EXISTENCIA de la fila (`getRate(for:)`, y solo si no hay fila, `getMostRecentRate`); si la fila no trae la divisa, `calculateRatesFromPreferred` la omite y no se busca otra fila. Sin commits en el fichero desde el 2026-09-03.
- Sigue sin un test que fije «omitir, no inventar 1:1».

Triage 2026-10-08: abierto · low → low · el widget sigue omitiendo la divisa cuando la fila del día no la trae; es de presentación y se cura al llegar las tasas.
