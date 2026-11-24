---
id: 2026-11-24-aviso-de-ejemplo-en-la-moneda-de-la-region
status: done
priority: low
area: "bank-notices, captura-atajo-banco-parte-2"
created: 2026-11-24
updated: 2026-11-24
source: "«Fuera, a propósito» del cierre de Avisos del banco (tickets/qa/2026-11-23-avisos-del-banco-claridad-y-region.md); Jürgen pidió arreglarlo el 24-nov"
---

# El aviso de ejemplo de «Tu banco o app» va en la moneda que toca

## Qué pasaba

En Ajustes › Avisos del banco › «Tu banco o app», el aviso de ejemplo decía «Pagaste S/ 25.00 en STARBUCKS LARCOMAR»
también en Estados Unidos o España: soles y un centro comercial de Lima para quien no vive en Perú.

## Qué cambió

- Con los bancos de Perú (región Perú o el sol como moneda principal), el ejemplo de siempre, en soles.
- Fuera de Perú, «Pagaste <moneda> 25 en CAFE CENTRAL con tu tarjeta ****3456»: la moneda principal de Yala (si no hay,
  la de la región del iPhone; si no, USD), con los decimales de esa moneda («USD 25.00», «JPY 25»). Código ISO y no
  símbolo, porque «$» lo comparten USD, MXN, COP y otras.
- El criterio vive en `BankNoticeChoiceLogic.sampleText(for:regionCode:mainCurrencyCode:)`, junto al que ya decide qué
  bancos se ofrecen. Los bancos de Perú conservan sus ejemplos.

## Pruebas

- `YalaTests/AvisosCorreosBancoRestos/AvisosCorreosBancoRestosTests`: Perú, sol fuera de Perú, Perú con otra moneda,
  EE. UU., EUR/MXN/JPY/GBP, región sin moneda principal, bancos de Perú intactos y el cableado de la pantalla.
- `YalaUITests/AvisosCorreosBancoRestos/AvisoEjemploRegionUITests`: EE. UU. con USD y Perú con PEN, en tema claro y
  oscuro. Sin el arreglo, el caso de EE. UU. cae con «S/ 25.00 en STARBUCKS LARCOMAR» (medido).

## Fuera

- El texto del ejemplo sigue en español en los 16 idiomas, como antes.
