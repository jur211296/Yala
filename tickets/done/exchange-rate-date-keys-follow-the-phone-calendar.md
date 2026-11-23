---
id: exchange-rate-date-keys-follow-the-phone-calendar
status: qa
priority: medium
area: cloud
created: 2026-09-26
updated: 2026-11-22
source: encargo 2026-09-26-claude-mcp-numbers-match-the-app (review adversarial, lente de tasas)
---

# Con el calendario budista o japonés, las filas de tasas se guardan con otro año

## Qué cambia para el usuario

Un usuario con el iPhone en calendario budista (Tailandia) o japonés podría ver sus importes en otra divisa
convertidos con la tabla estática en vez de con la cotización del día, y subir a la nube filas de tasas con claves
como `2569-09-26` que ningún otro dispositivo ni el conector de Claude encuentran.

## Lo que hay (INFERIDO leyendo el código, no medido en un dispositivo)

- El `DateFormatter` de `CurrencyConverter` (`Yala/Services/CurrencyConverter.swift`, propiedad `dateFormatter`) y el
  de `ExchangeRateService` fijan `dateFormat = "yyyy-MM-dd"` y la zona UTC, pero **no** `locale = en_US_POSIX` ni
  calendario gregoriano. Con otro calendario del sistema, `yyyy` es el año de ese calendario.
- La clave `date_key` viaja al backend tal cual, y el conector (`mcp/src/logic/fx.ts`) busca claves gregorianas.

## Qué hay que hacer

1. Medirlo: simulador con calendario budista, convertir un importe y mirar la `dateKey` guardada.
2. Si se confirma: fijar `locale = Locale(identifier: "en_US_POSIX")` y `calendar = Calendar(identifier: .gregorian)`
   en los dos formatters, y decidir qué hacer con las filas ya guardadas con otra era (re-clave o descartarlas).

## Cómo se sabe que está bien

Con el iPhone en calendario budista, la fila de hoy se guarda como `2026-…` y la conversión es exacta.

## Medido en 2.1 (triage 2026-10-08)

- Los dos `DateFormatter` siguen igual: `CurrencyConverter.dateFormatter` y `ExchangeRateService.dateFormatter` fijan `dateFormat = "yyyy-MM-dd"` y zona UTC, sin `locale = en_US_POSIX` ni calendario gregoriano. Sin commits en esos ficheros desde el 2026-09-26.
- Un `DateFormatter` sin `locale` fijo toma el calendario del sistema (lo documenta la QA1480 de Apple para formatos fijos). El calendario lo decide la región, no el idioma: en Tailandia el budista es el de serie. La app trae `ja.lproj`.
- Sigue sin medir en simulador (paso 1 del cuerpo); la subida a `medium` se apoya en el comportamiento documentado del formatter, no en una medida.

Triage 2026-10-08: abierto · low → medium · los formatters siguen sin en_US_POSIX ni gregoriano; para toda una región (Tailandia, budista de serie) los importes en otra divisa se convertirían con la tabla aproximada, y el arreglo son dos líneas.

## Construido (2026-11-22, encargo «Tasas de cambio»): espera el device-QA de abajo

- Los tres formatters que escriben o piden claves (`CurrencyConverter`, `ExchangeRateService`, `ExchangeRateAPIService`)
  fijan `locale = en_US_POSIX` y calendario gregoriano.
- **Filas ya guardadas con otra era: se descartan**, no se re-claven (el año japonés no dice de qué era es; la tasa se
  vuelve a pedir si hace falta). Las borra la limpieza diaria de `ExchangeRateService`
  (`ExchangeRateDuplicateLogic.isImplausibleDateKey`: año fuera de 1900…actual+1, o clave mal formada).
- **Pruebas:** `TasasDeCambioLogicTests` reproduce el `2569-11-22` de un formatter sin calendario, fija los tres
  formatters por código y cubre las claves imposibles; `TasasDeCambioLimpiezaTests` borra `2569-…` y `0008-…`.
- **No medido en un dispositivo** con el calendario budista: device-QA abajo.
- **Fuera del toca, sin tocar:** `CurrencySettingsView`, `ExchangeRatesSheet` y `PanelViewModel` parsean una clave para
  enseñar «última actualización» con un formatter sin calendario fijo; con el budista enseñarían otro año.

### Device-QA (cuando se pueda)
1. iPhone 14 → Ajustes → General → Idioma y región → Calendario → Budista.
2. Abrir Yala con una cuenta en otra divisa: el importe convertido sale sin «≈» (tasa del día, no la tabla estática).
