---
id: changing-an-account-currency-orphans-its-whole-history
status: qa
priority: high
area: "accounts, currency, fx"
created: 2026-09-08
updated: 2026-09-16
source: barrido de chat-draft-stamps-its-own-currency-not-the-account (2026-09-08)
---

# Cambiar la divisa de una cuenta deja todo su histórico en la divisa vieja

## Qué le pasa al usuario

Tiene una cuenta en soles con dos años de movimientos. Entra a editarla, cambia la divisa a dólares
y guarda. **Las transacciones no se tocan**: siguen estampadas en PEN dentro de una cuenta que ahora
dice USD. A partir de ahí la app da dos respuestas distintas sobre el mismo dinero, y solo una se
mueve con el tipo de cambio.

Nada avisa, nada convierte y no hay vuelta atrás automática.

## Lo medido (2026-09-08)

`Yala/App/ViewModels/Accounts/AccountFormViewModel.swift:372-386`:

```swift
private func applyBaseAccountProperties(to account: Account, trimmedAccountNumber: String) {
    account.name = trimmedName
    account.currencyCode = normalizeCurrencyCode(selectedCurrency.rawValue)   // :374
```

Se usa **también en la ruta de update**, y el selector de divisa es un `NavigationLink` liso, **sin
gate por `isEditing`** (`Yala/App/Views/Accounts/AccountFormView.swift:248-274` — compárese con
`:140` y `:531`, donde otras secciones sí se gatean). No hay ninguna referencia a reestampado,
conversión ni recálculo en ese ViewModel.

Esto lo convierte en **la ruta más productiva de desemparejamientos de la app**: las de creación
producen como mucho una fila; ésta produce el histórico entero de una cuenta de una vez.

## Por qué duele: el sistema asume dos cosas incompatibles a la vez

No es que el resto del código dé por hecho que coinciden. Es que **la mitad se fía de la transacción
y la otra mitad de la cuenta**, y nadie reconcilia:

- **Suman en crudo y rotulan con la divisa de la CUENTA** — `Yala/Utils/AccountBalanceCalculator.swift:81-83`
  (`signedAmount` devuelve `Decimal(item.amount)`, sin leer `currencyCode`). De ahí comen las
  tarjetas del carrusel del Panel (`AccountCardView:88-92`, `:155`), la lista de cuentas de Ajustes
  (`AccountsSettingsListViewModel:145-158`) y los widgets (`WidgetDataCache:422-434`).
- **Leen `tx.currencyCode` y convierten** — `LiveBalanceCalculator:125`,`:130-140` (con la tasa de
  **hoy**), presupuestos (`BudgetsViewModel:645-654`, también tasa de hoy), FX P&L
  (`FXPnLLogic:147-157`), cash flow, top categorías, insights, informes, el pivot «por divisa»
  (`PivotTableCalculator:228-230`), los filtros (`FilterService:279`) y la fila y el detalle
  (`RecordRowView:126`,`:243`).

⇒ La tarjeta de la cuenta y el saldo vivo del Panel enseñan cifras distintas del mismo dinero.

**Y el round-trip de exportación queda roto**: la exportación escribe `transaction.currencyCode`
(`TransactionsExportService:435-437`, `:571-572`) y la importación **rechaza** toda fila cuya divisa
no sea la de la cuenta destino (`TransactionCSVImportService:450-457`, `:689-695`, `:1313-1320`,
`:1619-1625`, `ImportError.currencyMismatchWithAccount`). Yala exporta un fichero que Yala se niega
a importar.

## Lo que NO se midió

- Si el `NavigationLink` de la divisa se puede abrir **de verdad** en modo edición desde la UI (se
  midió que no hay gate en el código; no se ejecutó en simulador).
- **INFERIDO, no medido**: `Yala/Services/CloudSync/EntityApplyMap.swift:158` escribe `currency_code`
  del cable sin contrastarlo con el `account_ref` que resuelve unas líneas más abajo. Si es así,
  propagaría el desemparejamiento al resto de dispositivos, y podría crearlo en el receptor cuando la
  divisa de la cuenta se edita en un device y las transacciones llegan del otro. Hay que medirlo
  antes de decidir nada aquí.

## Criterio de hecho (AC)

- [x] **Decidido (Jürgen, 2026-09-09): prohibir, y ofrecer convertir cuando se puede.** Con
      movimientos, Guardar ya no cambia la divisa en silencio: pide confirmación («¿Convertir N
      movimientos?») y, al aceptar, reexpresa cada importe con la tasa de **su** fecha. Si el
      histórico contiene filas que manda otra entidad, el selector ni se abre y dice por qué.
- [x] Las columnas del grupo `money` quedan coherentes: `convertHistory` escribe `amount` y
      `currencyCode` y **después** llama a `recalculatePreferredCurrency`, que es el mismo criterio
      que `RecordsViewModel.bulkUpdateAccount`. *(Corrección de la premisa: el grupo `money` de
      `tx_items` tiene **cinco** columnas, no cuatro, y `currency_code` **no es una de ellas** —
      `EntityEmissionMap.swift:179-189`, medido el 2026-09-09.)*
- [x] Tests que fijan la decisión sobre una cuenta con histórico: `AccountCurrencyChangeLogicTests`
      (13), `AccountCurrencyMigrationServiceTests` (9), `AccountFormCurrencyGateTests` (9). Cuatro
      mutantes compilados verificados.
- [x] Medida la rama de CloudSync. **Lo inferido apuntaba al applier equivocado**: `EntityApplyMap`
      `:158` es el de `tx_items`, y ahí la divisa del cable viene coherente desde el emisor. La rama
      que propaga el daño es la de **`accounts`** (`"currency_code": Apply.stringReq(\.currencyCode)`
      en el bloque `table: "accounts"`): escribe la divisa nueva en el receptor sin tocar sus
      transacciones, que es el mismo bug replicado por sync. No hace falta que las transacciones
      «lleguen del otro device». Ticket propio: `cloudsync-account-currency-orphans-receiver-history`.

## Lo que se decidió y por qué (2026-09-09)

**Por qué no «avisar y seguir»** (la tercera opción del AC): deja vivo exactamente el
desemparejamiento que este ticket describe —la tarjeta de la cuenta y el saldo del Panel siguen
dando cifras distintas del mismo dinero— y encima mantiene roto el round-trip de exportación.

**Por qué hay filas que bloquean el cambio entero en vez de quedarse sin convertir.** Medido en el
árbol el 2026-09-09, y en las tres una conversión **no se sostiene**:

- **Pata de transferencia.** Las dos patas codifican juntas la tasa de la operación.
  `RecordsViewModel.bulkUpdateAmount:722-728` ya bloquea por esto («cambiar el amount destruiría el
  exchange rate») y `:565` bloquea transferencias en el cambio masivo de cuenta.
- **Gasto de grupo (`splitExpenseID`).** `GroupTransactionBridge:393` **pisa el `amount`** en cada
  re-bridge. Y es peor que inútil: el guard de esa rama es
  `realTx.currencyCode == expense.currencyCode` (`:391`); en cuanto dejan de casar, el bridge
  **borra la transacción** y deja un draft en el Inbox (`:410-422`).
- **Liquidación (`splitSettlementID`).** `bridgeSettlement:1069-1083` hace delete+recreate
  incondicional tomando `amount` y `currencyCode` del settlement.

Convertir unas filas y dejar otras reproduciría el bug original en pequeño, así que basta una fila
bloqueada para bloquear el conjunto.

**Es el primer sitio del repo que reescribe el `amount` crudo de filas ya persistidas** — medido:
`CurrencyChangeService` (cambio de divisa PREFERIDA) barre el corpus entero pero solo toca las
derivadas, que tienen reparador. Por eso: confirmación explícita, tasas refrescadas **antes** de
convertir, y la pantalla tapada mientras dura.

## Lo que cazó la review adversarial (tres lentes, 2026-09-09)

Ninguno de estos estaba en el ticket; todos salieron revisando el arreglo, y **cinco eran del
arreglo, no del bug**. Se arreglaron en el mismo PR:

1. **El botón «Convertir» podía no convertir nada — o algo peor.** Dos lentes independientes, mismo
   mecanismo: en iOS un alert no tiene gesto de descarte, así que SwiftUI escribe `false` en su
   `isPresented` al pulsar **cualquier** botón, Convertir incluido. El setter cancelaba y el cuerpo
   `async` se encontraba el estado ya limpio. En el peor orden —la escritura cayendo durante el
   `await` de las tasas— la cuenta se guardaba en la divisa **vieja** con el histórico ya convertido:
   el bug de este ticket, creado por su arreglo. Ahora el dato viaja por parámetro y la divisa
   destino se reafirma antes de guardar. Fijado por dos tests.
2. **El ajuste de saldo se aplicaba con el número de la divisa vieja.** Basta tocar el selector de
   modo: `adjustmentModeChanged` prellena el campo con el saldo inicial en soles, y tras convertir
   `needsAdjustment` lo compara contra un `currentBalance` que ya está en dólares → un ajuste de +733
   que el usuario nunca vio, o un saldo inicial multiplicado por el tipo de cambio. La sección de
   saldo va deshabilitada mientras hay cambio de divisa pendiente, y el gate limpia el campo.
3. **El gate fallaba ABIERTO.** Si el `fetch` de transacciones lanzaba, `allTransactions` quedaba
   vacío y eso se lee igual que «cuenta sin movimientos» → veredicto `.free` → la divisa cambiaba sin
   convertir nada. Ahora el fallo se registra y bloquea.
4. **Se convertía sobre un snapshot congelado.** `allTransactions` se carga al abrir el formulario y
   el refresco de tasas hace red: en esa ventana el sync puede escribir una fila nueva de esa cuenta,
   que se quedaba sin convertir **y el re-gate no la veía**, porque releía el mismo array. Ahora se
   refetchea después del `await`, como ya hacía `CurrencyChangeService`.
5. **Un importe convertido con la tabla estática se sellaba como definitivo.** El `Bool` de
   `fetchRates` se descartaba, y cuando la divisa destino es la preferida `recalculatePreferredCurrency`
   marca la fila como exacta (esa pata es la identidad) → fuera de la cola del reparador **y** fuera
   del barrido de envenenadas. Un 33 % de error sellado para siempre en una columna que no tiene
   reparador. Ahora se verifica la cobertura **después** del fetch y, si falta, **no se convierte**
   nada y se dice.
6. **El divisor local no viajaba con el importe.** Un split personal (`splitTotalAmount`) no lleva
   `splitExpenseID`, así que no lo bloquea nadie y se convertía el `amount` dejando el total del
   divisor en la divisa vieja. Ahora se reexpresa — y `splitDivisor` no, porque son personas.

Dos correcciones menores del mismo barrido: la fila de divisa bloqueada enseña la divisa de la
**cuenta** (no la que el usuario acababa de tocar), y «Saldo actual» se rotula con la divisa de la
cuenta hasta que se convierte, que es lo que evitaba enseñar «$ 900,00» sobre novecientos soles.

**Deja cinco tickets** (`account-currency-change-leaves-scheduled-and-favorites-stale`,
`account-currency-conversion-overlay-has-no-ceiling`,
`save-error-alert-lies-when-the-context-autosaves`,
`cloudsync-account-currency-orphans-receiver-history`,
`bridge-virtual-only-currency-mismatch-is-silent`).

**Y un aviso que ninguna pantalla da:** un CSV exportado **antes** de la conversión deja de poder
importarse a esa cuenta —la importación rechaza toda fila cuya divisa no case y aborta el fichero
entero—, así que los backups previos del usuario quedan inservibles para ella. Medido, no arreglado.

## Qué mirar en device-QA

Sí es simulable. El seam es **`-uitest-seed-foreign-account <ISO>`** (medido en
`Yala/Seed/DevSeedForeignCurrencyAccount.swift`; el nombre del fichero y el del argumento NO
coinciden). Cualquier cuenta con movimientos vale igual: el seed `minimal` ya trae PEN y USD.

**Aviso del propio fixture, y aquí es la trampa central del guion:** el selector de Moneda del
formulario de cuenta es un `NavigationLink` y **no responde a los taps sintéticos** de la
automatización — medido el 2026-09-08 con cuatro técnicas, y el control cruzado descarta que sea un
bug de la app. ⇒ los pasos 1 y 2 se recorren **a mano**, no con XCUITest. El paso 3 sí es
observable sin tocar el selector: la fila sale en gris y sin chevron.

1. Cuenta con movimientos **corrientes**: Ajustes › Cuentas › tocar la cuenta › Divisa › elegir otra
   › Guardar. Sale «¿Convertir N movimientos?» con el conteo real. Aceptar: overlay de progreso,
   cierra, y los importes de esa cuenta salen reexpresados (no el mismo número con otro símbolo).
2. **Cancelar** en ese diálogo: el selector vuelve a la divisa vieja y nada cambia.
3. Cuenta con una **transferencia** o un **gasto de grupo**: la fila «Divisa» sale en gris, sin
   chevron y sin navegar, con el motivo debajo.
4. Cuenta **sin movimientos**: la divisa se cambia como siempre, sin preguntar.

## Relacionados

- `bulk-update-account-leaves-converted-amount-stale` — el caso complementario (mover transacciones
  a una cuenta de otra divisa). Su AC nº3 pide barrer «cualquier otra ruta que escriba `currencyCode`
  o `amount` de una transacción ya persistida»; **ésta no cae ahí**, porque aquí nadie escribe la
  transacción: es la cuenta la que cambia debajo.
- `chat-draft-stamps-its-own-currency-not-the-account` — el hueco de creación, ya cerrado.
- `saving-a-mismatched-transaction-relabels-it-without-converting` — qué pasa al abrir en el
  formulario una fila ya desemparejada.

## QA Visual · 2026-09-16 — parcial (sigue en qa: a mano en simulador)

Simulador iPhone 17 Pro (iOS 26.5), sobre `2.1` @ `bebd57a57`, `Yala Dev`, seed `realista` + `-uitest-seed-foreign-account JPY` + `-uitest-pro`.

**Paso 3 — PASS.** «Cuenta Principal», que tiene transferencias: la fila Moneda sale como texto
(`account_currency_locked`), sin navegar, con el motivo «…transferencias entre cuentas…» debajo.
Control: «QA FX», sin transferencias, ofrece el enlace tocable (`account_currency_link`).

Captura: [divisa bloqueada](../../qa/evidencia-barrido-20260916/32-divisa-bloqueada-cuenta-con-transferencias.jpg).

**Pasos 1, 2 y 4 — a mano.** El selector de Moneda es un `NavigationLink` y hoy tampoco respondió al tap
sintético ni a touch down/up (quinta técnica medida). Montaje para quien lo haga con el dedo, ~5 min: el
mismo lanzamiento, y en «QA FX» (movimientos corrientes) los pasos 1 y 2 del guion de arriba; para el
paso 4, una cuenta nueva sin movimientos.
