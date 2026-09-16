---
id: chat-rows-sealed-before-the-fix-have-no-repair-path
status: done
priority: medium
area: "currency, chat"
created: 2026-09-08
updated: 2026-09-16
source: hallazgo de camino en chat-assistant-plants-exchange-rate-one (2026-09-08)
qa-status: passed
qa-date: 2026-09-16
---

# Las transacciones que el chat ya guardó con la tasa falsa no tienen quien las cure

## Qué le pasa al usuario

`chat-assistant-plants-exchange-rate-one` arregló la ruta **hacia delante**: desde el 2026-09-08 el
chat guarda la tasa que usó. Pero las transacciones que ya se guardaron con el `1.0` plantado siguen
ahí, y **el detalle de esas transacciones va a seguir diciendo «1,0000» para siempre**.

## Por qué no se curan solas (medido el 2026-09-08 en este árbol)

Hay dos mecanismos que deberían cogerlas, y ninguno lo hace:

1. **El reparador de arranque** (`TransactionUpdateService.updateProvisionalTransactions`) tiene un
   `#Predicate` que solo busca `isExchangeRateProvisional == true`. Cuando la conversión del chat fue
   **exacta** —el caso normal— el flag quedó en `false`, así que la fila nunca entra en esa cola. Ése
   es justamente el daño que describía el ticket padre.

2. **El barrido legacy** (`TransactionUpdateService.repairLegacyOneToOneRatesIfNeeded`) sí las
   reconocería: `ExchangeRateRepairLogic.needsRepair` pide `exchangeRate == 1.0` **y** divisa distinta
   de la preferida, que es exactamente la forma de estas filas. Pero es **one-shot por dispositivo**:

   ```swift
   private static let repairSweepKey = "fxOneToOneRepairSweep.v1"
   guard !defaults.bool(forKey: repairSweepKey) else { return }
   ```

   y el flag **se marca aunque no hubiera candidatas** (`TransactionUpdateService.swift`, comentario
   propio: «El flag se marca aunque no hubiera candidatas: el barrido HIZO su trabajo»). En cualquier
   instalación donde ese barrido ya corrió, no vuelve.

## La ventana afectada

Las filas creadas desde el chat, en divisa distinta de la preferida, **entre** el arranque en que
corrió `fxOneToOneRepairSweep.v1` y la build que traiga el fix del ticket padre. Las anteriores al
barrido sí se curaron. La ventana es corta pero real, y TestFlight build 12 está dentro.

## Corrección a una creencia del ticket padre

El ticket padre decía que estas filas «parecen candidatas del barrido legacy **sin serlo**». Medido:
es al revés — son candidatas **legítimas**, con el daño exacto que `needsRepair` busca. Lo que las
deja sin cura no es que sean falsos positivos, sino que el barrido no vuelve a correr.

## Criterio de hecho (AC)

- [x] Las filas ya selladas por el chat con `exchangeRate == 1.0` y divisa ≠ preferida vuelven a
      tener una ruta de reparación.
- [x] Si la vía elegida es un `fxOneToOneRepairSweep.v2`, que quede escrito **por qué** se rebobina
      el flag y qué corpus alcanza — un barrido que se re-dispara sin criterio es un aluvión de
      emisiones al canal nube por nada (`exchangeRate` viaja en el grupo de coherencia `money`).
- [x] Un test del barrido legacy. Hoy **no existe ninguno**: `grep -rn "fxOneToOneRepairSweep\|repairLegacyOneToOne" YalaTests/`
      da cero, y su única llamada de producción es `AppBootstrapper`.

## Decisión que puede necesitar Jürgen

Si el corpus afectado es pequeño, puede no compensar el riesgo de re-disparar un barrido sobre toda
la tabla. Esa es una decisión suya, no del código.

## Cerrado el 2026-09-08

**Lo que cambia para el usuario:** un gasto que dictó al chat en otra divisa y que quedó diciendo
«1,0000» en su detalle vuelve a enseñar el tipo de cambio que de verdad se usó — y lo hace **sin
tocar el importe convertido**, que estaba bien.

**La vía es la que el AC contemplaba**, `fxOneToOneRepairSweep.v2`: subir el número de la clave
rebobina el one-shot y el dispositivo que ya barrió vuelve a barrer una vez. Pero **lo que el barrido
HACE con cada fila cambió**, y ésa es la parte que vale.

### El plan obvio hacía daño, y lo destapó la review adversarial

Reabrir la fila —marcarla provisional para que el reparador de arranque la recalcule— es lo que hacía
la `.v1` y era el plan de partida. Medido: **para este corpus es peor que no hacer nada.**

Las filas de la `.v1` tenían el monto convertido **crudo** (la conversión había fallado), así que
recalcular solo podía mejorarlas. Las del chat tienen `amountInPreferredCurrency` **correcto** y solo
mienten en la columna `exchangeRate`. Y `recalculatePreferredCurrency` pisa el monto con lo que dé la
conversión de HOY: si la tasa de aquella fecha ya no está en disco, baja los escalones hasta la tabla
estática, que es un snapshot congelado (`ars: 1050.0` en `CurrencyUtils`, a un orden de magnitud del
valor de 2025). Cambiar un número bueno por uno peor es más daño que el que el ticket venía a curar.
Y hay camino a **pérdida permanente**: el pase siguiente ya no cambia nada, `allFetchesSucceeded`
sella la huella futile de `FXRepairQueueLogic` y la cola deja de reintentarlo.

**Ahora la tasa se deduce de los dos montos que ya están guardados**
(`ExchangeRateRepairLogic.rateFromStoredAmounts`) y se corrige en el sitio. Solo vuelve a la cola la
fila cuyo cociente vale 1 — el monto tampoco se convirtió, que es el corpus de
`fx-partial-rate-rows-silent-1to1` y sí necesita reconversión. Las dos poblaciones estaban bajo el
mismo criterio y tratarlas igual era el error.

**Segundo efecto, y lo cierra el mismo cambio.** Reabrir emite el grupo `money` **entero** —cinco
columnas, `DeltaEmitter` expande cualquiera de ellas al grupo— con la tasa envenenada **todavía
puesta** y un HLC fresco: bajo LWW por unidad, este barrido le habría ganado a un dispositivo par que
ya hubiera reparado esa fila. Difundía el veneno. Corrigiendo antes de guardar, lo que viaja es el
valor bueno.

**Tercero, y lo cazaron las rules de divisas, no una lente:** un monto convertido en `0` da cociente
`0`. Sellar eso reproduciría dentro del arreglo la forma exacta del bug del módulo —una tasa
inservible que pasa por dato—. Se filtra con `CurrencyConverter.isUsableRate`, que es la misma
pregunta que hacen la cobertura de la caché y el guard de la conversión.

### Dos guards nuevos, y no son el mismo

El barrido nació el 2026-09-03 (`6ddc4367`), **después** de que `ccbc97e9` gateara por quiescencia
los `save()` del store personal en el arranque, y no lo tenía: hacía `save()` en pleno import del
restore mientras `updateProvisionalTransactions` —tres líneas más abajo— sí salía por el suyo. En ese
arranque el barrido tocaba filas, quemaba el flag, y el reparador que debía curar las reabiertas ni
siquiera corría. Ahora comparte el gate.

Y **sobre un store sin ninguna transacción ya no se sella**: es el punto ciego que
`ChatUnsignedExpenseRepairService` cerró para su propio barrido citando a éste por su nombre. Su
referencia cruzada se actualiza aquí, porque el cambio la dejaba apuntando a otras líneas.

**Residual declarado, no resuelto.** `isImportQuiescent` vale `true` **antes** de que empiece ningún
import (`lastImportDate == nil`, documentado en `BootSaveGateLogic`), así que en el arranque en frío
de un restore el gate está abierto; y el guard de presencia distingue *vacío* de *no vacío*, no
*completo* de *parcial* — un restore que ya entregó 3 filas de 5.000 sella igual. Cerrarlo pedía el
gate de seis entradas de `awaitPersonalStoreReady`, que este barrido no usa porque **no espera nada en
absoluto** → `fx-repair-sweep-seals-on-a-partially-restored-store`.

### Verificación

`YalaTests/FXOneToOneRepairSweepTests` (13 casos), **9 mutantes verificados**, cada uno rojo en su
caso y solo en el suyo. El que más importa es `reabrir-siempre`: reponer el diseño anterior pone en
rojo el caso principal con 4 issues, uno de ellos el del monto — o sea que el hallazgo de diseño está
demostrado, no razonado.

**El agujero de test que cazó la segunda lente:** los 12 casos de comportamiento inyectan
`isQuiescent` y `defaults`, y producción no pasa ninguno de los dos — un mutante `isQuiescent ?? true`
dejaba la suite **entera** verde devolviendo la app al bug del ticket. Lo cierra
`productionCallSite_isWiredToTheSyncService`, que además pinnea el orden barrido → reparador que el
comentario de producción declara crítico y que no cubría nadie.

### Correcciones a este ticket, medidas

1. **El AC nº3 decía que el grep «da cero» y da una línea** (el `// MARK:` de
   `TransactionUpdateServiceTests`). La sustancia se sostiene —ningún test invocaba la función— pero
   la cifra no era la de este árbol.
2. **«Un barrido que se re-dispara es un aluvión de emisiones» estaba mal calibrado en los dos
   sentidos.** El coste no es el tamaño del store sino el número de filas candidatas; pero cada una
   emite **las cinco** columnas del grupo, no una. Y el problema serio no era el volumen: era el
   contenido de lo que se emitía.
3. **La banda del umbral es `0 < |monto| <= 0.0001`**, con valor absoluto: desde el PR #102 los
   gastos del chat se guardan negativos, o sea justo la mitad que un rango sin `abs` dejaría fuera.

### Qué falta

Device-QA. **Sí es simulable**: hace falta una cuenta en otra divisa y una fila sembrada con
`exchangeRate = 1.0` y monto convertido real; al arrancar, el detalle debe pasar de «1,0000» a la tasa
verdadera **sin que cambie el importe convertido**, y sin que aparezca el «≈». El log de DEBUG imprime
el reparto entre curadas en el sitio y reabiertas, que es lo que responde cuántas filas había de
verdad.

### Hallazgos de camino, con ticket propio

- `fx-repair-sweep-seals-on-a-partially-restored-store` (medium)
- `fx-repair-sweep-is-the-only-boot-sweep-without-a-uitest-gate` (low)
- `fx-repair-sweep-has-no-canary` (low)

---

## 2026-09-09 — el montaje que esperabas ya existe

El estado de partida se siembra desde un solo launch con `-uitest -uitest-reset -uitest-skip-onboarding -uitest-seed realista -uitest-seed-foreign-account JPY` (ticket `qa-no-puede-crear-cuenta-en-otra-divisa`, **done**). Deja la cuenta «QA FX» con un ingreso y dos gastos fechados HOY, marcados `isExchangeRateProvisional` por el camino de producción — la fila del día existe y no trae JPY, así que la conversión es `.staticFallback`.

**Aviso para no leer un falso negativo:** con el filtro «Todo el tiempo» el fixture NO marca (750 sobre 206.725 son el 0,36 %, bajo el umbral del 5 %). **Acota el período** — con «Este mes» los tres números del Panel llevan «≈» y sin el arg ninguno.

**Desbloqueado a medias.** La cuenta ya la tienes; falta la otra mitad de tu :156 —una fila sembrada con `exchangeRate = 1.0` y monto convertido real—, que es la población envenenada que el reparador debe curar. El seam siembra filas SANAS-pero-aproximadas, que es el caso contrario.

Ojo al elegir cómo sembrarla: `.claude/rules/currency-fx.md` avisa de que reabrir una fila cuyo monto ya era bueno DESTRUYE datos, y las dos poblaciones se distinguen por el cociente `amountInPreferredCurrency / amount`.

---

## Device-QA hecho · 2026-09-09 — PASS

**El montaje que faltaba se implementó en esta sesión**: `-uitest-seed-chat-sealed-rate <ISO>`
(`DevSeedChatSealedRate`) siembra exactamente la población que tu :156 pedía — una fila con
`exchangeRate = 1.0`, divisa ≠ preferida y **monto convertido real**. El monto sale del converter de
producción y el veneno se planta DESPUÉS del recálculo; si fuera antes, la fila nacería sana.

Y hace la distinción que avisaba `.claude/rules/currency-fx.md`: como el cociente de los dos montos
guardados no vale 1, esta fila cae en la población que se **cura en el sitio**, no en la que se
reabre. Sembrar el monto crudo habría reproducido el caso contrario — el que destruye datos.

### El veredicto, medido

Simulador iPhone 17 Pro (`9D0F6D32`), iOS 26.5, `Yala Dev`. Dos arranques:

1. `-uitest -uitest-reset -uitest-skip-onboarding -uitest-seed realista -uitest-seed-chat-sealed-rate JPY`
2. lo mismo **sin** `-uitest-reset` y **sin** `-uitest-seed` (ver el aviso de abajo)

| | detalle de la transacción |
|---|---|
| tras el arranque 1 | `≈ S/ -600,00` · **`TC: 1.0000`** |
| tras el arranque 2 | `≈ S/ -600,00` · **`TC: 0.0237`** |

**El importe convertido no cambió y la tasa pasó a ser la verdadera** — que es literalmente el AC.
Log del barrido: `repair sweep fixed 1 in place and reopened 0 of 1 candidates`, o sea que tomó el
camino de curar y no el de reabrir. Sin «≈», porque la fila no está marcada como provisional.
Capturas `qa/evidencia-fx-20260909/10` y `/11`.

### Por qué el par de arranques sale gratis, y qué lo puede estropear

El barrido es el **paso 2** del bootstrap (`loadExchangeRates`) y el seed el **19**
(`applyUITestSeed`), así que en el arranque que siembra el barrido ya pasó sobre un store vacío y no
quema el flag (su guard `candidates.isEmpty && fetchCount == 0`). No hubo que tocar el orden.

Dos avisos para quien repita la receta:

- **En el arranque 2, NO pases `-uitest-seed <perfil>`.** Vuelve a sembrar el corpus entero: medido,
  2.326 → 4.651 registros, con «Bolt» duplicado y los totales al doble. No es un bug de cálculo →
  [[uitest-seed-reseeds-the-corpus-without-reset]].
- **El barrido depende del gate de quiescencia de CloudKit**, así que puede no correr en un arranque
  concreto. Si el log no imprime la línea `repair sweep …`, relanza; no es un FAIL.

### Un defecto del montaje, corregido aquí

`-uitest-reset` **no rebobina el one-shot**: `DataWipeService` borra una lista explícita de claves y
`fxOneToOneRepairSweep.v2` no está en ella. Sin arreglarlo, el fixture sólo servía **una vez por
simulador** — a la segunda el barrido salía por su primer `guard`, la fila se quedaba en «1,0000» y
el QA lo habría leído como un FAIL del producto que no lo es. Lo rebobina ahora el propio fixture
(`DevSeedChatSealedRate.rewindRepairSweepOneShot`), que es lo mínimo: quien siembra la fila deja el
barrido en condiciones de correr, sin tocar el «Empezar de cero» de producto, que es otra decisión.

### Verificación del fixture

`YalaTests/DevSeedChatSealedRateTests` (7 casos) + **5 mutantes**, todos rojos donde debían:
préstamo sellado exacto, pata real puesta a «mi parte», veneno no plantado, clave del one-shot
desincronizada, guard de idempotencia retirado. El que más importa es el de la clave: si divergiera,
el fixture rebobinaría una clave muerta y el veredicto sería un falso FAIL.

## QA Visual · 2026-09-16 — PASS (re-verificado)

Simulador iPhone 17 Pro (iOS 26.5), sobre `2.1` @ `bebd57a57`, `Yala Dev`. La receta del 2026-09-09, en dos arranques:

| Arranque | Montaje | Hoja de detalle (Registros) |
|---|---|---|
| 1 | instalación limpia, seed `realista` + `-uitest-seed-chat-sealed-rate JPY` | `≈ S/ -600.00` · **TC 1.0000** |
| 2 | `-uitest -uitest-skip-onboarding`, sin reset ni seed | `≈ S/ -600.00` · **TC 0.0237** |

Log del arranque 2: `repair sweep fixed 1 in place and reopened 0 of 1 candidates`. El importe no cambia,
la tasa pasa a la verdadera, y Gastos de «Todo el tiempo» da S/ 204,344.00 en los dos arranques. El «≈»
del detalle no es la marca de provisional: esa hoja lo antepone siempre al importe convertido
(`TransactionDetailSheet.swift:459`).

**Para quien lo repita:** mira la hoja de detalle de Registros, no el formulario de edición. El
formulario (desde Buscar) recalcula la tasa en vivo y ya enseña 0.0237 en el arranque 1, así que no
distingue nada.

Capturas: [antes](../../qa/evidencia-barrido-20260916/16-chat-sealed-ANTES-tc-1.0000.jpg) · [después](../../qa/evidencia-barrido-20260916/17-chat-sealed-DESPUES-tc-0.0237.jpg).
