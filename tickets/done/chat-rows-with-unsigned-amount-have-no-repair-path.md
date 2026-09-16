---
id: chat-rows-with-unsigned-amount-have-no-repair-path
status: done
priority: high
area: "chat, data"
created: 2026-09-08
source: hallazgo de camino en chat-draft-drops-the-expense-sign (2026-09-08)
updated: 2026-09-16
qa-status: not-replicable
qa-date: 2026-09-16
qa-notes: No replicable (override Jurgen 2026-09-16) - el barrido one-shot ya corrio con el build 13 en el iPhone de Jurgen y el conteo solo sale en un print DEBUG. Criterio cubierto por ChatUnsignedExpenseRepairTests
---

# Las transacciones que el chat ya guardó sin signo siguen rotas, y nada las cura

## Qué le pasa al usuario

`chat-draft-drops-the-expense-sign` arregló la ruta **hacia delante**: desde el 2026-09-08 un gasto
dictado al chat se guarda firmado. Las que ya se guardaron siguen ahí con el monto positivo, y siguen
inflando el saldo, la curva y los totales — para siempre, salvo que el usuario las edite a mano una
a una.

## La ventana afectada

`saveDraft` nació el **2026-04-27** (`52d2ad6b`, «feat(chat): registrar transacciones desde Yala IA
con cards inline») y guardó sin firmar hasta el fix. Son **cuatro meses y medio** de filas, y
TestFlight build 12 está dentro. Cada gasto dictado al chat en esa ventana es una fila afectada.

## Por qué no se curan solas (medido el 2026-09-08 en este árbol)

Ninguno de los cinco mecanismos que tocan estas columnas corrige el signo:

1. **`TransactionItem.recalculatePreferredCurrency`** nunca asigna `self.amount` — es puramente
   derivador. Y como alimenta el converter con `Decimal(amount)`, **propaga** el signo malo a
   `amountInPreferredCurrency`. Pasar una fila del chat por él la deja igual de rota.
2. **El reparador de arranque** (`TransactionUpdateService`) filtra por
   `isExchangeRateProvisional == true`, y estas filas se sellaron con `false` cuando la tasa era
   exacta — el caso normal.
3. **`TransactionService`** preserva el signo existente a propósito:
   `let sign: Double = transaction.amount < 0 ? -1 : 1`.
4. **`RecordsViewModel`** (edición masiva de monto) hace lo mismo:
   `transaction.amount < 0 ? -abs(amount) : abs(amount)`.
5. **`CloudSyncReconciler`** lo dice en su propio comentario: «El SIGNO del perdedor se PRESERVA,
   nunca se corrige».

## Lo que hace difícil la migración, y es la decisión

**`TransactionItem` no tiene campo de origen.** No hay `source`, `origin` ni `createdVia`: una fila
guardada por el chat es indistinguible en el store de una escrita a mano. Lo único que las señala es
la incoherencia «categoría de gasto + monto positivo»…

…y **esa forma también la tiene un dato legítimo**. `TransactionClassificationLogic` lo documenta como
comportamiento intencionado: «un monto de signo contrario a su categoría se trata como
reembolso/corrección y REDUCE el bucket, no como magnitud absoluta». El seed de desarrollo siembra
justamente esa forma como fixture (`DevSeedTransactions`, `insert(amount: -100, sub: salary)` con el
comentario `// DESYNC: categoría income, monto NEGATIVO`).

⇒ **Un barrido que le dé la vuelta al signo de toda fila «gasto positiva» destruiría los reembolsos
que el usuario registró a propósito.** No es un caso teórico: es semántica documentada de la app.

## Qué necesita decidir Jürgen

1. **¿Se migra?** Las tres salidas, y ninguna es obviamente la buena:
   - **No migrar.** Las filas viejas quedan mal para siempre. Es lo más seguro y lo más insatisfactorio.
   - **Migrar a ciegas** (toda fila con categoría de gasto y monto positivo). Cura el corpus del chat
     y **rompe los reembolsos legítimos**, sin poder distinguirlos.
   - **Ofrecérselo al usuario**: una pantalla que liste las filas sospechosas y le deje decidir. Es la
     única que no adivina, y la que más trabajo cuesta.
2. Si se migra: **¿se acota por fecha?** La ventana `2026-04-27 → build del fix` reduce el daño
   colateral pero no lo elimina — un reembolso registrado a mano dentro de esa ventana cae igual.

## Lo que NO se midió

Cuántas filas hay realmente afectadas en el dispositivo de Jürgen o en TestFlight. Se puede acotar
antes de decidir: contar en un store real las transacciones con `category.isIncome == false` y
`amount > 0` creadas después del 2026-04-27, para saber si esto son tres filas o trescientas.

## Una trampa para quien haga la migración

**Cambiar el signo de una fila cambia su ancla de contenido.** `SyncContentAnchor.canonicalAmount` es
`String(describing: amount)`, sin `abs()`, así que dos filas idénticas salvo el signo hashean distinto.
Hoy da igual —la captura de identidad está apagada en producción— pero un barrido que corrija el signo
de filas viejas les cambiará el ancla, y con ella el rebind por ancla del backfill de sync. Quien lo
implemente tiene que mirar eso antes, no después.

## Criterio de hecho (AC)

- [x] Decisión de Jürgen registrada sobre las tres salidas de arriba.
- [x] Si se migra: barrido con la forma de `repairLegacyOneToOneRatesIfNeeded` (one-shot con flag en
      defaults), negando `amount` **y** `amountInPreferredCurrency` — `recalculatePreferredCurrency`
      no sirve, propaga el signo.
- [x] Test que demuestre que un reembolso legítimo **sobrevive** al barrido.
- [ ] Device-QA: ver el saldo antes y después del primer arranque con el build nuevo.

---

# La decisión, y lo que hizo falta medir para cumplirla

## Decisión de Jürgen (2026-09-08)

**Migrar a ciegas**, acotado por fecha: `2026-04-27` → el arreglo. Se acepta que **los reembolsos
legítimos registrados dentro de esa ventana también se volteen** — el daño está nombrado y asumido.
Negar las dos columnas, sin pasar por `recalculatePreferredCurrency`. One-shot con flag en defaults.

## Lo implementado

- `Yala/App/Logic/ChatUnsignedExpenseRepairLogic.swift` — el criterio, puro y testeable sin store.
- `Yala/Services/ChatUnsignedExpenseRepairService.swift` — el barrido y su flag
  (`chatUnsignedExpenseRepairSweep.v1`).
- `Yala/App/AppBootstrapper.swift` — la llamada, tras el gate de quiescencia
  (`awaitPersonalStoreReady`), en un `Task` propio como la migración de Live Balance.
- `YalaTests/ChatUnsignedExpenseRepairTests.swift` — 13 casos.

## Lo que la forma literal habría roto, y por eso el criterio lleva un filtro más

«Categoría de gasto + monto positivo» no señala solo a reembolsos: también es la forma de filas que
**genera el sistema**. El caso vivo, medido, es el **bridge de Grupos**: `GroupTransactionBridge`
construye sus transacciones con `category: subcat.safeCategory` explícita y monto positivo en las
ramas de cobro y liquidación, y los roles `loanCollection`, `settlementSent` y `openingBalanceDebt`
cuelgan de una categoría de sistema **de gasto**. Voltear una de ésas rompe el puente con el grupo,
que no es el daño que se aceptó.

El corte no es enumerar casos, sino mirar lo que el chat **no** escribe: `saveDraft` construye una
transacción simple y no toca ninguno de los cinco marcadores de sistema (`balanceAdjustmentType`,
`transferPairID`, `splitExpenseID`, `splitSettlementID`, `scheduledPaymentID`). Excluir las filas que
llevan uno **no pierde ni una del corpus del chat**. Es además el filtro que ya usa el resto de la
app: `StatisticsViewModel`, `BudgetsViewModel` y `FinancialReportViewModel` descartan
`balanceAdjustmentType != nil` de sus cálculos.

### Dos justificaciones mías que eran FALSAS, y la review adversarial midió

Este ticket y el docblock sostuvieron el filtro con dos ejemplos que suenan plausibles y no lo son.
Se dejan escritos porque el error es fácil de repetir:

1. **«El saldo inicial habría pasado a −500».** No: `InitialBalanceService` asigna `subcategory` y
   `balanceAdjustmentType` pero **nunca `category`**, así que esas filas llegan con `category == nil`
   y las rechaza el guard de categoría, que va **antes** que el de marcadores. Cada pieza del
   razonamiento era cierta —monto tal cual, subcategoría «Ajuste de saldo», «Otros» con
   `isIncome: false`— y la conclusión no: la categoría del padre de la subcategoría no es la
   categoría de la fila.
2. **«La pata de entrada de una transferencia cuelga de Otros».** Es la de **salida**, y es negativa
   (`outAmount = -amount` con `ensureTransferCategory`, que pide `isIncome == false`). La de entrada
   usa `ensureIncomeTransferCategory`, de ingresos. Ninguna de las dos pasa el criterio.

**Cómo se me coló:** el mutante que creí que lo demostraba montaba la fila con una categoría
explícita, que es la forma de mi test y **no la de producción**. El rojo era real; lo que probaba,
otra cosa. El filtro de marcadores se queda —salva las filas del bridge— pero con el motivo medido.

**El criterio sigue sin contradecir la decisión.** Jürgen aceptó perder reembolsos, no filas de
Grupos.

## Dos precisiones más, medidas

1. **La ventana se mide sobre `createdAt`, no sobre `date`.** `date` es la fecha que el usuario le
   pone a la transacción y el chat la resuelve como `parsed.date ?? Date.now`: se puede dictar hoy
   «un café en marzo», o registrar hoy un reembolso fechado en junio. Solo `createdAt` responde a
   «¿la escribió el código roto?». Y es fiable para todo el corpus: existe en el modelo desde el
   2026-01-30 (`c6c4dd9b`), **tres meses antes** de que naciera `saveDraft` (`52d2ad6b`), así que
   ninguna fila de la ventana lo tiene falseado por el default de una migración posterior.
2. **El cierre de la ventana es el instante en que corre el barrido, no la fecha del commit.** El
   barrido solo se ejecuta desde un build que ya firma, así que toda fila anterior a ese arranque
   pudo salir del código viejo — incluidas las que el usuario dicte con el build 12 de TestFlight
   entre el arreglo y su instalación. Un corte fijo en el 8-sep dejaría fuera precisamente esas.

## La trampa del ancla que el ticket avisaba: mirada, y no bloquea

`SyncContentAnchor.canonicalAmount` es `String(describing:)` sin `abs()`, así que el signo **sí**
viaja en el hash (`SyncContentAnchor.swift:124-127`). Pero el ancla se persiste **una sola vez**, al
materializar el testigo (`SyncApplyEngine.swift:422`), y **nada la recalcula cuando el contenido
cambia**: el único escritor posterior de `SyncIdentity.localAnchor` es `rekeyIdentity`, que escribe
un `stableID`, no contenido. Vive además en un store `cloudKitDatabase: .none`, local por
dispositivo. Su único lector es el rebind por ancla del backfill de identidad
(`SyncIdentityService.swift:237-244`), que corre solo desde la migración a Modo Nube. El residual, si
una fila anclada con el signo viejo se borrase y recreara, es que el rebind no case y se acuñe un
`syncID` nuevo — no hay colisión ni pérdida.

**De paso:** `Yala/App/Logic/StorageRowGateLogic.swift:11-12` afirma que el gateway sirve
`CLOUD_MODE_ROLLOUT_PERCENT = "0"`, y `gateway/wrangler.toml:130` sirve `"100"` desde el 2026-07-30.
Ese comentario está stale — ticket aparte.

## Idempotencia, y por qué un `save()` fallido es seguro

El criterio pide `amount > 0`, y una fila ya volteada deja de cumplirlo. El barrido no puede
deshacer su propio trabajo, así que no hace falta rollback: si el `save()` falla, el flag no se marca
y el reintento del próximo arranque no vuelve a tocar lo firmado.

## El barrido no corre bajo UI tests

El seed de UI tests siembra a propósito la forma que el barrido busca (`insert(amount: 200,
sub: restaurants)`, «DESYNC: categoría expense, monto POSITIVO») para demostrar que la app clasifica
por categoría y no por signo. El barrido va gateado por `!uiTestActive`, como sus vecinos.

**Medido, y no es lo que esperaba:** quitando el gate, `IncomeExpenseClassificationUITests` **sigue
pasando** — el barrido no llega a pisar el fixture porque antes espera `awaitPersonalStoreReady()` y
el test termina en ~15 s. Así que el gate no arregla un rojo: evita que ese verde dependa de ganar
una carrera contra un gate de hasta 120 s, cuyo fallo sería intermitente.

## Lo importado por CSV queda fuera (decisión de Jürgen, 2026-09-08)

Al medir el daño colateral apareció que el criterio alcanzaba también a lo importado por CSV, más
ancho de lo que se había aceptado. Jürgen decidió **acotar: el barrido no toca filas importadas**.

Campo a campo son indistinguibles de las del chat, pero **nacen a la vez**: el importador crea el lote
sin `save()` intermedio, mientras el chat exige un toque humano por fila. `batchFlags` agrupa por
huecos encadenados sobre **todas** las filas del store y deja fuera a las que tienen compañía.
Detalle, residuales y verificación en `csv-import-rows-fall-in-the-chat-sign-sweep`.

## Residual del criterio: las filas sin categoría se saltan

Una fila del chat cuya categoría se haya **borrado** llega con `category == nil` —la relación es
`deleteRule: .nullify`— y el criterio la descarta; SwiftData con CloudKit también puede entregar la
relación `nil` mientras su record va en vuelo. Esas filas no se curan, y como el barrido es one-shot
no se vuelven a mirar. Se elige errar hacia no tocar: sin categoría no hay señal que permita afirmar
que el signo esté mal, y admitirlas metería en el criterio a toda fila huérfana positiva del store —
el saldo inicial de una cuenta es justo una de ésas.

## Lo que sigue sin medirse

**Cuántas filas hay afectadas de verdad** en el dispositivo de Jürgen. Sigue sin poderse contar desde
aquí. El log de DEBUG del barrido imprime el número al correr, así que el device-QA lo responde.

## QA · 2026-09-16 — cerrado sin verificar: no replicable (override de Jürgen)

- **Lo que pedía el criterio ya no se puede observar:** el saldo antes y después del primer arranque con el
  build nuevo, y cuántas filas había en el iPhone de Jürgen. El barrido es de una sola vez, se quema en el
  primer arranque con alguna transacción (`ChatUnsignedExpenseRepairService.swift:111`, `:163`) y ya corrió
  con el build 13 (sus dos commits son ancestros del de ese build). El conteo solo existe en un `print`
  bajo `#if DEBUG` (`:164-166`), sin canario.
- **No hay montaje que lo fabrique:** ningún seam o seed rebobina este barrido (el gemelo del tipo de cambio
  sí lo tiene), el barrido está apagado bajo `-uitest` (`AppBootstrapper.swift:202`) y la IA del chat no
  corre en simulador.
- **Lo que queda de red:** `YalaTests/ChatUnsignedExpenseRepairTests.swift`. El caso más parecido que sí se
  puede mirar a mano es la fila suelta del guion de `csv-import-rows-fall-in-the-chat-sign-sweep`.

Medido por un lector del barrido sobre `2.1` @ `bebd57a57`.
