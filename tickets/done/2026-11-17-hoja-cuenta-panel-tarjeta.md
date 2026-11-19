---
id: 2026-11-17-hoja-cuenta-panel-tarjeta
status: done
priority: medium
area: "panel, cuentas"
created: 2026-11-17
updated: 2026-11-18
source: "Jürgen, 17-nov-2026 (20:56 Lima), con captura y referencia"
---

# La hoja de una cuenta se ve plana

Al tocar una cuenta en el Panel se abría una hoja con un ícono chico genérico, «Tarjeta de crédito · PEN · USD», los
montos por divisa, el selector PEN/USD, «Así se forma tu saldo» y «Filtrar por esta cuenta». Funcionaba, pero se veía
plana. Referencia que le gusta: `docs/design/referencias/2026-11-17-hoja-cuenta-tarjeta-referencia.jpg` (tarjeta grande
arriba, el monto debajo, uso de la línea y fecha de pago con su acción).

## Hecho cuando

Arriba sale la tarjeta de la cuenta tal como la personalizó la persona, grande y con una entrada animada suave; debajo, el
monto grande con su rótulo; en tarjetas de crédito, el estado de cuenta con fecha de pago y de corte si Yala las tiene. Lo
que ya aportaba la hoja sigue, más ordenado y debajo. X y Editar como antes.

## Resolución (2026-11-18)

Variante A «Wallet» de tres (A tarjeta grande centrada y monto debajo; B la tarjeta del carrusel entera, con el saldo
dentro; C tarjeta pequeña con el monto al lado).

- **Tarjeta**: la cara de la tarjeta del carrusel sin el saldo (ícono, nombre, chip, tipo · divisas, «•••• 1234»), con el
  diseño que eligió la persona. Ancho tope 280 pt en proporción de tarjeta bancaria; con letra de accesibilidad ocupa todo
  el ancho y crece. Entra subiendo con un resorte; con Reducir movimiento, sin animación.
- **Monto**: rótulo (Por pagar, Saldo) y cifra grande centrados; con varias divisas, una por línea y el total ≈.
- **Tarjeta de crédito con corte**: lo facturado frente a lo por facturar (con barra cuando hay una sola divisa), «Paga
  antes del…» y «Próximo corte: …».
- **Tarjeta sin día de corte**: «Añade tu día de corte y de pago» con «Añadir fechas», que abre Editar.
- **Sin barra de «% usado»**: Yala no guarda el límite de la tarjeta. Añadirlo toca el modelo de datos: queda fuera.
- **Sin botón «Pagar»**: Yala no tiene ese flujo.
- Lo demás (selector de divisa, «Así se forma tu saldo», «Filtrar por esta cuenta», gráficas y registros) sin cambios.

Código en `Yala/App/Views/Panel/Sheets/HojaCuentaTarjeta/`; textos en `HojaCuentaTarjeta.strings` (16 idiomas). Pruebas:
`YalaTests/HojaCuentaTarjeta/`, `YalaUITests/HojaCuentaTarjeta/` y `CreditCardStatementUITests` (que sigue leyendo
`cc_statement_billed`/`unbilled` en el bloque nuevo).
