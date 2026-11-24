---
id: 2026-11-24-pagos-planificados-chips-vista-y-pie
status: done
priority: medium
area: "scheduled-payments"
created: 2026-11-24
updated: 2026-11-24
source: "QA de Jürgen en su iPhone, 2.3 (24-nov, 06:08-06:15 Lima)"
---

# Pagos planificados: chips de vista con nombre, ícono cuando no hay logo y el enlace del pie pegado al final

## Qué cambia para quien usa la app

- Debajo del mes, en vez de tres botones redondos solo con ícono a la derecha, hay tres chips con nombre desde la
  izquierda: «Lista», «Línea de tiempo» y «Calendario». Con texto grande o en idiomas largos se desplazan en
  horizontal. La vista elegida se recuerda al salir y volver (antes se perdía).
- En la línea de tiempo y en el calendario, los pagos sin logo de comercio llevan el ícono de su subcategoría (o de
  su categoría) en el mismo sitio y tamaño que el logo. En el calendario, la marca del día es ese ícono con el aro del
  color de estado, dos por celda.
- El enlace del pie queda a una sección de distancia del final de la lista, sin los ~100 pt vacíos de antes, y dice
  «Ver más pagos que se repiten» (16 idiomas). El sitio del «+» flotante va debajo del enlace.

## Por qué

El hueco salía de un margen de 100 pt «para el botón flotante» que la lista ponía ENTRE ella y el enlace del pie.

## Pruebas

`YalaTests/PagosPlanificadosChipsVista/` (orden y nombre de las vistas, vista recordada, orden logo → subcategoría →
categoría → tipo, cableado). Capturas antes/después en claro, oscuro, texto grande y girado con
`YalaUITests/PagosPlanificadosChipsVista/PagosChipsVistaCapturasUITests` (a mano).
