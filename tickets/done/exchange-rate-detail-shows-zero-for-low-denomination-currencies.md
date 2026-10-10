---
id: exchange-rate-detail-shows-zero-for-low-denomination-currencies
status: done
priority: medium
area: "currency, ui"
created: 2026-09-08
updated: 2026-10-09
source: hallazgo de camino en chat-assistant-plants-exchange-rate-one (review adversarial, 2026-09-08)
---

# El detalle de la transacción enseña «0,0000» como tipo de cambio

## Qué ve el usuario

Registra un gasto de 500.000 dongs vietnamitas con la moneda preferida en dólares. Abre el detalle de
esa transacción y el tipo de cambio dice **«0,0000»**.

No es un cero redondeado a efectos de mostrar: es el número entero de la conversión desapareciendo.
El monto convertido de al lado sale bien; solo la tasa se pierde.

## Lo medido (2026-09-08, este árbol)

`TransactionDetailSheet` formatea la tasa con cuatro decimales fijos:

```swift
Text(L10n.Transaction.exchangeRateShort(String(format: "%.4f", transaction.exchangeRate)))
```

Y la tasa se guarda en la dirección «preferida por unidad de divisa nativa», que para divisas de
denominación baja cae por debajo de esa resolución:

| par | tasa real | `%.4f` |
|---|---|---|
| VND → USD | 0,0000408163 | **0,0000** |
| VND → EUR | 0,0000376 | **0,0000** |
| IDR → USD | 0,0000632911 | 0,0001 |
| KRW → USD | 0,0007407407 | 0,0007 |

Las cuatro divisas están en la tabla de la app (`CurrencyCode`: VND, IDR, KRW, JPY, KWD…), así que el
caso es alcanzable sin nada raro.

## Es preexistente y general, no del chat

Cualquier ruta que derive la tasa —crear desde el formulario, importar CSV, aprobar un borrador del
Inbox— ya guardaba estos valores y ya mostraba «0,0000». Se destapó revisando
`chat-assistant-plants-exchange-rate-one`, que añade la ruta del chat al conjunto afectado: **esa ruta
pasó de enseñar «1,0000» (falso) a enseñar «0,0000» (verdadero pero ilegible)**. Las dos están mal
para el usuario; el ticket de la tasa arregla el dato, éste arregla lo que se ve.

## Criterio de hecho (AC)

- [ ] El tipo de cambio se lee para cualquier par de divisas de la app, incluidas las de denominación
      baja. Decimales significativos en vez de cuatro fijos, o invertir la presentación («1 USD =
      24.500 VND»), que suele ser además como la gente lee un tipo de cambio.
- [ ] Si se invierte la presentación, comprobar que no se rompe el caso normal (PEN→USD y similares).
- [ ] Buscar el patrón: `String(format: "%.4f"` y sus primos sobre tasas en otras pantallas —el chip
      del formulario de transacción es candidato.

## Hecho (2026-10-09)

- Un solo formateador de tasas, `ExchangeRateDisplayFormatter` (`Yala/App/Logic/`). Tasa ≥ 1: de 2 a 4
  decimales. Tasa < 1: los decimales que den 4 cifras significativas. Separadores del idioma, los mismos
  que los importes. VND→USD pasa de «0,0000» a «0,00004082»; PEN→USD sigue «0,2667».
- Lo usan el detalle de la transacción, el widget de tipos de cambio del Panel (chips, tooltip, eje y
  etiquetas), la hoja de ganancia cambiaria, las dos pantallas de Ajustes de divisas y el chip «TC:» del
  formulario de nuevo registro (el candidato que nombraba este ticket).
- **No se invierte la presentación.** Con las capturas delante, «TC: 0,00003861» se lee bien en la fila del
  detalle y no abre ninguna decisión de UI. Si se quisiera «1 € = 25.900 ₫» en algún par, queda como
  propuesta (A: dejar así, recomendado · B: invertir solo cuando la tasa < 0,01), no aplicada.
- **`TransferAmountInputView` no se toca.** Allí la tasa es un campo editable que se vuelve a parsear y ya
  se invierte cuando es menor que 1, así que nunca sale «0,0000». Cambiar su formato (separador de miles,
  coma) arriesga la entrada y no hay test que fije el parseo en es y en; sigue con `%.4f` sin localizar.
- Tests: `ExchangeRateDisplayFormatterTests` (VND, IDR, KRW, JPY, KWD y PEN contra USD en es y en, todos
  los pares de la tabla legibles a < 0,1 %) + `ExchangeRateDisplayFormatterWiringTests` (las seis
  pantallas). Control rojo: con el formateador vuelto a `%.4f`, caen.
- Capturas en el simulador (seed `realista` + cuenta en VND): gasto en VND con preferida EUR: antes «TC: 0.0000», después «TC: 0,00003861»; widget: antes «3.5500», después «3,55».
