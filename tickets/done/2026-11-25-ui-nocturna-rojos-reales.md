---
id: 2026-11-25-ui-nocturna-rojos-reales
status: done
priority: high
area: "qa, ci, registros, cuentas"
created: 2026-11-25
updated: 2026-11-25
source: "Análisis de las tandas de UI en rojo del 25-nov (PR #1173); Jürgen pidió encolar los lotes a las 7:22 (Lima)"
---

# UI nocturna: los tres rojos reales (Límite de tarjeta, Hacer recurrente y Quitar repetidos)

Tres pruebas de interfaz en rojo en la nocturna. El análisis las marcó como reales o probables reales: podía haber
un bug de la app detrás. Las tres resultaron ser fallos de la prueba, no de la app.

## Causas

- **Límite de tarjeta** (`LimiteTarjetaUITests.test_ponerCambiarYBorrarElLimite…`, rojo 3/3 las nocturnas del 23, 24
  y 25-nov). El campo del límite reagrupa el número a cada cambio («8,00» → «800») y reescribe el texto. La prueba
  borraba con una ráfaga de teclas en una sola llamada a `typeText`, y en el runner del CI las teclas que llegaban
  mientras tanto se perdían contra esa reescritura: los tres intentos del 25-nov dejaron «8», «800» y «80». En la
  Mini pasaba (la ráfaga llegaba antes que la reescritura). Una persona no borra a esa velocidad: no es un bug de la
  app.
- **Hacer recurrente** (`RecurrenteDesdeRegistroUITests`, detalle y menú del registro, rojo 3/3 el 25-nov) y
  **Quitar repetidos** (`RecordsLote8BUITests.test_duplicates_removeRepeated…`, rojo 3/3 el 25-nov). Las dos usaban
  «la primera fila» de Registros. La semilla `minimal` siembra una transferencia los días 10 y 25, y esos días encabeza
  la lista. Una transferencia no ofrece «Hacer recurrente» (un pago planificado es gasto o ingreso) y el modo
  duplicados deja fuera las transferencias, así que la copia no formaba grupo. La tanda corrió el 25-nov de madrugada
  (Lima); el 24 la primera fila era un gasto. No hubo cambio de la app detrás: la bisección no hizo falta.

## Arreglo

- Límite: una tecla de borrar por llamada, hasta que el campo quede vacío (XCUITest espera a que la app quede quieta
  entre llamadas).
- Recurrente y Quitar repetidos: eligen el primer **gasto** de la lista (por la etiqueta de accesibilidad, que lleva
  el tipo), no la primera fila.

## Verificación

- Reproducido en local el 25-nov (día 25): Recurrente ×2 y Quitar repetidos en rojo con el mismo mensaje del CI; con
  el arreglo, los cuatro casos en verde. El Límite pasaba también sin arreglo en la Mini: su causa se midió en el log
  de la nocturna (tres restos distintos en tres intentos).
- Gate: build 2/2, interfaz de las tres clases completas (10 casos: 9 verdes y el de capturas, que se salta sin su
  variable), centinela solo, índice 29/29.

## Fuera

- `RecordsLote8UITests.test_changeSubcategory…` («El menú no ofrece cambiar la categoría», noches del 10, 13 y
  24/25-nov) tiene muy probablemente la misma causa (la transferencia de los días 10 y 25 no ofrece cambiar la
  categoría). Es de otro lote (intermitentes): el hallazgo quedó en la nota de su card.
- Riesgo residual: un domingo que coincida con un día de factura de la semilla y sin gasto diario podría dejar arriba
  un pago ya vinculado a un recurrente. Probabilidad baja; si sale, el mensaje lo dirá igual («no ofrece Recurrente»).
