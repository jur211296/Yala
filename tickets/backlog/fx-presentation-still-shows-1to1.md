---
id: fx-presentation-still-shows-1to1
status: backlog
priority: medium
area: currency
created: 2026-09-03
updated: 2026-09-03
source: residual explícito de fx-partial-rate-rows-silent-1to1 (decisión del owner, 2026-09-03)
---

# Lo que se guarda ya es correcto; lo que se ve en pantalla todavía puede ser un 1:1 silencioso

## Qué le pasa al usuario

Cuando a la fila de tasas de un día le falta una divisa, el monto que la app **guarda** ya se convierte
bien desde `fx-partial-rate-rows-silent-1to1`. Pero las ~34 llamadas que solo PINTAN números siguen
usando `CurrencyConverter.convert`, que ante una divisa ausente devuelve el monto crudo sin decirlo.

Panel, Tendencias, Estadísticas y los saldos de Grupos pueden mostrar un número plausible y falso.

## Por qué está separado, y no es un olvido

**Decisión del owner del 2026-09-03**, con el coste delante: el daño duradero es el disco —lo guardado
viaja por la nube y alimenta informes—, así que ese se arregló primero. Cubrir la presentación exige
tocar el protocolo `CurrencyConverting` (`CurrencyConverter.swift:26-29`), sus tres dobles de test y
los ~28 ficheros que lo inyectan como parámetro por defecto.

**El efecto que hay que tener presente es que la divergencia se INVIRTIÓ.** Antes de aquel fix, la
pantalla se veía bien (leía de la caché en memoria, con el set completo) y el disco se envenenaba.
Ahora el disco está bien y la pantalla es la que puede mentir. No es una regresión —el número en
pantalla no era más correcto antes— pero sí cambia dónde mirar al diagnosticar.

## Punto de partida medido (2026-09-03, HEAD `85ba0077`)

- `CurrencyConverter.convertChecked` ya existe y devuelve `RateQuality`: la información está, solo hay
  que llevarla al protocolo y decidir qué hace la UI con ella.
- `ExchangeRateWidgetHelper` ya resuelve esto de otra forma —omite la divisa en vez de inventar un
  número— y es el precedente de diseño del repo. Su propio defecto está en
  `fx-widget-drops-missing-currency`.
- La decisión de producto que hay que tomar antes de escribir código: **qué ve el usuario** cuando el
  número es aproximado. Hoy `isExchangeRateProvisional` tiene CERO consumidores de UI (medido): se
  escribe, se lee en un `#Predicate` y se emite por nube. Sin superficie visible, la app pasa de
  mentir con seguridad a callarse.

## No confundir con

- `fx-partial-rate-rows-silent-1to1` (en `qa/`) — la persistencia, ya arreglada.
- `distribution-balance-kpi-skips-fx` — qué base de conversión usa cada vista, no si hay tasa.
