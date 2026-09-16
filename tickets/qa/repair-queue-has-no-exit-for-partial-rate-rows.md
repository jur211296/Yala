---
id: repair-queue-has-no-exit-for-partial-rate-rows
status: qa
priority: high
area: "currency, fx, cloud-sync, arranque"
created: 2026-09-07
updated: 2026-09-16
source: review adversarial de fx-manual-writes-seal-approximate-as-final (2026-09-07)
---

# La cola del reparador no tiene salida para el caso que más la llena

## Qué pasa

`TransactionUpdateService.updateProvisionalTransactions` corre **en cada arranque**, busca todas las
transacciones con `isExchangeRateProvisional == true` y llama a `ensureRates` para el rango de sus
fechas. Pero `ensureRates` decide qué falta con `findMissingDates` → `rateExists`
(`ExchangeRateService.swift:450-452, 477-493`), que **solo pregunta si la FILA de ese día existe**, no
si trae la divisa que hace falta.

Y el escenario que marca la mayoría de esas transacciones es exactamente **la fila parcial**: existe la
fila del día, pero le falta la divisa. Así que `ensureRates` responde «no falta nada», vuelve en el
acto, la conversión vuelve a degradar, la transacción se re-marca provisional, y **la cola se recorre
entera otra vez en el siguiente arranque. Para siempre.**

No hay `fetchLimit`, ni contador de intentos, ni backoff, ni sentinel por fecha ya intentada. Y como el
log de DEBUG está dentro de `if updatedCount > 0`, **una cola atascada no imprime nada**: es invisible.

`rateHasAllCurrencies` —que sí pregunta por cobertura de divisa— existe en el mismo fichero
(`ExchangeRateService.swift:456-463`) y solo la llama un sitio (`:187`).

## La asimetría que delata que esto ya se sabía

`repairLegacyOneToOneRatesIfNeeded`, en el mismo fichero, **sí** lleva flag one-shot en `UserDefaults`,
y su docblock dice por qué (`TransactionUpdateService.swift:39-42`):

> repetirlo en cada arranque sería recorrer todas las transacciones para siempre a cambio de nada. Y
> `exchangeRate` viaja por el canal nube en el grupo de coherencia `money`, así que cada fila marcada
> emite: conviene que ocurra una vez y no en bucle.

Ese razonamiento **no se aplicó al bucle que ese barrido alimenta**.

## Los tres daños, medidos el 2026-09-07

1. **Coste de arranque, en el camino crítico.** `findMissingDates` hace **un `context.fetch` por día**
   del rango `min...max` de todo lo marcado (`ExchangeRateService.swift:477-493`). Tres años de
   histórico ≈ 1.100 fetches por arranque aunque no falte ni una fila. Va `await`-eado en el paso 2 del
   bootstrap, antes de `isBootstrapSettled`.
2. **Emisión repetida al canal nube.** `TransactionItem.recalculatePreferredCurrency`
   (`TransactionItem.swift:126-152`) asigna las cuatro columnas del grupo `money`
   **incondicionalmente**, aunque el valor recalculado sea idéntico: SwiftData ensucia igual.
   `DeltaEmitter` expande cualquier columna tocada **al grupo entero** y le sella un HLC fresco. El
   `if updatedCount > 0` no lo evita: solo se salta el `save()` explícito, y `autosaveEnabled` no
   aparece **en ningún sitio de `Yala/`** (cero ocurrencias) + hay saves garantizados en el mismo
   arranque sobre el mismo contexto.
3. **Riesgo de pisar la edición de otro dispositivo.** El grupo `money` resuelve por LWW de su propio
   reloj (`CloudSyncReconciler.moneyHLC`). Un dispositivo que arranca sin haber hecho pull re-sella
   toda la población marcada con un HLC nuevo llevando **sus valores locales aproximados**, y al
   pushear ganan a la edición legítima —anterior en HLC— del otro. No hay eco infinito: el apply del
   grupo `money` llega autoritativo y nunca llama `recalculatePreferredCurrency`
   (`EntityApplyMap.swift:15-16`).

## Qué NO es este ticket

**No es una regresión de `fx-manual-writes-seal-approximate-as-final`.** Los tres mecanismos son
anteriores: `recalculatePreferredCurrency` incondicional viene de `85ba0077`
(`fx-partial-rate-rows-silent-1to1`) y el reparador ya corría en cada arranque. Lo que hizo aquel
ticket fue **aumentar la población** que los recorre — que es lo correcto, porque antes esas
transacciones tenían un número aproximado **sellado como definitivo y sin ninguna ruta de cura**. El
trade-off cambió de «dato falso, coste cero» a «dato correcto y marcado, coste de arranque», y este
ticket es el que paga la segunda mitad.

## Criterio de hecho (AC)

- [x] `findMissingDates` / `rateExists` preguntan por **cobertura de divisa**, no por existencia de
      fila — o `ensureRates` recibe las divisas que hacen falta. Sin esto la cola no tiene salida y lo
      demás es paliativo.
- [x] `recalculatePreferredCurrency` no asigna si el valor no cambia (guard de igualdad en las cuatro
      columnas del grupo `money`). Corta a la vez la emisión repetida y el clobber por HLC.
- [x] Un tope o backoff en `updateProvisionalTransactions`: `fetchLimit`, intentos por transacción, o
      sentinel por `dateKey` ya intentado sin éxito.
- [x] Que una cola atascada sea **visible**: el log de DEBUG sale del `if updatedCount > 0`, o hay un
      canario del tamaño de la cola por arranque.
- [x] Test: con fila parcial y sin red, dos arranques seguidos no deben reescribir dos veces la misma
      transacción. Hoy la reescriben siempre.

---

## Cerrado el 2026-09-08

### Qué cambia para quien usa la app

Una transacción en una divisa para la que ese día no había tasa **se corrige sola en cuanto la tasa
llega**, en vez de quedarse esperando indefinidamente con un número aproximado. Y el arranque deja de
cargar con un trabajo que no servía para nada: hasta hoy, cada vez que se abría la app se recorría la
lista entera de transacciones pendientes de tasa y se volvía a escribir cada una —también en los otros
dispositivos, por el canal de sincronización— aunque no hubiera nada nuevo que aplicarles.

El caso concreto que no tenía salida: existe la fila de tasas de ese día, pero **sin la divisa que
hacía falta**. El reparador preguntaba «¿tengo la fila?» en vez de «¿tengo la tasa?», así que se
respondía que sí y no pedía nada. Ahora pregunta por la divisa.

### Ficheros

| Archivo | Qué cambia |
|---|---|
| `Yala/App/Logic/ExchangeRateCoverageLogic.swift` | NUEVO. La única pregunta «¿esta fila cubre estas divisas?», con el mismo criterio de tasa servible que usa el converter |
| `Yala/App/Logic/FXRepairQueueLogic.swift` | NUEVO. La huella del barrido estéril y la decisión de saltárselo |
| `Yala/Services/ExchangeRateService.swift` | `rateExists` RETIRADA; `rateCovers` la sustituye; `findMissingDates` pregunta por divisa y hace **un** fetch por rango en vez de uno por día; `ensureRates(for:needing:)`, `uncoveredDates(among:)` y `fetchRates(for:)`; troceo a 365 días; freno diario en `updateTodayIfNeeded` |
| `Yala/Utils/DataWipeService.swift` | El wipe borra también la huella del reparador |
| `Yala/Models/TransactionItem.swift` | `recalculatePreferredCurrency` solo asigna lo que cambia |
| `Yala/Services/TransactionUpdateService.swift` | Salida del bucle, divisas pedidas por nombre, log siempre, canario |
| `Yala/Services/Metrics/MetricsService.swift` | Canario `fxRepairQueueStuck` |
| `YalaTests/FXRepairQueueTests.swift` | NUEVO. 16 casos en 2 suites |
| `qa/coverage-index.json` | Área `fx-conversion-persistence` |

### Correcciones al propio ticket, medidas en este árbol

1. **El daño nº 2 del ticket es FALSO, y lo dice una medición.** El ticket afirmaba que reescribir las
   columnas del grupo `money` con el mismo valor emite igual al canal nube, y de ahí colgaba también el
   daño nº 3 (pisar por HLC la edición de otro dispositivo). Medido el 2026-09-08 con el motor real
   (`FXRepairQueueOutboxTests`): una asignación idéntica deja `context.hasChanges == true` pero **el
   drain no produce ni una fila de outbox**. Son dos señales distintas — el estado sucio del contexto y
   el change-set que el History entrega al motor — y en este repo no había ningún test, regla ni
   documento que afirmara nada sobre esto (`updatedAttributes` aparece 4 veces en todo el árbol).
   El guard de igualdad se queda porque sigue evitando un `save()` a disco por arranque y por
   transacción, no por la emisión que no ocurre.
2. **«las cuatro columnas del grupo `money`» — el grupo tiene CINCO emisores.** `amount` también va en
   ese grupo (`EntityEmissionMap.swift:179`), y `recalculatePreferredCurrency` no lo toca.
3. **`rateExists` tenía DOS llamadores, no uno.** El otro era `updateTodayIfNeeded`, o sea la fila de
   **hoy** — la que más transacciones marca provisionales, porque son las que el usuario acaba de
   apuntar. Arreglar solo `findMissingDates` habría dejado el caso más frecuente sin cura.

### Lo que el AC no pedía y sin ello el arreglo no cerraba

**La cobertura tiene que descartar las tasas inservibles, no solo mirar si la clave está.** Una tasa
`0` guardada tiene su clave presente, pero `CurrencyConverter.resolveRates` la trata como ausente y
degrada igual. Una cobertura que contara la clave habría dicho «cubierta» de algo que nunca da una
conversión exacta ⇒ el bucle seguiría vivo para esas filas. Es **la forma exacta del bug original**
—una pregunta más laxa que la que de verdad decide— reproducida dentro de su propio arreglo.

### Lo que cazó la review adversarial (4 lentes), y era todo mío

Ninguno de estos lo veía la suite. Los seis primeros están arreglados en este PR:

1. **La huella se escribía también cuando lo que falló fue la RED**, mientras su propio docblock
   prometía lo contrario: `ensureRates` se tragaba el error y el barrido no tenía forma de distinguir
   «el proveedor no tiene esa divisa» de «no llegué a preguntar». Una transacción curable se quedaba
   esperando. Ahora el fetch devuelve si todo salió bien y un resultado indeterminado **no sella nada**.
2. **La huella era ciega a las tasas que llegan por CloudKit.** Contaba un contador de escrituras de
   `persistRate`, y `ExchangeRate` está espejado por CloudKit y lo escribe también el applier del Modo
   Nube — sin ejecutar una línea de nuestro código. Un dispositivo podía tener ya en disco la fila que
   cura su cola y saltarse el barrido. Ahora la huella mide **la cobertura observada en disco**, que da
   igual quién la escribiera; el contador desapareció entero.
3. **El barrido estéril pasó a refetchear el histórico completo.** Si al proveedor le falta una divisa,
   le falta todos los días del rango: pedir `min…max` de la cola son ~1.000 días con un `context.save()`
   por día, en el camino crítico del arranque. Ahora se piden **las fechas de la cola**, que son tantas
   como transacciones, no como días entre la primera y la última.
4. **`ensureRates` no troceaba a 365 días.** El repo ya documenta ese tope de la API en
   `preloadHistoricalIfNeeded`, pero `ensureRates` no lo respetaba — daba igual mientras preguntaba por
   existencia de fila, porque nunca pedía rangos largos. Al pasar a cobertura, la petición de varios
   años que el proveedor rechaza entera se volvió el caso normal, con el usuario esperando delante del
   spinner de cambio de divisa. El troceo va en `groupIntoRanges`, por donde pasan los tres caminos.
5. **La fecha más nueva de la cola podía no pedirse nunca.** El recorrido día a día parte de la hora de
   `min` y compara contra `max`: con horas distintas —lo normal al mezclar un import a medianoche con
   una entrada manual por la tarde— el último día no se generaba. Y es justo la transacción más
   reciente, la que más probablemente está pendiente.
6. **El mismo patrón sin arreglar en la función de al lado.** `repairLegacyOneToOneRatesIfNeeded`
   asignaba `isExchangeRateProvisional = true` sin mirar el flag actual, y su filtro no lo mira nunca:
   la población que ya estaba marcada —exactamente la del bug— recibía una asignación idéntica.
7. **`updateTodayIfNeeded` se quedaba sin freno.** Con la cobertura como única puerta, una divisa que
   el proveedor no sirva nunca provocaría una petición en cada arranque y en cada apertura del
   formulario. Ahora hay un segundo freno por día, con la clave que ya se escribía y **nadie leía**.

Tres hallazgos más salieron de camino y **no son de este ticket**, así que tienen el suyo:
`wire-decoder-accepts-non-finite-money`, `currency-change-asks-rates-for-the-old-currency` y
`ensure-rates-for-existing-transactions-has-no-callers`.

### Decisiones, con su porqué

1. **Huella causal en vez de backoff por tiempo.** Una ventana («no reintentes en 24 h») corta el coste
   pero también corta la cura: si las tasas llegan cinco minutos después, la transacción se queda mal
   un día entero por una constante que nadie eligió con un dato delante. La huella describe el estado
   del que dependía el resultado, así que reintenta exactamente cuando algo pudo cambiar.
2. **La huella mide el DISCO, no nuestras escrituras.** Es la corrección que trajo la review: un
   contador de `persistRate` no ve lo que llega por CloudKit ni por el applier del Modo Nube. Contar
   filas tampoco valía —`persistRate` fusiona, así que completar una parcial no cambia cuántas hay—.
   Lo que se cuenta es cuántas fechas de la cola siguen sin la tasa que necesitan.
3. **La huella se recalcula DESPUÉS del barrido.** Guardar la de la entrada dejaba el bucle vivo: si el
   barrido trajo tasas nuevas y aun así no curó nada, el arranque siguiente vería otra cobertura y
   repetiría el trabajo entero.
4. **Se cuentan las tocadas, no solo las selladas.** Una tasa arrastrada mejor mejora el monto sin
   poder sellarlo como definitivo: con el contador de selladas como único criterio, ese trabajo no se
   guardaba y encima el barrido se marcaba estéril, bloqueando el reintento de una mejora real.
4. **`ensureRates(for:context:)` conserva su firma** y por dentro pide la cobertura de lo que la app
   usa. Los cuatro llamadores que no son el reparador quieren exactamente eso, así que ninguno se tocó.
   El reparador usa la sobrecarga con `needing:`, porque las divisas de sus transacciones no tienen por
   qué estar entre las de la app: un gasto en yenes de un viaje no deja ninguna cuenta en yenes detrás.

### Verificación

- **16 casos nuevos en 2 suites, verdes**, más la suite unit completa.
- **Control positivo por mutación, tres veces.** (a) Quitado el guard de igualdad,
  `partialRow_secondRecalculateWritesNothing` se pone rojo y **solo ése**. (b) Quitado el troceo,
  cae `longRange_isChunkedIntoRequestsTheProviderAccepts`. (c) Devuelto `uncoveredDates` al recorrido
  por rango, caen los dos tests de fechas sueltas —incluido el de la hora del día, que es el bug real
  que la review encontró— y los otros 12 siguen verdes.
- Los tests de `ensureRates` usan un provider falso y ejercitan el `#Predicate` de rango de Strings
  **contra el store**. No es un detalle: en este repo un `#Predicate` compila limpio y revienta al
  ejecutarse, así que probar solo la lógica pura no habría probado el camino.
- `FXRepairQueueOutboxTests` cuenta filas de outbox tras un `drainOnce` real, con su control positivo.
  Es lo que refutó el daño nº 2 del ticket: leer el estado final no habría distinguido nada.

### Qué tiene que mirar el QA en device

Una transacción en una divisa que no esté en ninguna cuenta (yenes, por ejemplo), fechada en un día
cuya fila de tasas ya exista sin esa divisa. Comprobar que **se corrige sola** al llegar las tasas, y
que abrir y cerrar la app varias veces sin conexión no la reescribe (el canario `fxRepairQueueStuck`
con `detail=skipped` debe aparecer una vez por arranque, no un barrido entero).

## Corrección al guion · 2026-09-16 (barrido de QA, medida en código)

**«Qué tiene que mirar el QA en device» (:216-219)** — `skipped` **no puede aparecer sin conexión**.
Un fallo de red nunca sella el barrido como estéril: el sello exige `allFetchesSucceeded`
(`TransactionUpdateService.swift:365`), y el salto solo ocurre contra un barrido ya sellado (:285-295).
Offline, cada arranque vuelve a intentarlo y falla.

Guion corregido: **con conexión**, una transacción en una divisa que el proveedor no traiga para esa
fecha. Primer arranque → barrido estéril sellado (`futile`). Arranques siguientes, sin cambios →
`fxRepairQueueStuck` con `detail=skipped` **una vez por arranque**. Al llegar tasas nuevas o cambiar la
cola → se corrige sola.
