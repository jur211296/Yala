---
id: currency-change-asks-rates-for-the-old-currency
status: backlog
priority: low
area: "currency, fx"
created: 2026-09-08
source: review adversarial de repair-queue-has-no-exit-for-partial-rate-rows (2026-09-08)
updated: 2026-10-08
---

# Al cambiar de divisa preferida se piden las tasas de la divisa que se abandona

## Qué pasa

`CurrencyChangeService` llama a `ensureRates(for:context:)` —la variante sin divisas— antes de migrar
las transacciones. Esa variante pregunta por la cobertura de `getRequiredCurrencies`, que lee la
divisa preferida **actual**; y `CurrencySettingsView` escribe la nueva sólo **después** de que la
migración haya salido bien.

O sea: en el momento de pedir las tasas, la divisa preferida que consta es todavía la vieja, que es
justo la que va a dejar de hacer falta. La divisa de destino no entra en la pregunta.

## Consecuencia

La migración puede quedarse sin la tasa que necesita y marcar las transacciones como provisionales.
Se auto-curan en el arranque siguiente —el reparador ahora sí tiene salida— así que el usuario ve
números aproximados durante un rato, no para siempre.

## Por qué ahora es fácil

Desde `repair-queue-has-no-exit-for-partial-rate-rows` existe la sobrecarga
`ensureRates(for:needing:context:)`. El arreglo es pasarle `{divisa vieja, divisa nueva}`.

## Criterio de hecho (AC)

- [ ] `CurrencyChangeService` nombra las divisas que necesita en vez de heredar las de la app.
- [ ] Test: con la fila de tasas sin la divisa de DESTINO, la migración la pide.

## Medido en 2.1 (triage 2026-10-08)

- `CurrencyChangeService.updateAllTransactions` sigue llamando a `ensureRates(for:context:)` sin divisas, que delega en `getRequiredCurrencies` y lee `defaultCurrencyCode` (la vieja). Sin commits en el fichero desde el 2026-09-08.
- La divisa nueva solo entra si ya era secundaria o de alguna cuenta; si no, las transacciones quedan provisionales hasta que el reparador las cure en el arranque siguiente.

Triage 2026-10-08: abierto · low → low · `CurrencyChangeService` sigue sin nombrar la divisa de destino; el efecto se auto-cura en el siguiente arranque.
