---
id: 2026-11-17-reusar-registro-hoja-con-filtros
status: done
priority: medium
area: "planificacion, pagos-planificados, registros"
created: 2026-11-17
updated: 2026-11-17
source: "Jürgen, 17-nov 17:35 Lima, con capturas de TestFlight: «Desde un registro» queda debajo de «Nuevo pago planificado» y la hoja es una lista simple"
---

# Pagos planificados: botón «Reusar» y hoja de registros con los filtros y el buscador de Registros

## Qué pidió Jürgen

1. Un nombre corto para el botón que crea un pago planificado desde un registro: «Reusar», con su icono. Nunca un
   botón debajo del otro, tampoco en el iPhone SE ni con texto grande: si no cabe el nombre, solo el icono.
2. La hoja «Elige un registro», grande y parecida a Registros: el buscador, los filtros rápidos (Cuenta, Categoría,
   Más filtros) y las mismas filas, agrupadas por día. Tocar un registro sigue el flujo de siempre.

## Qué cambió para quien usa la app

- **«Reusar»** (icono de copiar) va al lado de «Nuevo pago planificado», en la misma fila, en todos los iPhone. Si no cabe
  con su nombre (texto de accesibilidad), queda solo el icono en un círculo de 44 pt; VoiceOver dice «Reusar» y lo que hace.
- **La hoja abre grande** y arriba trae el buscador de Registros (descripción, categoría, cuenta, etiqueta o importe) y
  los chips Cuenta · Categoría · Más filtros. Debajo, las filas de Registros (icono de color, cuenta, monto, prioridad y
  etiquetas) agrupadas por día. Con algún filtro puesto sale una ✕ para limpiarlos.
- **Los filtros son de la hoja**: elegir una cuenta para encontrar el registro no deja filtrados Registros, el Panel ni
  Estadísticas al cerrarla. Sin resultados con filtros: «Ningún registro coincide con estos filtros».
- Tocar un registro sigue igual: si hay un pago parecido, ofrece vincularlo; si no, abre el editor prellenado.

## Qué se tocó

- `ScheduledPaymentsListView.swift`: el botón «Reusar» con sus dos formas en un `ViewThatFits`, las dos en fila.
- `RecurringFromRecordSheet.swift`: la hoja nueva (`RecurringRecordPickerSheet`), los filtros propios
  (`ReusarRegistroFilters`), la lógica de qué se ve (`ReusarRegistroLogic`) y los textos (`ReusarRegistroText`).
- `ScheduledPaymentsView.swift`: la hoja con `.presentationDetents([.large])`.
- Cambio mínimo en dos componentes de Registros: `RecordsQuickFilterBar` acepta cualquier modelo
  (`RecordsQuickFilterModel`, que `RecordsViewModel` cumple tal cual) y `RecordsListSearchField` deja de ser privado.
- `ReusarRegistro.strings` en los 16 idiomas.
- Tests: `YalaTests/ReusarRegistro/ReusarRegistroTests.swift` (lógica, filtros propios, cableado con mutante del apilado,
  16 idiomas) y el XCUITest `RecurrenteDesdeRegistroUITests` (misma fila y piezas dentro de la hoja).

## Probado

- iPhone SE (simulador): botones en una fila a tamaño normal y con el texto más grande; hoja en oscuro y claro; filtro de
  cuenta, «Más filtros» y vacío con filtros; al cerrar, el Panel sin filtros.
- iPhone 17 Pro (simulador): antes y después de los botones.
- iPhone 14 (Device MCP): ver el informe de la sesión.

## Quedó fuera

- Con el texto más grande en el iPhone SE, «Nuevo pago planificado» se corta en «Nuevo pago plan…» (es el botón de
  siempre, con dos líneas como tope). No se tocó: es la pieza compartida de todas las páginas.
