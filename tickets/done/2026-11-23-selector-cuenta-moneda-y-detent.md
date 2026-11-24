---
id: 2026-11-23-selector-cuenta-moneda-y-detent
status: done
priority: medium
area: "registro, bandeja"
created: 2026-11-23
updated: 2026-11-23
source: "Jürgen, pruebas de Yala 2.3 en el iPhone (23-nov)"
---

# El selector de cuenta enseña solo las cuentas de la moneda del monto, y en la Bandeja abre a media altura

Al abrir «Cuenta» desde Nuevo registro o desde un borrador de la Bandeja salían todas las cuentas de todas las monedas
(BCP Crédito PEN, BCP Crédito USD…), sin importar la moneda elegida junto al monto. En la Bandeja, además, la hoja abría
a pantalla completa; en Nuevo registro, a media altura.

## Hecho cuando

- En un gasto o ingreso, el selector enseña solo las cuentas de la moneda junto al monto, en Nuevo registro y en la
  Bandeja. Para pasar a otra moneda, la cápsula «S/ ▾», que elige la cuenta (la línea de su tarjeta o la primera de esa
  moneda).
- Sin cuentas en esa moneda, la hoja no queda vacía: enseña todas con la línea «No tienes cuentas en USD. Estas son todas
  tus cuentas.».
- Transferencias y gasto de grupo, como estaban.
- En la Bandeja el selector abre a media altura y se estira a grande, como en Nuevo registro.

## Resolución (2026-11-23)

Hecho.

- `AccountSelectorSheet` gana `currencyScope` (filtro por moneda con respaldo) y la regla vive en
  `AccountSelectorCurrencyScope`.
- Nuevo registro le pasa la moneda del monto (`amountCurrencyCode`). Su cápsula de moneda abre también sin cuenta
  elegida: sin eso, con el filtro no había forma de llegar a una cuenta en otra moneda.
- La Bandeja le pasa la moneda del borrador y `sizing: .mediumFirst`. Su cápsula pasa a ofrecer todas las monedas con
  cuenta (`AmountCurrencyMenuLogic`, la de Nuevo registro); antes solo abría las líneas de una tarjeta.
- Pruebas: `YalaTests/SelectorCuentaMoneda/` (filtro, respaldo, cambio de moneda y cableado). Tres XCUITest que elegían la
  cuenta en dólares desde el selector pasan por la cápsula (`FormClarity23UITests`, `TransactionFormDecided02BUITests`,
  `AccountCardPickersUITests`; el anidado tarjeta-línea se mira ahora en el origen de una transferencia).
- El caso de la card y1z6 (tocar la tarjeta desde su línea en dólares vuelve a la principal) ya no cabe en un gasto: en
  dólares la tarjeta en soles no sale. Se vuelve con la cápsula; en transferencias sigue igual.
