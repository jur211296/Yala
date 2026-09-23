---
id: chat-draft-drops-the-expense-sign
status: qa
priority: high
area: "chat, accounts"
created: 2026-09-08
source: hallazgo de camino en chat-assistant-plants-exchange-rate-one (review adversarial, 2026-09-08)
updated: 2026-09-23
---

# Un gasto guardado desde el chat SUMA al saldo de la cuenta

## Qué le pasa al usuario

Dicta «gasté 30 soles en el almuerzo», el chat propone el borrador, pulsa Guardar — y **el saldo de la
cuenta sube 30 soles en vez de bajar**.

## Lo medido (2026-09-08, en este árbol)

`ChatAssistantViewModel.saveDraft` persiste el monto **sin firmar**:

```swift
guard dbl.isFinite, dbl > 0, dbl < 1_000_000 else { … }   // solo acepta positivos
…
let transaction = TransactionItem(
    date: draft.date,
    amount: amountDouble,        // ← positivo siempre
```

`draft.isExpense` existe y el ViewModel lo usa en otros dos sitios —lo propaga al abrir el formulario
(`prefill`) y filtra subcategorías con él (`sub.safeCategory.isIncome == !draft.isExpense`)— pero
**no lo usa para firmar el monto que guarda**. `TransactionService.create` tampoco lo toca: hace
`insert` + `save` y nada más.

Todas las demás rutas de escritura SÍ firman:

- `NewTransactionViewModel`: `let finalAmount = transactionType.isNegative ? -amount : amount`
- `TransactionFormModels`: «Indica si el monto debe ser negativo internamente», `.expense → true`
- `DraftService` recibe el monto ya firmado; `InboxView` deduce `isExpense: amount < 0`

Y el saldo se calcula sumando el monto **en crudo**, sin mirar la categoría:

```swift
// LiveBalanceCalculator
nativeBalances[tx.currencyCode, default: 0] += Decimal(tx.amount)
```

## Por qué no salta a la vista

Las pantallas que clasifican ingreso/gasto por **categoría** (`TransactionClassificationLogic`, que
solo cae al signo cuando `category == nil`) muestran la transacción bien: en Registros y Estadísticas
aparece como gasto porque su subcategoría lo es. **El saldo es el que no pregunta por la categoría.**
De ahí que el síntoma sea «los números de las listas cuadran y el saldo no».

## Lo que NO se midió

No se reprodujo en ejecución el saldo resultante — la evidencia es de código: las cuatro piezas de
arriba, leídas en este árbol. Antes de arreglar, conviene un test que ate el saldo, no solo el signo.

## Relación con `chat-assistant-plants-exchange-rate-one`

Ninguna causal, pero sí una consecuencia incómoda que conviene tener presente: ese ticket hizo que
estas filas guarden una tasa correcta y coherente. **Antes, el `1.0` plantado era una señal visible de
que la fila no era de fiar; ahora la fila luce impecable sobre un monto de signo equivocado.** El
arreglo de la tasa no causa este bug, pero le quita el único síntoma que lo delataba de lado.

## Corrección a la premisa de arriba

**La sección «Por qué no salta a la vista» es parcialmente falsa, y conviene no heredarla.** Es cierto
que la fila se *pinta* bien en Registros y Estadísticas —el tipo se decide por categoría—, pero de ahí
no se sigue que «los números de las listas cuadren»: los TOTALES de esas mismas pantallas eligen el
bucket por categoría y luego **acumulan con signo** (`expense -= amount` en `RecordsViewModel`,
`.reduce { $0 - … }` en `StatisticsViewModel`). Un gasto de 30 guardado en positivo **restaba** 30 del
total de gastos, así que el KPI se desviaba 60 respecto del valor real.

Lo escribí igual en el comentario del código y en el test antes de medirlo; lo cazó la review
adversarial y está corregido en los tres sitios. La frase importaba porque invitaba a concluir «solo
el saldo lee el signo» — que es justo la creencia que produjo el bug.

## Lo que resultó ser, al medirlo (2026-09-08, en este árbol)

Las cuatro piezas del diagnóstico de arriba se confirmaron una a una. Lo que cambió es el **tamaño**:
el saldo no era el daño, era el síntoma más visible de ocho.

**El monto en divisa preferida también salía sin firmar**, y ése es el que consumen los totales. El
ticket original solo señalaba `amount`. Con las dos columnas positivas, un gasto dictado al chat
entra en todo el sistema como un **reembolso** — que es literalmente el contrato escrito en
`TransactionClassificationLogic`: «un monto de signo contrario a su categoría se trata como
reembolso/corrección y REDUCE el bucket». Rompía, además del saldo:

- las **curvas de saldo** de Panel y Estadísticas (`runningBalance += amountInPreferredCurrency`, en
  cuatro sitios, sin mirar categoría) — un gasto hacía SUBIR la curva;
- los **totales de ingreso/gasto** de Estadísticas y Registros: el bucket lo elige la categoría, así
  que el gasto caía bien pero **restaba** de «Gastos del mes»;
- **Informes** (pivot), **Top categorías/subcategorías**, **Insights**, los **widgets** y las
  **notificaciones de informe**;
- el **heatmap de gasto diario**, que además **borraba el día entero**: con el día en negativo, el
  guard `if dayExpense > 0` lo descarta.

**El bug era asimétrico, y eso explica que sobreviviera cuatro meses.** El mismo borrador guardado con
«Guardar» salía positivo y guardado con «Editar → Guardar» salía negativo: `editDraft` propaga
`isExpense` a `NewTransactionViewModel`, que sí firma. Quien lo probara editando no veía nada.

**Barrido de las otras rutas del chat:** `saveDraft` es la única que construye un `TransactionItem`
en todo el dominio del chat. No hay batch ni «guardar todo» —`ChatAttachmentsView` llama a `saveDraft`
una vez por card— y el retry es la reentrada al mismo método, así que heredaba el bug y queda cubierto
por el mismo arreglo. Las demás (`markDraftSaved`, `updateDraft`, `discardDraft`) no tocan SwiftData.

## El arreglo

El signo sale de `draft.isExpense` y se aplica a **las dos** columnas de monto. Se convierte la
magnitud y se firma después, en vez de firmar antes de convertir: así el número que devuelve el
converter se preserva exactamente, y `exchangeRate` —que se deriva del cociente de ambas— sigue
saliendo positiva. Firmar una sola de las dos habría dejado la tasa negativa y el grupo de coherencia
`money` roto.

## Lo que este ticket NO arregla, y tiene ticket propio

- Las filas **ya guardadas** siguen rotas y nada las cura: ni el reparador de arranque, ni
  `recalculatePreferredCurrency` (que conserva `amount` y propaga el signo), ni el reconciliador de
  sync (que preserva el signo a propósito). Y no se pueden distinguir de un reembolso legítimo porque
  `TransactionItem` no tiene campo de origen. → `chat-rows-with-unsigned-amount-have-no-repair-path`
  (**high**, necesita decisión de Jürgen).
- El chat es la única superficie de captura que **ignora el modo «solo gastos»**. Antes daba igual
  —todo se guardaba positivo—; al firmar, la diferencia pasa a ser real. →
  `chat-ignores-expenses-only-mode`.
- En la ruta de **foto de recibo**, el signo depende de un ejemplo del prompt y no de una regla, sin
  red debajo. Se midió y **no está roto hoy** — se deja escrito para que nadie lo «arregle» al revés.
  → `vision-amount-sign-contract-is-only-a-prompt-example`.

## Criterio de hecho (AC)

- [x] Un gasto guardado desde el chat resta del saldo de la cuenta.
- [x] El signo sale de `draft.isExpense`, como en las otras rutas — no de una heurística nueva.
- [x] Test de comportamiento sobre el SALDO (no solo sobre el signo del campo), con control positivo
      por mutación.
- [x] Comprobar qué pasa con las filas ya guardadas: hay corpus afectado (ventana de cuatro meses y
      medio, desde `52d2ad6b` el 2026-04-27) y **la migración necesita decisión** — sale del alcance
      de este ticket con el suyo propio.

## Barrido de `qa` · 2026-09-23 · se queda para el iPhone

Está en la lista corta de device-QA del 2026-09-23 (`qa/guion-tanda.md`). Se prueba con **Yala Dev compilado desde `2.1`**: el TestFlight 13 es del 9-sep y no lleva los arreglos posteriores. Para cerrarlo basta con el bloque A del guion (dictar un gasto y ver bajar el saldo).
