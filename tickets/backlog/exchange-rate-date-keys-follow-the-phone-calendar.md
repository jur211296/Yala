---
id: exchange-rate-date-keys-follow-the-phone-calendar
status: backlog
priority: low
area: cloud
created: 2026-09-26
updated: 2026-09-26
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
