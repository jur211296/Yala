---
id: resolved-amount-trusts-a-zero-converted-amount
status: done
priority: low
area: "currency, fx, statistics"
created: 2026-10-11
updated: 2026-10-11
source: hallazgo de bridge-synthesis-trusts-a-zero-converted-amount (2026-10-11)
---

# Un movimiento suelto con la conversión sin escribir cuenta 0 en las estadísticas, y sin marca

## Qué le pasa al usuario

Un gasto en otra divisa cuya conversión a la divisa principal no llegó a escribirse aparece en sus
estadísticas como **0**: no suma al gasto del mes, y el total no lleva «≈».

## Dónde, medido el 2026-10-11

`CashFlowCalculator.resolvedAmount`, primera rama: si `tx.preferredCurrencyCode == currencyCode` lee
`amountInPreferredCurrency` tal cual, y un 0 con `amount != 0` entra como importe real. La duda sale
del flag de la fila, que en una fila que nunca se convirtió es su default `false`.

Desde `bridge-synthesis-trusts-a-zero-converted-amount` la síntesis de un gasto de grupo ya trata
ese cero como conversión ausente y reconvierte con `CashFlowCalculator.reconverted`. Una fila suelta
no pasa por esa síntesis.

La ventana es estrecha por la misma razón que en el bridge: `recalculatePreferredCurrency` escribe la
conversión al guardar, así que el cero solo aparece con una fila que llegó incompleta por sync o que
se creó sin contexto de tasas.

## Qué habría que hacer

Decidir si `resolvedAmount` aplica el mismo criterio: cero con nativo no nulo ⇒ segunda rama
(reconvertir). Toca a todos los consumidores de `resolvedAmount` y al port de `mcp/`
(`preferredAmount` en `summary.ts`), así que va con su golden.

## Criterio de hecho (AC)

- [ ] Una fila suelta con el importe convertido a 0 cuenta su importe reconvertido, con «≈» si la
      tasa no es exacta.
- [ ] El conector `mcp/` da lo mismo (golden de paridad).

## Cerrado el 2026-10-11

Decidido: el mismo criterio que la síntesis del bridge (#460). Un `amountInPreferredCurrency == 0` con `amount != 0`
va a la segunda rama de `resolvedAmount` (reconvertir con la tasa de su día; «≈» si no es exacta).

- **Un solo sitio:** `CashFlowCalculator.storedConversionIsMissing`. Lo llaman `resolvedAmount`,
  `TransactionItem.chatAmount` (la regla gemela con la que Yala IA cuenta categorías, comercios y destacados: sin ella
  la app reconvertía y la IA recibía 0) y `GroupBridgeStatsAdjustment.storedPreferred`, que dejó su copia.
- **Pata real de un gasto de grupo con el convertido a 0:** se queda en la síntesis de #460 (`adjustment.isAdjusted`),
  que ya la reconvierte; es el mismo número que leen los calculadores que no pasan por `resolvedAmount`.
- **Lo que cazó la review adversarial (tres lentes), arreglado aquí:** (1) Yala IA y las anomalías decidían «pata
  ajustada» comparando importes; con «mi parte» = 0 y la pata guardada a 0 coincidían, la fila pasaba por suelta y
  `chatAmount` reconvertía el gasto entero. Ahora preguntan `adjustment.isAdjusted(_:)`. (2) Una fila sin categoría se
  clasificaba ingreso/gasto por el signo del convertido guardado; con 0 decía «ingreso» y, ya reconvertida, restaba de
  los ingresos. `TransactionClassificationLogic` lee el signo del nativo en ese caso.
- **Alcance medido:** 26 llamadas a `resolvedAmount` (Panel, Tendencias, Estadísticas, Informes, widgets, salud
  financiera, Yala IA, sugerencias) y `chatAmount` (contexto de la IA y anomalías). Suite completa en verde: ningún test
  fijaba el 0 como contrato.
- **`mcp/`:** `preferredAmount` y `chatMagnitude` (`summary.ts`) portan el criterio (`storedConversionMissing`); test en
  `logic.test.ts` y dos filas nuevas en el escenario principal del golden de paridad. **Pide deploy del conector.**
- **Tests:** `ResolvedAmountZeroConvertedTests` (la regla, hero con «≈», Tendencias, Estadísticas, Informes, Yala IA,
  sugerencias, «mi parte» = 0 en IA y anomalías, sin categoría; cada uno con su control), rojo con el criterio apagado
  (23 fallos, más `GroupBridgeUnconvertedLegTests` y el golden) y con cada corrección revertida (4).
- **Diferencia declarada del conector que se ensancha:** una fila con el convertido a 0 y una divisa que la app no
  conoce (o sin fecha) la app la suma convirtiendo como USD y el conector la deja fuera con aviso (`fx.ts`).
- **Fuera:** siete calculadores leen el convertido guardado sin pasar por `resolvedAmount` —
  card `tablero-las-tartas-y-rankings-de-estadisticas-si-985z`.
