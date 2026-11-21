---
id: 2026-11-20-nuevo-registro-b1-en-bandeja-y-grupos
status: done
priority: high
area: "registro"
created: 2026-11-20
updated: 2026-11-21
source: "encargo de Jürgen del 20-nov (19:00 Lima), antes del TestFlight de la 2.3: llevar el rediseño de Nuevo registro a la aprobación de la Bandeja, al nuevo gasto de Grupos y a las demás pantallas de registro"
---

# La hoja B1 de Nuevo registro en todas las pantallas de registro

Que la aprobación de un borrador de la Bandeja, Nuevo gasto de Grupos y el resto de pantallas de registro se vean y se
comporten como la hoja B1 de Nuevo registro: la cápsula de moneda junto al monto, la subcategoría bajo el monto con
«● Categoría · ● Necesidad ▾», la fila de abajo en una línea (Hoy · Cuenta · #) y los mismos colores. Más los tres
ajustes de Jürgen del 20-nov sobre la propia B1.

## Qué se hizo

- **Nuevo registro** (y con él Editar y Duplicar): fuera la línea «Ahora en dólares (USD)…» (VoiceOver sigue oyendo el
  cambio), el tipo de cambio en cápsula glass (también en la transferencia) y el título-menú y «···» en primary.
- **Aprobación de la Bandeja**: el título dice el tipo («Editar gasto ▾») y abre Gasto | Ingreso, sin el segmentado;
  fecha, cuenta y «#» en una línea; la subcategoría bajo el monto; la cápsula de moneda elige la línea de una tarjeta con
  varias monedas (antes, pastillas PEN · USD); el «#» lleva un punto si Yala IA creó alguna de sus etiquetas. Origen,
  texto leído y Aprobar / Dejar para después se quedan.
- **Nuevo gasto de Grupos**: «Hoy · Cuenta» en una línea abajo y la subcategoría bajo el monto con «● Categoría».
  Grupo, «Pagado por», reparto y la línea de lo que sale se quedan.
- **Borradores de grupo en la Bandeja** (las cinco hojas, por el andamio común): descripción y monto como la B1, la
  categoría con su puntito o la subcategoría por elegir bajo el monto, y la fecha con la cuenta o «Partir» en una línea.
- **Pago entre miembros**: la nota con el estilo de la descripción, el monto con la cápsula y «Hoy · Cuenta» en una
  línea; «Hoy» abre la hoja de fecha de Nuevo registro.
- **Editor de favorito**: descripción, monto con cápsula, subcategoría bajo el monto con su necesidad y «Cuenta · #» (u
  «Origen · Destino») en una línea. Conserva su selector de tipo y su «Guardar» arriba.
- Se retiraron las piezas que quedaron sin uso: la pastilla grande de fecha como botón, los chips de categoría de la
  aprobación, la pastilla de etiqueta con ✕, las pastillas de línea de tarjeta y el chip de necesidad suelto.

## Cómo se probó

- XCUITest en el iPhone 17 Pro: `RegistroUnificadoUITests` (Nuevo registro, aprobación ×2, Grupos),
  `RegistroB1OtrasPantallasUITests` (favorito, pago, borrador de grupo) y los dos casos M1 de `FormClarity23UITests`.
- Unit: `RegistroB1PantallasWiringTests` (fila de una línea, cápsula, línea de categoría y los tres ajustes) y
  `RegistroUnificadoWiringTests` al día.
- Capturas antes y después con `RegistroB1PantallasCapturasUITests` (17 Pro y SE, claro y oscuro, soles y dólares).

## Qué quedó fuera

Pantallas que también eligen cuenta o categoría pero no son la hoja de registro: la hoja de una línea de «Tu parte»,
la tarjeta y los «Detalles» de un borrador del chat, los guiados del chat, el asistente de favorito, «Guardar como
favorito», editar en lote, las acciones en lote de la Bandeja y el editor de pago planificado.
