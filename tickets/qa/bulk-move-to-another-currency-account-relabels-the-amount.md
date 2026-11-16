---
id: bulk-move-to-another-currency-account-relabels-the-amount
status: qa
priority: medium
area: "transactions, bulk-edit, currency, fx"
created: 2026-10-08
updated: 2026-11-06
source: análisis de impacto de multi-currency-accounts (2026-10-08)
---

# Mover movimientos en lote a una cuenta de otra divisa reetiqueta el importe sin convertirlo

## Qué le pasa al usuario

Selecciona en Registros varios gastos de su cuenta en dólares y, con la edición en lote, los mueve a
su cuenta en soles. Un gasto de **50 USD pasa a ser 50 PEN**. El número se queda y la divisa cambia:
no se convirtió, se reetiquetó. A precio de hoy desaparecen unos 137 soles por cada gasto movido, sin
aviso.

## Lo medido (2026-10-08, árbol `e755b0d64`; no ejecutado)

`Yala/App/ViewModels/RecordsViewModel.swift`, `bulkUpdateAccount`:

```swift
for transaction in transactions {
    transaction.account = account
    transaction.currencyCode = account.currencyCode
    transaction.recalculatePreferredCurrency(context: context)
}
```

- El importe (`amount`) no se toca. Solo cambia la etiqueta de divisa y se recalculan las columnas
  derivadas.
- El editor en lote abre el selector de cuentas **sin filtro de divisa**:
  `BulkEditSheet.swift:153` (`AccountSelectorSheet(selectedAccount:)`) y `:271`.
- El test que cubre esta ruta, `YalaTests/RecordsViewModelBulkAccountCurrencyTests` (nacido en
  `bulk-update-account-leaves-converted-amount-stale`), comprueba que las derivadas se recalculan.
  **Fija el reetiquetado como contrato**: no pregunta qué pasa con el importe.
- El propio formulario lo da por pendiente. `NewTransactionViewModel.amountCurrencyCode` dice «mover
  una fila de cuenta es otro problema» y apunta al ticket de derivadas, que ya está cerrado.

## Por qué es medium

Requiere mover a propósito movimientos entre cuentas de distinta divisa, que no es lo habitual. Pero
cuando pasa, el daño es silencioso y llega al historial, que la decisión 2A del 2026-10-07 quiere
intacto.

## Criterio de hecho (AC)

- [ ] Decidido qué hace la edición en lote al mover a una cuenta de otra divisa: convertir el importe
      con la tasa de la fecha de cada fila (como `AccountCurrencyMigrationService`), bloquear y
      explicar por qué, o filtrar el selector a cuentas de la misma divisa.
- [ ] Test con un gasto en USD movido a una cuenta en PEN, con una tasa distinta de 1, que discrimine
      entre reetiquetar y convertir, con control rojo.

## Relacionados

- `saving-a-mismatched-transaction-relabels-it-without-converting`: el mismo reetiquetado, en el
  formulario.
- `save-as-favorite-from-a-mismatched-row-relabels-it`: el mismo, en favoritos.
- `bulk-update-account-leaves-converted-amount-stale` (done): arregló las derivadas de esta ruta, no
  el importe.
- `multi-currency-accounts`: con la opción A recomendada, mover entre líneas de una misma tarjeta
  pasa por aquí (`docs/multi-currency-accounts-impact-2026-10.md`).

## 2026-11-06 · Arreglado: se convierte con la tasa del día de cada movimiento

- Decisión (la del encargo, sin pregunta de producto abierta): **convertir**, con
  `AccountCurrencyMigrationService.convertHistory`, la misma pieza del cambio de divisa de una cuenta. Cada fila pasa
  a la divisa de la cuenta destino con la tasa de SU fecha; con la tasa que hay guardada (sin pedir a la red antes),
  así que si falta la del día usa la más cercana o la tabla estática, como el resto de la app. Grupos en otra divisa y
  transferencias siguen bloqueados como antes.
- El aviso de la hoja decía «se actualizará la moneda»; ahora «los montos se convertirán a la moneda de la cuenta nueva
  con el tipo de cambio de su fecha», en los 16 idiomas.
- Tests: `RecordsViewModelBulkAccountCurrencyTests` (los dos casos fijaban el reetiquetado como contrato; ahora fijan
  la conversión), con control rojo: sin la línea de la conversión caen los dos.
- Medido en el simulador: «Electricista» S/ 60.00 movido a «Ahorros USD» quedaba en $ 60.00 (base) y ahora en $ 16.39.
- QA: Registros › Seleccionar dos gastos en soles › Editar › Cuenta › una en dólares › Aplicar. Los montos salen
  convertidos, no con el mismo número.
