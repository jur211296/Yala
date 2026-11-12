---
id: records-calendar-folds-to-the-chosen-week
status: done
priority: medium
area: "records, calendar, ipad"
created: 2026-11-11
updated: 2026-11-11
card: tablero-2-3-calendario-de-registros-la-semana-a-rjsz
source: "revisión por vistas 2.3 · Registros (ficha 31), decisiones 19, 66 y 67 del 9-nov"
---

# Calendario de Registros: la semana del día a la vista, también en el iPad

Tres hallazgos de la revisión de Registros (`docs/ux/revision-vistas-2.3/31-registros/`), decididos por Jürgen el 9-nov:

1. Al tocar un día del calendario solo cambiaba la celda: el resumen y las filas del día quedaban debajo del mes, fuera
   de la pantalla. Opción C2: el mes se pliega a la semana del día elegido y su lista queda debajo, a la vista. C3
   (moneda en la celda) no.
2. En el iPad el calendario se apretaba en la columna de la lista (375-480 pt) con la columna de detalle vacía al lado.
3. En el iPad el título de la columna salía cortado («Registr…») junto a «Seleccionar», «···» y el avatar.

## Hecho cuando

En el iPhone el mes se pliega a la semana del día tocado y su lista queda debajo; en el iPad el calendario y el título
de la columna se leen enteros. Un test por punto, rojo sin el arreglo.

## Resolución (2026-11-11)

- **C2.** Con un día elegido el calendario enseña solo su semana, con «13–19 oct 2026 ▾» en el sitio del mes; tocarla
  (o el día otra vez) suelta el día y vuelve el mes. La página sube hasta el calendario para que la semana y la lista
  del día queden a la vista también con texto grande. Plegado no se cambia de mes deslizando. Pista de VoiceOver nueva
  («Muestra el mes entero») en los 16 idiomas.
- **iPad, calendario.** Con la vista calendario la página de Registros va en una sola columna, como en el iPhone, y su
  contenido a 700 pt (ancho legible); lo abierto, en la hoja de siempre. Con la lista vuelve el split. El modo, el día y
  el mes del calendario viven en `RecordsViewModel` para sobrevivir al plegado del split.
- **iPad, título.** La columna de la lista no admite título grande (medido: `.large` no cambia nada ahí). En esa columna «Seleccionar» va con su icono y el título cabe entero; el botón sigue a la vista y en «···».
- Tests: `YalaUITests/RecordsCalendarWeek23UITests` (un caso por punto; los del iPad, en un iPad Pro 13) y
  `YalaTests/RecordsCalendarFoldTests`.
