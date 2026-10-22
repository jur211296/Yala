---
id: fx-unknown-currency-code-collapses-to-usd
status: backlog
priority: low
area: currency
created: 2026-09-06
updated: 2026-10-08
source: review adversarial de fx-presentation-still-shows-1to1 (2026-09-06)
---

# Una divisa fuera del catálogo se convierte en dólares sin decirlo

## Qué le pasa al usuario

`normalizeCurrencyCode` (`Yala/Utils/CurrencyUtils.swift:784`) mapea **todo código que no reconoce a
"USD"**. Un importe en una divisa fuera de las 54 del catálogo —ISK, BGN, VES, XOF, cripto— pasa a
tratarse como dólares antes de llegar al converter, así que:

- `convertChecked(1000, from: "BTC", to: "USD")` normaliza las dos a `"USD"`, entra por el
  cortocircuito de identidad y devuelve **1000 con calidad `.exact`**.
- El monto crudo se presenta como convertido, y la marca de aproximado **no puede saltar**: para el
  converter no hubo conversión que juzgar.

Es el mismo daño que `fx-partial-rate-rows-silent-1to1` —un 1:1 sellado como bueno— por una puerta
que aquel fix no tocaba, porque el colapso ocurre **aguas arriba** del converter.

## Alcance real, medido el 2026-09-06

Baja frecuencia: el catálogo cubre 54 divisas, incluidas las de mercados pequeños. Y la mayoría de
las entradas ya guardan el código normalizado (`TransactionCSVImportService` lo hace en sus cuatro
rutas), así que moneda guardada y conversión al menos concuerdan. **La excepción medida es
`GroupBalanceService:342,345,374`**, que pasa `balance.currencyCode` crudo.

## Por qué no se arregló en el ticket que lo encontró

Tocar `normalizeCurrencyCode` es tocar la SSOT de divisas de toda la app: el fallback a USD lo
consumen la UI, el import, los widgets y el canal de nube. No es un cambio de una línea y su radio
es mucho mayor que el ticket de presentación donde apareció.

**Aviso para quien lo arregle:** devolver el código original en vez de "USD" hace ALCANZABLE el
`return (merged, .exact)` de `CurrencyConverter.resolveRates`, hoy muerto por construcción — y ahí
devolvería monto crudo con calidad exacta, que es justo lo que se quiere evitar. Ese camino hay que
cerrarlo en el mismo cambio.

## Criterio de hecho (AC)

- [ ] Un código desconocido no se presenta como una conversión exacta: o se convierte de verdad, o
      se declara aproximado, o se rechaza en la entrada.
- [ ] `GroupBalanceService` normaliza antes de convertir.
- [ ] Test con un código fuera del catálogo que hoy devuelve el monto crudo con `.exact`.

## Medido en 2.1 (triage 2026-10-08)

- `normalizeCurrencyCode` vive ahora en `CurrencyUtils.swift:755`, y el fallback a USD está en `:782-783`. `convertChecked` sigue normalizando las dos puntas antes de la identidad (`CurrencyConverter.swift:235-239`).
- `GroupBalanceService.swift` sigue pasando `balance.currencyCode` y `debt.currencyCode` crudos a `convertWithLatestRate` (`:338-347`, `:373-375`).
- Los `return (merged, .exact)` de `resolveRates` están en `CurrencyConverter.swift:457` y `:488`. Ningún commit en esos ficheros desde el 06-sep.

Triage 2026-10-08: abierto · medium → low · `normalizeCurrencyCode` sigue cayendo a USD (`CurrencyUtils.swift:782`) y `GroupBalanceService` convierte códigos crudos (`:338-375`); baja frecuencia, fuera de las 54 divisas.
