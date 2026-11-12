---
id: trial-says-30-days-for-a-one-month-offer
status: done
priority: low
area: pro, paywall, copy
created: 2026-10-19
updated: 2026-10-22
source: lote decidido 2.2 · 06 — Yala Pro (encargo 2026-10-19-lote-decidido-2-2-06-yala-pro, PR #561)
---

# La prueba se anuncia como «30 días» y es de un mes: en febrero la fecha de cobro cae antes

## Qué pasa

`PaywallPricingLogic.promisedTrialDays` convierte la oferta introductoria de un mes (`P1M` en `Configuration.storekit` y en App Store Connect) en «30 días». Desde el lote 06 el paywall enseña además la fecha real del primer cobro («Así funciona la prueba», con `firstChargeDate`, que suma un mes de calendario). Si la prueba empieza entre el 29 de enero y el 28 de febrero, la misma pantalla dice «30 días gratis» y una fecha a 28 días.

## Pregunta para Jürgen

- A. Dejarlo («30 días» es lo que dicen la ficha y el marketing).
- B. Decir «1 mes gratis» cuando la unidad de la oferta es el mes. ← recomendada: lo que se promete coincide con lo que cobra Apple.

Afecta a la ficha de la App Store (de Lola) si se cambia el término.

## Hecho (2026-10-22, lote decidido 2.2 · 15)

Implementada la opción que eligió Jürgen. Red: `YalaTests/UXAudit22Decidido15Tests` y `YalaUITests/Flows/SettingsLote15UITests`.
