---
id: 2026-11-22-limite-tarjeta-uso-linea-dos-monedas
status: done
priority: medium
area: cuentas
created: 2026-11-22
updated: 2026-11-22
source: decisión de Jürgen del 22-nov 15:05 (lote registrado en docs/DECISIONS.md, «uso de línea en tarjetas con dos monedas»)
qa-status: passed
---
# El «uso de línea» también en las tarjetas con dos monedas

Hasta ahora, la hoja de una tarjeta de crédito con límite ocultaba «X % usado · N disponible de M» si la tarjeta tenía
deuda en dos monedas (ticket `tickets/qa/2026-11-22-cuenta-limite-tarjeta-campo-sincronizado.md`).

## Hecho

- **Hoja de la tarjeta:** con límite y dos monedas, la línea sale. Lo usado se mide en la divisa del límite (la de la
  principal): lo que debes en la otra se convierte con el último tipo de cambio guardado, el mismo que usa el «Total ≈»
  de la cabecera, así que las dos cifras cuadran.
- **Nota bajo la línea:** «Aprox.: incluye lo que debes en USD, al último tipo de cambio.» Solo cuando de verdad se
  convirtió algo (una divisa con deuda cero o saldo a favor no se convierte ni se nombra).
- **Sin tipo de cambio real** para esa pareja (solo la tabla estática de reserva), la línea no sale, como antes.
- **Saldo a favor** en una divisa cuenta como cero y no descuenta de la otra: son dos deudas, como en el resto de la hoja.
- Sin límite, nada. Una sola divisa, igual que antes (mismo cálculo, sin nota).
- Textos en los 16 `LimiteTarjeta.strings`; español neutro en es, es-419 y es-ES.
- Semilla `-uitest-seed tarjeta-limite-dos-monedas`: la tarjeta con corte, en soles y dólares, con límite de 5.000 S/.

## Verificado

- `YalaTests/LimiteTarjetaDosMonedas/`: dos monedas con cambio, sin cambio, saldo a favor en una de ellas, pasarse del
  límite, límite en dólares, sin límite, una sola divisa; la nota en los 16 idiomas.
- Capturas antes/después en iPhone 17 Pro (claro y oscuro) e iPad Pro 13": 1.626,50 S/ + 80 USD ≈ 1.919,30 S/ →
  «38 % usado · S/ 3,080.70 disponible de S/ 5,000.00» con la nota.
