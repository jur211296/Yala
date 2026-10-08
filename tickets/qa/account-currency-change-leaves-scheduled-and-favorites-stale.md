---
id: account-currency-change-leaves-scheduled-and-favorites-stale
status: qa
priority: medium
area: "accounts, currency, fx, planning"
created: 2026-09-09
updated: 2026-10-08
source: review adversarial de changing-an-account-currency-orphans-its-whole-history (2026-09-09)
---

# Tras convertir una cuenta de divisa, los pagos programados y los favoritos siguen con el importe viejo

## Qué le pasa al usuario

Cambia su cuenta de soles a dólares y acepta convertir el histórico: los movimientos pasados quedan
bien. Pero el alquiler que tenía programado por **3.500** sigue diciendo 3.500, y cuando llegue su
fecha nacerá como **3.500 dólares** en vez de los ~930 que le corresponden. Lo mismo con los
favoritos de la pantalla de nuevo movimiento. Y se repite cada mes.

## Lo medido (2026-09-09)

El importe se conserva y la divisa se toma de la **cuenta**, así que al materializarse quedan
emparejados con el número equivocado:

- `Yala/App/Services/ScheduledPaymentDraftService.swift:253-271` crea el borrador con
  `payment.amount` crudo y `account: payment.account`; al aprobarlo,
  `Yala/Services/DraftService.swift:299-303` estampa `currencyCode: account.currencyCode`.
- `Yala/App/Views/Transactions/NewTransactionView.swift:1732-1742` precarga `favorite.amount` y acto
  seguido hace `viewModel.currencyCode = account.currencyCode`.

El veredicto que decide si la divisa de una cuenta se puede cambiar
(`AccountFormViewModel.currencyChangeVerdict`) solo mira `TransactionItem`: `ScheduledPayment`,
`FavoritePayment` y los `InboxDraft` pendientes no entran ni en el bloqueo ni en la conversión.

## Por qué va aparte

`changing-an-account-currency-orphans-its-whole-history` cerró el histórico —el objeto que la
decisión del owner nombraba—. Esto son **otros tres objetos** con su propia forma: un pago
programado no tiene fecha pasada con la que convertir, así que ni siquiera está claro que
«convertir con la tasa de su fecha» sea la respuesta.

## Criterio de hecho (AC)

- [x] Decidido qué pasa con `ScheduledPayment`, `FavoritePayment` e `InboxDraft` pendientes de una
      cuenta cuya divisa cambia: convertir (¿con qué tasa?), bloquear el cambio, o avisar.
- [x] Si se convierte, con qué tasa se hace y qué pasa con los que no tienen fecha aún.
- [x] Test que fije la decisión con un pago programado sobre la cuenta convertida.

## Relacionados

- `changing-an-account-currency-orphans-its-whole-history` — el histórico, ya cerrado.

## Decisión de Jürgen (2026-10-07)

Opción 2A, la misma en los tres tickets de moneda: **antes de cambiar la moneda de una cuenta, Yala avisa y muestra qué se
va a convertir; los pagos programados y los favoritos se convierten a la tasa de hoy; el historial no se toca.**

Los tres tickets que la comparten:
- `account-currency-change-leaves-scheduled-and-favorites-stale`
- `saving-a-mismatched-transaction-relabels-it-without-converting`
- `cloudsync-account-currency-orphans-receiver-history`

A qué parte corresponde: es la respuesta directa a los dos primeros AC de este ticket. `ScheduledPayment` y
`FavoritePayment` **se convierten a la tasa de hoy** (lo que el ticket dejaba abierto: «¿con qué tasa?», y qué pasa con
los que no tienen fecha), y el aviso previo enumera qué se va a convertir.

Lo que la decisión no nombra y hay que resolver al implementar, sin cambiarla:
- Los `InboxDraft` pendientes de esa cuenta, que este ticket también lista.
- «El historial no se toca» frente a lo que ya hace `changing-an-account-currency-orphans-its-whole-history` (en `qa`):
  hoy Guardar ofrece convertir los movimientos pasados, cada uno a la tasa de **su** fecha. Lectura de esta sesión, por
  confirmar con Jürgen antes de tocar código: la decisión no cambia ese comportamiento, solo añade programados y favoritos
  al aviso. La otra lectura —dejar de convertir el histórico— deshace una decisión suya del 2026-09-09.

**Confirmado por Jürgen el 2026-10-08 (04:00 Lima):** el historial se queda como está —Guardar sigue ofreciendo convertir
cada movimiento a la tasa de su fecha—; el aviso y la conversión solo SUMAN programados y favoritos. La «lectura por
confirmar» de arriba queda confirmada.

## Lo que se hizo (2026-10-08)

**Para la persona:** al cambiar la divisa de una cuenta, el aviso de siempre enseña además qué más se convierte: hasta
tres pagos programados o favoritos con su importe antes y después («Alquiler: PEN 3,500.00 → USD 1,000.00», con «≈» si
la tasa de hoy aún no es la exacta) y «y N más»; y cuántos borradores pendientes de la Bandeja pasan con la tasa de su
fecha. Una cuenta sin movimientos pero con un alquiler programado ya no cambia de divisa en silencio: pregunta
(«¿Cambiar la divisa a USD?»). Al confirmar, todo entra en el mismo guardado que la cuenta.

**Decisiones de esta sesión** (detalle en el Paso 0 del encargo y en el PR):

- **Borradores pendientes (Jürgen, 2026-10-08, AskUserQuestion):** se convierten con el historial, a la tasa de **su**
  fecha. Los de grupo (`groupExpense`, `groupSettlement`, `groupScheduledExpense` o con puntero de grupo) no se tocan.
- **Programados:** solo los personales; los de grupo llevan el importe en la divisa del grupo. Se convierten desde su
  propia `currencyCode`, a la tasa de hoy, redondeados a los decimales ISO de la divisa nueva (JPY sin decimales).
- **Favoritos:** desde `currencyCode ?? divisa vieja de la cuenta`; los que no tienen importe solo cambian de etiqueta.
- **Sin tasa de hoy:** no se convierte nada —ni historial, ni programados, ni favoritos, ni borradores— y sale «No se
  pudo convertir». Es la misma regla todo-o-nada que Jürgen decidió para el historial el 2026-09-09.

**Código:** `AccountCurrencyPlanLogic` (qué entra y redondeo), `AccountCurrencyMigrationService.convertToday` /
`convertPlans` / `convertPendingDrafts` y `RateNeeds` en `prepareRates`, el gate y la confirmación de
`AccountFormViewModel`, el texto del aviso en `AccountFormView`. Seis textos nuevos en los 16 idiomas.

**Tests:** `AccountCurrencyPlanConversionTests` (10). Controles rojos con mutantes compilados: sin convertir
programados/favoritos, la cuenta sin movimientos que cambia sin preguntar, los borradores con la tasa de hoy y sin
redondeo — los cuatro caen.

## Lo que cazó la review adversarial (tres lentes, 2026-10-08)

Arreglado en el mismo PR, con test y mutante rojo cada uno:

1. **Un bloqueo que llega durante la espera de tasas** (una transferencia que baja por sync) se detectaba en
   `saveAccount`, DESPUÉS de reescribir en memoria programados y borradores; el siguiente guardado los persistía bajo la
   divisa vieja. Ahora el veredicto se vuelve a pedir antes de convertir nada.
2. **El saldo inicial tecleado se borraba** al preguntar en una cuenta sin movimientos (antes guardaba sin preguntar).
   Ahora solo se descarta cuando hay movimientos que reexpresar.
3. **Un borrador rechazado y devuelto a pendientes** conserva `cachedCurrencyCode`; convertido su importe, «Convertir a
   gasto de grupo» lo precargaba en la divisa vieja. Ahora pasa a la nueva.

Fuera, con ticket: `cashflow-scheduled-line-ignores-payment-currency` (el flujo de caja suma el importe del programado
sin mirar su divisa; este cambio lo hace más visible) y `save-as-favorite-from-a-mismatched-row-relabels-it`.

Residuales escritos, sin ticket (bajos, y los tres existían ya para el historial):
- Si el `save()` final lanza y la persona vuelve a la divisa vieja, lo convertido queda en memoria. Mismo hueco que el
  historial (`save-error-alert-lies-when-the-context-autosaves`).
- Importe y divisa de `scheduled_payments` / `favorite_payments` no forman grupo de coherencia en el sync: un teléfono
  sin red que edite el importe mientras otro convierte puede dejar «3.600 USD». Mismo hueco que `tx_items`.
- Los decimales salen de ICU, no de la tabla ISO: RSD, LBP e IQD redondean a entero, como los pinta iOS.

## Device-QA (iPhone, ~5 min)

El selector de Moneda del formulario de cuenta no responde a taps sintéticos (medido cinco veces en
`changing-an-account-currency-orphans-its-whole-history`), así que esto va con el dedo. Por eso no hay capturas.

Montaje: **Yala Dev** compilado desde `2.1` con este PR, con red (la conversión trae la tasa de hoy).

1. Crea una cuenta nueva «Prueba QA» en **PEN**, sin movimientos.
2. Planificación › Pagos programados › **+**: «Alquiler», 3.500, cuenta «Prueba QA», mensual, próxima fecha **hoy**.
3. Nuevo registro › estrella de favoritos › crear uno: «Mercado», 3.500, cuenta «Prueba QA».
4. Ajustes › Cuentas › «Prueba QA» › Moneda › **USD** › Guardar.
   - Esperado: sale «¿Cambiar la divisa a USD?» con «Alquiler: PEN 3,500.00 → USD ~930» y «Mercado: …», y «Esta acción no
     se puede deshacer».
5. Toca **Cancelar**: la cuenta sigue en PEN y el alquiler en 3.500.
6. Repite el paso 4 y toca **Convertir**.
   - Esperado: la cuenta queda en USD; el alquiler dice ~930 USD en Pagos programados; al abrir Nuevo registro y elegir el
     favorito «Mercado», el importe precargado es ~930, no 3.500.
7. Cierra y abre Yala: en la Bandeja aparece el borrador del alquiler por ~930 USD (venció hoy), no por 3.500.
8. Control: una cuenta con una transferencia sigue saliendo con la Moneda bloqueada, igual que antes.
