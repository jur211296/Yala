---
id: saving-a-mismatched-transaction-relabels-it-without-converting
status: qa
priority: medium
area: "transactions, currency, fx"
created: 2026-09-08
updated: 2026-10-08
source: barrido de chat-draft-stamps-its-own-currency-not-the-account (2026-09-08)
---

# Guardar una transacción desemparejada la reetiqueta sin re-expresar el importe

## Qué le pasa al usuario

Tiene una transacción de **50 USD dentro de una cuenta en soles** (llegó por el chat antes del
arreglo, o porque se editó la divisa de la cuenta). La abre en el formulario, no toca nada y pulsa
Guardar. Sale **50 PEN**. El número se queda igual y la divisa cambia: no se convirtió, se
reetiquetó. A precio de hoy eso son unos 187 soles que desaparecen del histórico sin aviso.

## Lo medido (2026-09-08)

`NewTransactionViewModel` guarda siempre con la divisa de la cuenta —`:641` al editar, `:658` al
crear— y el importe viaja intacto (`finalAmount`). La conversión parte de `account.currencyCode`
(`:609`), así que las derivadas quedan coherentes **entre sí**: lo que se pierde es la relación con
el importe que el usuario tenía delante.

Y la vista **ya sabe que el caso existe**. `NewTransactionView.swift:676-681` lo dice literalmente:

```swift
// Use viewModel.currencyCode (transaction's currency), NOT effectiveCurrencyCode (account's currency)
// This handles cases where transaction is in USD but account is in PEN
```

Carga la divisa de la transacción al editar (`:1491`) y la tasa desde ella (`:1553-1585`). Es decir:
la pantalla está preparada para **mostrar** el desemparejamiento, y el guardado lo borra sin
convertir.

MEDIDO en el código; **no ejecutado** en simulador.

## Por qué es medium y no high

Requiere que exista una fila ya desemparejada, y desde hoy el chat ya no las crea
(`chat-draft-stamps-its-own-currency-not-the-account`). Su generador vivo es
`changing-an-account-currency-orphans-its-whole-history`, que va aparte y es **high**. Visto de otro
modo, esto es hoy la única «curación» disponible para una fila desemparejada — solo que cura
perdiendo dinero.

## Criterio de hecho (AC)

- [x] Decidido qué hace Guardar ante una fila cuya divisa no es la de su cuenta: convertir el
      importe, avisar, o dejarlo como está.
- [x] Test con una transacción desemparejada de partida que fije la decisión.

## Relacionados

- `changing-an-account-currency-orphans-its-whole-history` (high) — quien las produce hoy.
- `bulk-update-account-leaves-converted-amount-stale` — el mismo patrón en la ruta de servicio.

## Decisión de Jürgen (2026-10-07)

Opción 2A, la misma en los tres tickets de moneda: **antes de cambiar la moneda de una cuenta, Yala avisa y muestra qué se
va a convertir; los pagos programados y los favoritos se convierten a la tasa de hoy; el historial no se toca.**

Los tres tickets que la comparten:
- `account-currency-change-leaves-scheduled-and-favorites-stale`
- `saving-a-mismatched-transaction-relabels-it-without-converting`
- `cloudsync-account-currency-orphans-receiver-history`

A qué parte corresponde: este ticket no tiene opciones con nombre; su AC es «decidido qué hace Guardar ante una fila
cuya divisa no es la de su cuenta». La parte de la decisión que le toca es **«el historial no se toca»**. Lectura de esta
sesión, por confirmar antes de implementar: una transacción ya guardada no se reetiqueta ni se re-expresa al darle a
Guardar sin cambios; conserva su importe y su divisa. Lo que hoy hace Guardar (reetiquetar con la divisa de la cuenta)
es justo lo que la decisión prohíbe.

**Confirmado por Jürgen el 2026-10-08 (04:00 Lima):** el historial se queda como está. La lectura de arriba —Guardar sin
cambios conserva importe y divisa— queda confirmada.

## Lo que se hizo (2026-10-08)

**Para la persona:** un movimiento de 50 USD dentro de una cuenta en soles se abre enseñando «$ 50» (antes «S/ 50») y,
guardado sin tocar nada, sigue siendo 50 USD. Si cambia el importe a 60, se guarda 60 USD: la divisa que la pantalla le
enseña. Si elige otra cuenta, manda la divisa de esa cuenta, como siempre (mover de cuenta es
`bulk-update-account-leaves-converted-amount-stale`).

**Código:** `NewTransactionViewModel.amountCurrencyCode` (la de la transacción al editar sin cambiar de cuenta; si no,
la de la cuenta) decide el símbolo del importe, la calculadora de split, la pantalla de éxito y lo que se guarda,
incluida la conversión a la divisa preferida. Los atajos «guardar como favorito / programado» siguen con la divisa de
la cuenta: no se tocó lo adyacente.

**Tests:** `MismatchedTransactionSaveTests` (4). Control rojo: con el guardado viejo (divisa de la cuenta) caen los dos
casos de la fila desemparejada.

## Device-QA (iPhone, ~2 min, solo si tienes la fila)

Hoy ninguna ruta de la app CREA una fila desemparejada (el chat se cerró en septiembre y el cambio de divisa de cuenta
convierte), y ningún seed la siembra. Así que esto solo se puede mirar con una fila vieja: un movimiento de antes de
septiembre en una cuenta cuya divisa cambiaste, o uno que llegó por el chat antiguo. Si no tienes ninguna, el ticket se
cierra con los tests (`MismatchedTransactionSaveTests`).

1. Abre ese movimiento: el importe sale con el símbolo de SU divisa (p. ej. «$ 50» en una cuenta en soles).
2. Guardar sin tocar nada › en Registros el importe y su símbolo no cambian.
3. Ábrelo otra vez, cambia el importe › Guardar: queda con el símbolo que enseñaba la pantalla.
