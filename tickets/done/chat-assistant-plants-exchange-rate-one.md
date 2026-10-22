---
id: chat-assistant-plants-exchange-rate-one
status: done
priority: medium
area: "currency, chat"
created: 2026-09-07
updated: 2026-09-23
source: hallazgo de camino en fx-manual-writes-seal-approximate-as-final (2026-09-07)
qa-status: not-replicable
qa-date: 2026-09-23
qa-notes: barrido 2026-09-23 sin device-QA - solo cambia la tasa del detalle; lo fija ChatDraftExchangeRateTests con mutante
---

# Crear una transacción desde el chat guarda `exchangeRate = 1.0` sin mirar la tasa

## Qué le pasa al usuario

En `ChatAssistantViewModel.swift:513` la transacción nace con `exchangeRate: 1.0` **literal**, aunque
el monto convertido de al lado sí salga de una conversión real. Las otras seis rutas que crean
transacciones derivan la tasa efectiva del propio resultado
(`amountInPreferred / amount`, con el guard de `abs(amount) > 0.0001`); ésta no.

El número que se ve en el detalle de la transacción dice «1,00» para un gasto en otra divisa.

## Actualizado el 2026-09-07: sube a `medium`, y el bug de la FECHA ya se arregló

La review adversarial de `fx-manual-writes-seal-approximate-as-final` destapó que esta ruta tenía
**dos** defectos, no uno, y que el segundo era peor:

**Arreglado ya (en aquel PR):** convertía con `convertCheckedWithLatestRate` —la tasa de HOY— y
después estampaba la transacción con `draft.date`, que el parseo resuelve como `parsed.date ?? .now`.
Dictar «un café ayer» guardaba el gasto convertido a la tasa de hoy. Peor: **el reparador convierte
`on: date`** (`TransactionItem.swift:130`), así que el número guardado no era reproducible por el
proceso que existe para repararlo — al pasar por él habría cambiado. Ahora convierte `on: draft.date`
como las otras seis rutas de creación.

**Sigue vivo (esto es el ticket), y sube a `medium`:** el `exchangeRate: 1.0` plantado. La razón por la
que estaba en `low` —«el reparador lo cura»— es falsa en el caso NORMAL: cuando la tasa es exacta el
flag queda `false`, la transacción sale de la cola del reparador (`#Predicate` = `== true`) y el 1.0
mentiroso se sella para siempre. O sea que esta ruta guarda una tasa falsa en **la mayoría** de sus
ejecuciones, no en la minoría.

## Por qué NO era `high` (la valoración original, que ya no aplica del todo)

Desde `fx-manual-writes-seal-approximate-as-final` (2026-09-07) esta ruta **marca la provisionalidad**
correctamente, y el reparador (`TransactionUpdateService`) recalcula monto **y tasa** al pasar por una
transacción provisional — así que el 1.0 se cura solo en el arranque siguiente **cuando la conversión
fue aproximada**. Lo que NO se cura es el caso exacto: conversión buena, flag en `false`, y el `1.0`
plantado se queda.

Segundo efecto, menor: `ExchangeRateRepairLogic.needsRepair` usa `exchangeRate == 1.0` como criterio,
así que estas transacciones parecen candidatas del barrido legacy sin serlo. Ese barrido es one-shot y
ya corrió, de modo que hoy no cambia nada — pero es una señal falsa si alguien lo reabre.

## Criterio de hecho (AC)

- [x] La ruta deriva la tasa efectiva como las demás, con el mismo guard del umbral.
- [x] Un test: transacción creada desde el chat en divisa distinta de la preferida guarda un
      `exchangeRate` distinto de 1.0 y coherente con `amountInPreferredCurrency / amount`.
- [x] Buscar el patrón: ninguna otra ruta de creación planta la tasa en vez de derivarla.

## Cerrado el 2026-09-08

**Lo que cambia para el usuario:** el detalle de un gasto en otra divisa deja de decir «1,00» y enseña
el tipo de cambio que de verdad se usó al guardarlo.

**El fix**, en `ChatAssistantViewModel.saveDraft`: la tasa se deriva del mismo `outcome` que ya
producía el monto convertido (`amountInPreferred / amountDouble`, guard `abs(...) > 0.0001`,
`abs(effectiveRate)`), idéntico a `TransactionItem.recalculatePreferredCurrency`. Esa identidad no es
estética: es lo que hace que el número guardado sea **reproducible por el proceso que existe para
repararlo**, y de paso elimina una emisión espuria al canal nube (antes, la primera pasada del
reparador cambiaba la tasa y expandía el grupo `money` entero con HLC fresco; ahora coinciden y el
guard de igualdad no toca nada).

**Nota de línea:** el ticket citaba `ChatAssistantViewModel.swift:513`. En el árbol de trabajo era la
**531** — el comentario del fix de fecha de #94 la había desplazado.

### AC nº3, medido: era el ÚNICO sitio

Barrido de las **18 construcciones** de `TransactionItem` fuera de `Yala/Seed/` y de tests. Un solo
sitio plantaba tasa falsa habiendo conversión real: éste. De los otros doce que pasan `1.0`, once lo
hacen de forma **transitoria** porque llaman `recalculatePreferredCurrency` inmediatamente después
(`InitialBalanceService` ×2, `GroupTransactionBridge` ×8, más la rama de update), y uno es el stub de
fábrica del apply de sync (`EntityApplyMap`), donde el grupo `money` llega del wire y está prohibido
recalcular.

Riesgo latente que el barrido dejó a la vista: el init de `TransactionItem` tiene
`exchangeRate: Double = 1.0` por defecto, así que **olvidar la línea de recálculo posterior es
silencioso**. Once sitios dependen hoy de esa línea, y así fue como se llegó a este bug.

### Una premisa del ticket era falsa

Arriba decía que estas filas «parecen candidatas del barrido legacy **sin serlo**». Es al revés:
`ExchangeRateRepairLogic.needsRepair` pide `exchangeRate == 1.0` **y** divisa distinta de la preferida
— que es exactamente el daño. Eran candidatas **legítimas**. Lo que las deja sin cura no es que sean
falsos positivos, sino que ese barrido es **one-shot por dispositivo**
(`guard !defaults.bool(forKey: "fxOneToOneRepairSweep.v1")`, y el flag se marca aunque no hubiera
candidatas). Eso agrava el ticket en vez de atenuarlo, y las filas ya escritas quedan fuera de
alcance → `chat-rows-sealed-before-the-fix-have-no-repair-path`.

### Verificación

`YalaTests/ChatDraftExchangeRateTests` (2 casos). El escenario es de fila de tasas **completa** a
propósito: con tasa aproximada el flag queda `true`, la fila entra en la cola del reparador y el 1.0
se curaba solo — un test con fila parcial habría pasado en verde con el bug puesto.

**Control positivo por mutación** (repetido tras endurecer el test): replantar `exchangeRate: 1.0`
pone el primer caso en rojo con 2 issues —la tasa y su coherencia con el monto— mientras la pareja de
control, donde `1.0` es el valor CORRECTO, sigue verde. Eso es lo que impide satisfacer el test
escribiendo cualquier número distinto de 1.0.

### Review adversarial (3 lentes) — lo que cazó

1. **Un comentario mío era falso.** Justificaba el umbral diciendo que la división «daría infinito o
   NaN»; la guard de entrada ya garantiza `isFinite` y `> 0`, y `0.000372 / 0.00005` es 7,44. El
   umbral está por **paridad con el reparador**, no por aritmética. Corregido en el código.
2. **La banda `0 < monto <= 0.0001` reproduce el bug** dentro del propio arreglo. Se deja a propósito
   porque el reparador tiene el mismo umbral y romper la paridad haría que la fila cambiara de número
   al repararse → `fx-rate-derivation-threshold-reseals-one-to-one`.
3. **Seis defectos en el test**, corregidos: comparación de divisa sin normalizar (un simulador con la
   preferida guardada como `"jpy"` lo ponía rojo **con el fix puesto**), `.first` sin exigir una sola
   fila, `setContext` redundante que dejaba el singleton apuntando a este store, «hubo conversión»
   inferido en vez de afirmado, y una cabecera mía que decía que el fichero no comparte estado —
   cierto para el store, **falso** para `SessionState` y los defaults.
4. **`prefillFromContext` cambia de rama** y a mejor: una fila del chat en divisa extranjera caía en
   el `else` que recalculaba el rate para compensar el 1.0 falso; ahora usa la tasa persistida, que es
   la real.
5. Dos hallazgos ajenos a esta ruta, con ticket propio: `chat-draft-drops-the-expense-sign` (**high**)
   y `exchange-rate-detail-shows-zero-for-low-denomination-currencies`.

### Qué falta

Device-QA. **No es simulable con los seeds actuales** — ninguno es multi-divisa, así que para ver el
número en el detalle hace falta una cuenta en otra divisa y el chat contra el LLM real.

---

## 2026-09-09 — el montaje que esperabas ya existe

El estado de partida se siembra desde un solo launch con `-uitest -uitest-reset -uitest-skip-onboarding -uitest-seed realista -uitest-seed-foreign-account JPY` (ticket `qa-no-puede-crear-cuenta-en-otra-divisa`, **done**). Deja la cuenta «QA FX» con un ingreso y dos gastos fechados HOY, marcados `isExchangeRateProvisional` por el camino de producción — la fila del día existe y no trae JPY, así que la conversión es `.staticFallback`.

**Aviso para no leer un falso negativo:** con el filtro «Todo el tiempo» el fixture NO marca (750 sobre 206.725 son el 0,36 %, bajo el umbral del 5 %). **Acota el período** — con «Este mes» los tres números del Panel llevan «≈» y sin el arg ninguno.

**Desbloqueado a medias.** La cuenta en otra divisa ya la tienes; sigue haciendo falta **el chat contra el LLM real** (:131), que no se simula.

Y una corrección a tu :130: «ninguno es multi-divisa» es **falso** — `DevSeedAccounts` crea PEN + USD desde siempre (`done/distribution-balance-kpi-skips-fx:281` ya lo midió). Lo que faltaba no era multi-divisa, era una divisa FUERA de la fila.

## Barrido de `qa` · 2026-09-23 · cerrado sin device-QA

Sale de la cola de device-QA por el barrido que pidió Jürgen el 2026-09-23 (encargo `2026-09-23-barrido-qa-in-qa-pre-device`). Solo cambia la tasa que se ve en el detalle del movimiento. La fija `ChatDraftExchangeRateTests` con su mutante.
