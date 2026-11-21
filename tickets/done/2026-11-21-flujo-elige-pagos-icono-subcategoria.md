---
id: 2026-11-21-flujo-elige-pagos-icono-subcategoria
status: done
priority: medium
area: "cash-flow-plan"
created: 2026-11-21
updated: 2026-11-21
source: "pedido de Jürgen en TestFlight 2.3, 2026-11-21 07:13"
---

# Flujo de caja: en «Elige los pagos», los pagos sin logo muestran el ícono de su subcategoría

**Qué pasaba.** En Flujo de caja → límite por pagos planificados → «Elige los pagos», los pagos con logo de comercio
(Netflix, Spotify, iCloud+) se veían con su logo, pero los que no lo tienen (Alquiler, Gimnasio, Hevy Pro…) quedaban sin
nada a la izquierda: el nombre empezaba más a la izquierda que el de los pagos con logo y el divisor no casaba con ninguno.
En «Pagos de esta línea» un pago sin logo salía con un calendario gris genérico.

**Qué cambió.** Las dos vistas pintan con una pieza, `FlujoPagoIcono`: con logo, el logo; sin él, el ícono y el color de
su subcategoría (o de su categoría si la subcategoría no tiene, o el de su tipo de pago si no tiene subcategoría), con el
mismo criterio que la lista de Pagos planificados (`ScheduledPaymentsViewModel.paymentDisplayProperties(for:)`, que pasó a
ser estático sin cambiar su resultado). En la hoja, la marca de selección mide lo mismo que el ícono, así que el texto de
todas las filas arranca en la misma columna y el divisor arranca ahí.

**Cómo se verificó.**
- `YalaTests/FlujoElegirPagosIcono/` (7 casos): logo → logo; sin logo → subcategoría; subcategoría sin ícono →
  categoría; sin subcategoría → el de su tipo; mismo resultado que la lista de Pagos; y el cableado de las dos vistas.
- Capturas antes/después en el simulador con `FlujoLimitesPagosYMonedaCapturasUITests` (seed `realista`, tema claro).

**Fuera.** La línea de tiempo de Pagos planificados sigue sin ícono cuando no hay logo, a propósito (decisión del
2026-11-18: su ícono es el círculo del día). La copia del criterio en `WidgetDataCache` no se tocó.
