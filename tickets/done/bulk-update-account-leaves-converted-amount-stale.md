---
id: bulk-update-account-leaves-converted-amount-stale
status: done
priority: medium
area: "currency, fx, cloud-sync"
created: 2026-09-07
updated: 2026-09-08
source: review adversarial de fx-manual-writes-seal-approximate-as-final (2026-09-07)
---

# `TransactionService.bulkUpdateAccount` cambia la divisa y deja el monto convertido de la vieja

## Qué pasa

`Yala/Services/TransactionService.swift:113-122` **en el árbol de entonces** (hoy esas líneas caen en
la nota que quedó en su lugar) reasignaba la cuenta **y con ella `currencyCode`**, que es el input de
la conversión, y guardaba sin recalcular nada:

```swift
for transaction in transactions {
    transaction.account = account
    transaction.currencyCode = account.currencyCode   // ← cambia el input de la conversión
}
try context.save()                                    // ← sin recalcular las derivadas
```

`amountInPreferredCurrency`, `exchangeRate` y `preferredCurrencyCode` se quedan con los valores
calculados para la divisa **anterior**. **14 de los 21 calculadores** de `Yala/App/Logic/Calculators/` leen
`amountInPreferredCurrency` y suman ese número como si fuera bueno.

## Lo que lo delata: sus dos hermanos sí lo hacen bien

- `TransactionService.bulkUpdateAmount` (`:238-242` entonces, `:255-259` hoy) llama
  `recalculatePreferredCurrency` y lo
  documenta en voz alta: *«al tocar `amount` SIEMPRE recomputar las derivadas […] o el drain de sync
  emitiría un money-group incoherente (canario `cloudSyncCoherenceGroupPartial`)»*. Y **tiene test**:
  `YalaTests/TransactionServiceTests.swift:22`.
- `RecordsViewModel.bulkUpdateAccount` (`:516-519`), que es el que la UI llama de verdad, también
  recalcula.

La única de las tres que no lo hace es ésta, y es la única sin test. La asimetría es la trampa: un
refactor que unifique las dos rutas por la del «servicio» hereda el bug.

## Atenuante, dicho con claridad

**Hoy no tiene llamador.** `BulkEditSheet.swift:271` llama al de `RecordsViewModel` y
`InboxBulkActionsSheet.swift:297` al de `DraftService`. Es código muerto — por eso `medium` y no
`high`. Pero está vivo en el árbol, es la copia «de servicio» que un refactor futuro llamaría, y

**el canario no lo cazaría**: ni `currency_code` ni `account_ref` están en el grupo de coherencia
`money` (`EntityEmissionMap.swift:179` y `:186-189`, que lo forman `amount`,
`amount_in_preferred_currency`, `preferred_currency_code`, `exchange_rate` e
`is_exchange_rate_provisional`). Y el mecanismo importa, porque no es el que este ticket suponía:
como `DeltaEmitter` arma `touchedGroups` con las columnas cambiadas **que tienen grupo**, tocar solo
esas dos lo deja vacío ⇒ no se emite el grupo `money` **en absoluto** y el guard
`coherenceGroupPartial` ni llega a evaluarse. No es que emitiera algo que parece coherente: es que no
emitía nada y el PATCH viajaba con la divisa nueva junto al monto convertido viejo.

## Criterio de hecho (AC)

- [x] `bulkUpdateAccount` llama `recalculatePreferredCurrency` tras reasignar la divisa, como su
      gemelo — o se borra, si de verdad no debe existir. → **BORRADO.**
- [x] Test equivalente al de `bulkUpdateAmount`: mover transacciones a una cuenta de OTRA divisa deja
      las cuatro columnas del grupo `money` coherentes entre sí. → **contra la ruta VIVA.**
- [x] Barrer el patrón: cualquier otra ruta que escriba `currencyCode` o `amount` de una transacción
      ya persistida sin recalcular las derivadas. → **1 bug más, 3 exenciones legítimas.**

---

## Resultado (2026-09-08)

### Se borró, no se parcheó — y el motivo son dos cosas que el ticket no había visto

**El método nunca tuvo un llamador, en toda la historia del repo.** `git log -S` sobre todas las
ramas: cero commits. No es un método que perdiera su llamador; nació especulativo en el refactor C.3
(`461cc0ea`, 29-ene) para «estandarizar operaciones» y la UI jamás migró. Un mes más tarde `2eb7acc6`
arregló la integridad del bulk edit **en el ViewModel**, y esta copia se quedó atrás.

**Y divergía de la ruta viva en DOS cosas, no en la una que se reportó.** Además del recálculo
faltaba el bloqueo de transferencias que `RecordsViewModel.bulkUpdateAccount` sí hace: una
transferencia tiene dos cuentas inherentes ligadas por `transferPairID`, y colapsarlas a una sola
parte el par y descuadra los dos saldos. Añadir solo la línea del recálculo habría dejado ese segundo
daño dentro y —peor— el método con aspecto de revisado, que es justo lo que el ticket temía del
«refactor que unifique por la del servicio».

Donde estaba queda la nota con el porqué, para que la papelera no sea el único registro.

### El test va contra la ruta VIVA, que no tenía ninguno

`RecordsViewModel.bulkUpdateAccount` es lo que `BulkEditSheet` ejecuta de verdad y **no tenía ni un
test**: ni del recálculo ni del bloqueo de transferencias. `YalaTests/RecordsViewModelBulkAccountCurrencyTests`,
3 casos:

1. mover a una cuenta en divisa extranjera reconvierte el monto;
2. el **espejo** —mover a la preferida— vuelve a la identidad, que es lo que impide que pase un fix
   que deje el número clavado;
3. la transferencia —con sus **dos patas de verdad**, ligadas por el mismo `transferPairID`— se
   rechaza y no se toca ninguna de las dos.

Testigo aritmético independiente de cuál sea la divisa preferida del simulador: sembrando
preferida = 1.0 y extranjera = 100.0 sobre base USD, la conversión da `amount / 100` por **las dos**
ramas posibles de `performConversion`, así que −250,00 → −2,50 y tasa 0,01.

**Tres mutantes verificados a exit 65, y son discriminantes**: quitar el recálculo tumba los dos casos
de divisa y deja verde el de transferencias; quitar el bloqueo de transferencias tumba solo ése y deja
verdes los de divisa; y repegar en `TransactionService` el método borrado tal cual tumba solo el
source-scan. Cada caso mide lo suyo.

### La review adversarial cazó lo mío, y esto es lo que cambió

Tres lentes independientes sobre el diff. Ninguna refutó el borrado —queda demostrado: cero llamadores
en los 3293 commits de todas las refs, cero dependencias de test, cero huérfanos de compilación— pero
las tres encontraron cosas que estaban mal **en lo que yo había escrito**:

1. **El test medía una columna, no cuatro.** De las cuatro derivadas, `preferredCurrencyCode` e
   `isExchangeRateProvisional` son invariantes en este escenario (valen lo mismo antes y después, y el
   default del modelo para la primera es `"PEN"`, que es la preferida más probable del entorno), y
   `exchangeRate` se DERIVA de `amountInPreferredCurrency` dentro del propio recalculador — afirmar las
   dos era afirmar el mismo número dos veces. Con el bug puesto, tres de las cuatro seguían verdes.
   Arreglado ensuciando las cuatro con centinelas imposibles justo antes de la operación, que es lo que
   hace el test hermano de `bulkUpdateAmount` con su `-999`.
2. **Un `save()` que lanzara dejaba el test verde.** El SUT se traga el error con un `print` bajo
   `#if DEBUG` y no lo expone; todas las aserciones leían la instancia en memoria, ya mutada antes del
   guardado. Añadido `context.hasChanges == false`, que es lo que da derecho a que los mensajes hablen
   de lo que ven Panel e informes.
3. **Y la más importante: los tres casos NO protegían el borrado.** Ninguno toca `TransactionService`,
   así que con el método malo repegado seguían los tres en verde — y la nota que dejé en su sitio
   afirmaba justo lo contrario. De ahí sale la segunda suite del fichero,
   `BulkAccountCurrencyRecalcSourceScanTests`, que vigila **por método y no por fichero** (el fichero ya
   contiene un `recalculatePreferredCurrency`, en `bulkUpdateAmount`, así que un barrido por fichero
   pasaría con el método malo dentro — que era el estado del árbol hasta hoy) y trae sus propios
   controles positivo, negativo y de comentarios.

Además corrigieron ocho cifras y referencias mal escritas por mí en tickets y notas: el grupo `money`
tiene cinco columnas y no cuatro; el mecanismo del canario no es «emite un grupo que parece coherente»
sino «no emite el grupo y su guard ni se evalúa»; son 14 calculadores de 21 y no once; el barrido de
`ManualWriteRateQualityTests` cubre tres árboles y no «`Yala/` entero»; `EntityEmissionMap.swift:181`
—que el ticket original citaba como el grupo— es en realidad `note`. **Y una lección de método: donde
las lentes se contradijeron, lo medí yo.** Una afirmó que solo tres modelos declaran `amount`; el grep
dice **siete**, y mi lista original tampoco era buena. La gravedad que una lente declara no es
evidencia; el grep sí.

### El barrido del patrón (AC nº3)

Barrido completo de los tres árboles de producción (`Yala/`, `YalaWidgets/`, `YalaShare/`; estos dos
últimos ni siquiera referencian `TransactionItem`) por escrituras de `amount`, `currencyCode` y **`date`**
(el tercer input de la conversión, que el AC no nombraba) sobre un `TransactionItem` ya persistido:

- **Un bug más**: `InitialBalanceService.swift:254` mueve la fecha del saldo inicial sin recomputar.
  Ticket propio: `initial-balance-date-move-leaves-converted-amount-stale`.
- **Tres exenciones legítimas y documentadas** (no son bug): `EntityApplyMap` ×3 (el grupo `money`
  llega entero y autoritativo del wire), `CloudSyncReconciler:100` (copia el grupo coherente del
  ganador) y `ChatUnsignedExpenseRepairService:145` (solo voltea el signo).
- **`DraftService.bulkUpdateAccount` está limpio**, y conviene que conste porque parecía candidato: un
  `InboxDraft` pendiente **deriva** la divisa de su cuenta (`displayCurrencyCode`) y no persiste
  columnas convertidas, así que la divisa sigue a la cuenta por construcción.
- El caso de cambiar la divisa de una **cuenta** entera ya tiene su ticket
  (`changing-an-account-currency-orphans-its-whole-history`) y no se duplicó.

### Dos hallazgos que salieron de camino

- `converted-amount-sweep-blind-to-input-changes` (**medium**): el barrido automatizado que ya existe
  (`ManualWriteRateQualityTests`) vigila a quien **escribe** la derivada, no a quien **cambia el
  input**. Este bug le pasó por delante sin activarlo, porque no escribía nada — no escribir era el
  bug. Y el canario tampoco, porque `currency_code` no está en el grupo `money` (medido).
- `transaction-service-bulk-block-is-dead-code` (**low**): no era un método huérfano. Son **seis**, y
  el bloque bulk entero del servicio es una copia paralela muerta de la del ViewModel.

### Por qué va a `done` y no a `qa`

No hay nada que mirar en pantalla: se borró código sin llamador y se añadieron tests. **La ruta que el
usuario ejecuta no cambió ni una línea** — solo pasó a estar cubierta.
