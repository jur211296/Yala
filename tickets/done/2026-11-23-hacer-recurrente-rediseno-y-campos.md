---
id: 2026-11-23-hacer-recurrente-rediseno-y-campos
status: done
priority: medium
area: "transactions, scheduled-payments"
created: 2026-11-23
updated: 2026-11-24
source: "pruebas de Yala 2.3 en el iPhone (Jürgen, 23-nov)"
---

# «Hacer recurrente» desde un registro: rediseño de la hoja y copia completa de campos

Jürgen, probando 2.3: la hoja «Hacer recurrente» que sale de Nuevo gasto / Editar gasto («Cada semana, el lunes»,
«Cada mes, el día 23»…) se veía simple —cuatro filas oscuras planas— y su fondo de cristal dejaba ver los botones violeta
y azul del formulario de atrás. Y no tenía claro que las opciones rápidas llevaran todos los campos del registro.

## Hecho cuando

- La hoja tiene fondo sólido del tema en oscuro y en claro, enseña el registro que se programa y las frecuencias en una
  tarjeta con personalidad.
- La opción rápida y «Más opciones…» copian todo lo del registro, con tests.

## Resolución (2026-11-24)

- **Hoja** (`RecurringQuickSheet`): fondo `.subtle` también a media altura (excepción escrita en `swiftui-ds.md`);
  arriba, el registro como una fila de Registros (icono de la categoría, nombre, monto, cuenta · categoría › subcategoría,
  etiquetas); las tres frecuencias en una tarjeta, cada una con una mini hoja de calendario con su ancla («LUN», «23»,
  «NOV 23»); «Más opciones…» aparte, con «Fecha de fin, avisos y monto variable» debajo (texto nuevo, 16 idiomas).
- **Campos**: una sola fuente, `RecurringFromRecordService.FormRecord`, para la opción rápida (`createQuickPayment`) y
  para «Más opciones…» (`moreOptionsPrefill`). Copian monto, divisa del importe, descripción, cuenta, subcategoría,
  etiquetas, tipo, necesidad y fecha (ancla del día). Dos huecos corregidos: «Más opciones…» sin descripción abría el
  editor sin nombre (ahora, la subcategoría), y la próxima fecha tras guardar avanzaba una sola vez (un registro de
  mañana dejaba mañana un borrador duplicado); ahora usa `linkAsFirstPayment`, la regla de un registro guardado.
- **Solo en «Más opciones…»**: fecha de fin, avisos (días antes), monto variable, suscripción y logo, y pago compartido
  con un grupo.
- **No se copia, a propósito**: el reparto de «Tu parte» de la calculadora personal (el pago guarda tu parte).
- Tests: `YalaTests/HacerRecurrenteDiseno/HacerRecurrenteCamposTests` y
  `YalaUITests/HacerRecurrenteDiseno/HacerRecurrenteDisenoUITests` (capturas en oscuro y claro).
