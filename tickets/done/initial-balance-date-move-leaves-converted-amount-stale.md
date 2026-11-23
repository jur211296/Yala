---
id: initial-balance-date-move-leaves-converted-amount-stale
status: backlog
priority: medium
area: "currency, fx, import"
created: 2026-09-08
updated: 2026-10-08
source: barrido del patrón de bulk-update-account-leaves-converted-amount-stale (2026-09-08)
---

# Mover la fecha del saldo inicial deja el monto convertido con la tasa del día viejo

## Qué pasa

`Yala/Services/InitialBalanceService.swift:254` retrocede la fecha de la transacción de saldo inicial
cuando un import trae movimientos más antiguos que ella:

```swift
if newDate < initialBalanceTx.date {
    initialBalanceTx.date = newDate     // ← cambia el input de la tasa histórica
}
```

La **fecha es input de la conversión**: `recalculatePreferredCurrency` convierte `on: date`, así que
la tasa aplicable es la de ese día. Al mover la fecha y no recomputar, las cuatro columnas del grupo
`money` (`amountInPreferredCurrency`, `exchangeRate`, `preferredCurrencyCode`,
`isExchangeRateProvisional`) se quedan con la tasa del día **anterior**.

Es el mismo patrón que `bulk-update-account-leaves-converted-amount-stale` —escribir un input de la
conversión sobre una fila ya persistida sin recomputar las derivadas— pero por el tercer input, la
fecha, en vez de por la divisa.

## Alcance, medido

- **Cuatro llamadores, todos del import CSV**: `TransactionCSVImportService.swift:229`, `:1149`,
  `:1541`, `:1703`. El `save()` lo hace el llamador (`ImportIntroSheet.swift:559` y `:670`), así que
  el cambio sí llega a disco.
- **Solo afecta a cuentas en divisa distinta de la preferida.** Si la cuenta está en la divisa
  preferida la conversión es la identidad en cualquier fecha y mover el día no cambia nada.
- **No hay red detrás.** `ExchangeRateService.ensureRatesForExistingTransactions` sí repararía filas
  así, pero **no tiene llamador** — ticket propio:
  `ensure-rates-for-existing-transactions-has-no-callers`. Y el reparador de tasas tampoco la alcanza,
  aunque el motivo no es el que parece: `TransactionUpdateService` tiene **dos** barridos, y solo el
  segundo (`:247`) filtra por `isExchangeRateProvisional == true`. El primero (`:146`) busca
  `exchangeRate == 1.0` y trabaja justamente sobre las NO provisionales (`:169`). Ninguno la coge: una
  fila en divisa extranjera tiene `exchangeRate != 1.0`, así que se escapa del primero por el
  predicado y del segundo por el flag.

El tamaño del error es la variación de la tasa entre la fecha vieja y la nueva. Con un CSV que trae
años de histórico —que es justo cuando la fecha se mueve— puede ser grande, y queda sellado como
definitivo.

## Por qué `medium` y no `high`

Pide una cuenta en divisa extranjera **y** un import con movimientos anteriores al saldo inicial. Es
una combinación acotada, pero cuando ocurre el número queda mal para siempre y sin ruta de auto-cura.

## Criterio de hecho (AC)

- [ ] `updateInitialBalanceDateIfNeeded` recomputa las derivadas tras mover la fecha, o el llamador lo
      hace antes de guardar. Decidir dónde: la función hoy no guarda, y meterle un `save()` cambiaría
      su contrato con los cuatro llamadores.
- [ ] Test: cuenta en divisa extranjera + saldo inicial + import que retrocede la fecha ⇒ el monto
      convertido corresponde a la tasa de la fecha NUEVA. Sembrar dos días con tasas distintas para
      que el testigo distinga.
- [ ] Verificar el mutante: sin el recálculo, el test debe caer.

## Medido en 2.1 (triage 2026-10-08)

- `InitialBalanceService.swift:241-256`: el `if newDate < initialBalanceTx.date { initialBalanceTx.date = newDate }` sigue sin `recalculatePreferredCurrency`. El servicio no tiene commits desde el 2026-09-08.
- Llamadores, sin cambio: `TransactionCSVImportService.swift:229`, `:1149`, `:1541` y `:1703`.
- Relación con `converted-amount-sweep-blind-to-input-changes`: es su control positivo, un hijo y no un duplicado. Aquel pone el detector y éste arregla el caso.

Triage 2026-10-08: abierto · medium → medium · no es duplicado: el barrido de `converted-amount-sweep-blind-to-input-changes` lo detectaría pero no lo arregla; `updateInitialBalanceDateIfNeeded` sigue moviendo la fecha sin recomputar (`InitialBalanceService.swift:253-255`).
