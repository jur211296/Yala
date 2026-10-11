---
id: chat-draft-stamps-its-own-currency-not-the-account
status: qa
priority: medium
area: "chat, currency"
created: 2026-09-08
updated: 2026-09-23
source: review adversarial de chat-draft-drops-the-expense-sign (2026-09-08)
---

# Una transacción del chat puede quedar en una divisa distinta a la de su cuenta

## Qué le pasa al usuario

Dicta «50 dólares», no tiene ninguna cuenta en dólares, elige su cuenta en soles y guarda. La
transacción queda **en USD dentro de una cuenta PEN**. El saldo agrupa por la divisa de la
transacción y convierte con la tasa de HOY, así que esa cuenta enseña un saldo que no cuadra con lo
que el usuario cree tener, y que además **cambia solo** al moverse el tipo de cambio.

## Lo medido (2026-09-08, en este árbol)

El chat estampa la divisa que dictó el usuario; el formulario de siempre estampa la de la cuenta:

| Ruta | Qué persiste |
|---|---|
| `ChatAssistantViewModel.saveDraft` | `currencyCode: draft.currencyCode` |
| `NewTransactionViewModel` | `currencyCode: account.currencyCode` |

Y el borrador no tiene forma de corregirlo: `updateDraft` acepta `amount`, `accountID`,
`subcategoryID`, `note`, `date` y `tagIDs` — **no `currencyCode`**. Así que el usuario puede cambiar
la cuenta pero no la divisa, y la pareja queda desemparejada sin que nada avise.

Aguas abajo, `LiveBalanceCalculator` agrupa por `tx.currencyCode` y convierte cada grupo con la tasa
actual, no con la del día de la transacción: el descuadre no es fijo, se mueve.

La ruta «Editar → Guardar» **no** tiene este defecto, porque pasa por el formulario.

## Lo que el ticket dejaba sin medir, ya medido (2026-09-08)

El ticket pedía saber, antes de arreglar, si esto ocurre alguna vez fuera del laboratorio. **Ocurre,
y es el camino natural, no el raro.**

`DraftBuilder.build` (`:221-222`) elige cuenta con `findAccount(byCurrency:)`, que es **match exacto
o nil**: no hay fallback. Cuando el usuario dicta en una divisa en la que no tiene cuenta, el
borrador nace con `accountID == nil`, `computeNeedsUserInput` marca «account», la tarjeta le pide
que elija y el menú le ofrece **todas** las cuentas sin filtrar por divisa
(`ChatTransactionDraftCard:161`, `ForEach(allAccounts)`). Es decir: el desemparejamiento era la
salida forzosa del **único camino en que ese match falla**, que es justo aquel en que las divisas
diferen. Y el parseo lo alimenta a propósito — el prompt del LLM pide `currencyHint` explícitamente
(`TranscriptionParserService:194`: `"USD" | "EUR" | "PEN" | null`).

Hay un segundo camino, igual de real: aunque el borrador nazca emparejado, `updateDraft` acepta
`accountID` y el menú no filtra, así que cambiar de cuenta rompía la pareja.

## Qué se decidió, y por qué no es una regla nueva

**Manda la divisa de la CUENTA elegida.** Mientras no hay cuenta, se sigue enseñando la dictada, que
es lo único que hay.

No es una invención de este ticket: **es la regla que el formulario ya aplicaba a este mismo
borrador**. `NewTransactionViewModel.prefill(fromChatDraft:)` (`:378-386`) hace
`currencyCode = account.currencyCode` cuando el ID resuelve, y cae en `draft.currencyCode` solo si
no. La incoherencia estaba **dentro de la propia tarjeta**: pulsar «Editar» aplicaba esta regla y
pulsar «Guardar» la contraria.

Y el resto del sistema ya la asumía. Barrido del universo cerrado — los 9 ficheros que construyen
`TransactionItem(` en `Yala/`: las otras ocho rutas estampan `account.currencyCode`, `InboxDraft`
(el borrador de Voz/Siri/Vision) **ni siquiera tiene campo de divisa** —usa el hint para elegir
cuenta y lo descarta—, y la importación CSV, el bridge de Grupos, el formulario de gasto de grupo,
el editor de pago planificado y el de liquidación tienen **guarda explícita** contra esta
combinación. El chat era el único hueco de creación.

Se descartó **convertir** el importe (dictar «50 dólares» y que se guarden 187 soles cambia el
número que el usuario está confirmando; tiene ticket propio).

## Dónde vive la divisa, y por qué eso es el arreglo

La divisa efectiva **vive en el borrador**: el ViewModel la sincroniza con la de la cuenta al
elegirla (`updateDraft`) y congela la realmente estampada al guardar (`saveDraft`). Nadie más la
deduce.

Eso es el segundo intento, y el primero enseña por qué. La primera versión derivaba la divisa **en
la tarjeta**, resolviendo `draft.accountID` contra su `@Query` — y la review adversarial la refutó:
ese `@Query` filtra `!isArchived` y `saveDraft` resuelve con `context.model(for:)`, que **no**
filtra. Con la cuenta archivada entre proponer y guardar —alcanzable de verdad: la sesión del chat
vive el día entero y la bajada de plan archiva cuentas en lote— la tarjeta enseñaba la divisa
dictada y el guardado estampaba la de la cuenta. **El mismo bug, movido al borde**, con un comentario
al lado que lo declaraba imposible.

La lección, que es la que vale para el yo-futuro: **dos criterios para la misma pregunta son dos
respuestas esperando a divergir**. Con un solo valor en el borrador no hay nada que sincronizar, y la
tarjeta vuelve a ser un `Text(draft.currencyCode)` sin lógica.

## Cómo se cerró el AC nº2 sin un aviso

La combinación deja de ser **representable**, que es más fuerte que avisar de ella: elegir otra
cuenta cambia la etiqueta del monto **a la vista**, antes de guardar.

## Criterio de hecho (AC)

- [x] Decidido qué manda: **la divisa de la cuenta elegida**.
- [x] La combinación imposible no se puede guardar en silencio — la divisa vive en el borrador,
      sigue a la cuenta y el cambio es visible en la tarjeta antes de guardar.
- [x] Test que fije la decisión: `YalaTests/ChatDraftAccountCurrencyTests` (6 casos).

## Verificación

- 6 casos nuevos; suite completa **6493/6493** en local, `EdgeCasesUITests` 2/2, ambas schemes sin
  warnings nuevos.
- **7 mutantes compilados, todos rojos:**
  1. estampar `draft.currencyCode` → caen 3;
  2. **el medio-arreglo** —estampar la de la cuenta y convertir desde la dictada— → caen 3, por las
     aserciones de coherencia (`exchangeRate` 0,0248 ≠ 1,0). Es el fallo más probable de un arreglo
     apresurado, y una aserción que solo mirase `tx.currencyCode` lo habría dado por bueno;
  3. devolver siempre la **preferida** → lo caza **solo** el caso espejo, que existe por eso;
  4. devolver siempre la dictada → caen 3;
  5. sin la sincronización de `updateDraft` → caen los dos casos del borde;
  6. sin el congelado de `saveDraft` → cae «lo que se enseña tras guardar es lo que se guardó»;
  7. sin la siembra de tasas → cae `isExchangeRateProvisional`.
- El escenario ancla un lado en la divisa preferida a propósito: así la conversión correcta es la
  identidad (tasa 1,0) y la incorrecta no, que es lo único que separa numéricamente el arreglo
  completo del medio-arreglo.
- **El mutante 5 destapó un hueco en el propio test**: el caso de la cuenta archivada medía solo
  DESPUÉS de guardar, cuando el congelado ya había alineado los dos lados, así que pasaba en verde
  con la divergencia puesta. La aserción se movió al instante crítico —lo que el usuario ve **antes**
  de pulsar Guardar—, y ahí sí cae.

## Pendiente

- **Device-QA** (sí simulable): dictar en el chat un importe en una divisa en la que no se tenga
  cuenta, elegir una cuenta local y comprobar que la etiqueta del monto cambia a la divisa de la
  cuenta antes de guardar, y que el saldo de esa cuenta cuadra después.

## De camino, con ticket propio

- `changing-an-account-currency-orphans-its-whole-history` (**high**) — el hueco que queda sin dueño
  no es el chat: editar la divisa de una cuenta existente desempareja su histórico **entero**, en
  masa y en silencio.
- `saving-a-mismatched-transaction-relabels-it-without-converting` (medium) — abrir una transacción
  ya desemparejada en el formulario y pulsar Guardar la reetiqueta sin re-expresar el importe.

## Medido de camino, sin ticket

- `findAccount(byCurrency:)` no es «exacto o nil»: es **exacto y ÚNICO** (`0 ó 2+ → nil`). Con dos
  cuentas en la divisa dictada el match también falla, y ahí las divisas ni siquiera difieren. La
  primera versión de este ticket y de los comentarios decía lo otro.
- La tarjeta del chat **no tiene un solo `accessibilityIdentifier`**, así que ningún XCUITest puede
  afirmar sobre ella. La red de esta ruta es unit, y conviene saberlo antes de confiar en el gate.

## Barrido de `qa` · 2026-09-23 · se queda para el iPhone

Está en la lista corta de device-QA del 2026-09-23 (`qa/guion-tanda.md`). Se prueba con **Yala Dev compilado desde `2.1`**: el TestFlight 13 es del 9-sep y no lleva los arreglos posteriores. Para cerrarlo basta con el bloque A del guion (dictar en dólares sobre una cuenta en soles).
