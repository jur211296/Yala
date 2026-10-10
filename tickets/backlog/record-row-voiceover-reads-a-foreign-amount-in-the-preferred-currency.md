---
id: record-row-voiceover-reads-a-foreign-amount-in-the-preferred-currency
status: backlog
priority: medium
area: "records, accessibility, currency"
created: 2026-10-09
source: hallazgo de camino en exchange-rate-detail-shows-zero-for-low-denomination-currencies (2026-10-09)
---

# VoiceOver lee un gasto en dongs como si fuera en soles

## Qué le pasa al usuario

En Registros, un gasto de 9.064.482 ₫ se ve bien en pantalla, pero VoiceOver lo lee como
**«S/ 9.064.482,03»**: el importe nativo con el símbolo de la divisa preferida. Quien usa VoiceOver
oye que gastó nueve millones de soles.

## Lo medido (2026-10-09, simulador, seed `realista` + `-uitest-seed-foreign-account VND`)

La etiqueta de accesibilidad de la fila (`record_row`) sale
`QA-FX VND, S/ 9.064.482,03, Viajes y vacaciones, QA FX`, mientras el texto visible pinta «₫ -9.064.482,03».

`RecordRowView.accessibilityDescription` formatea `abs(record.amount)` (importe NATIVO) con
`currencyCode`, la propiedad que recibe la vista, y `RecordsTabView` le pasa `defaultCurrencyCode`
(la preferida). El importe visible usa `record.currencyCode` (L94 y L249 del mismo fichero).

## Criterio de hecho (AC)

- [ ] La etiqueta de accesibilidad usa la divisa del registro, igual que el importe visible.
- [ ] Test que lo fije con un registro en divisa distinta de la preferida.
- [ ] Buscar el mismo patrón (importe nativo + divisa preferida) en otras filas con `accessibilityLabel`.
