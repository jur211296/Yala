---
id: 2026-11-19-nuevo-registro-b-realista-maquetas
status: backlog
area: transactions
created: 2026-11-19
updated: 2026-11-19
source: ajustes de Jürgen a la variante B (2026-11-19, 18:11 Lima) y sesión de maquetas realistas del mismo día
---

# Nuevo registro, B ajustada: hoja y pantalla de éxito

Segunda ronda de `2026-11-19-nuevo-registro-limpio-maquetas`. Jürgen eligió la **B** como base. Los cinco puntos de su
idea (título-menú, favoritos de icono, fila con Hoy, moneda junto al monto, «···») siguen vigentes; esta ficha recoge sus
seis ajustes y especifica la opción recomendada.

## Maquetas

Artifact: **https://claude.ai/artifact/8Se8XnuPMGBg1gHsnC7SRD** — la hoja (hoy · B1 · B2) en diez escenarios y la pantalla de éxito
(hoy · C · minimalista) en cinco, claro y oscuro, iPhone 17 Pro y SE, con el inventario completo. Al pie, «Tu decisión»
guarda lo elegido en la base del artifact (colección `decision`, documento `jurgen`). **Antes de implementar, leer esa
decisión**: lo de abajo es la recomendación, no lo elegido.

Las maquetas son SwiftUI dentro de la app (componentes de 2.3, datos de `-uitest-seed minimal`), capturadas en el
simulador. El arnés no se mergea: vive como parche en
`~/Claude/entregas/2026-11-19-nuevo-registro-b-realista-maquetas/arnes-maquetas-nuevo-registro.patch` (lanzar con
`-mockupNR <variante>:<escenario>`; variantes `hoy`, `b1`, `b2`, `exito-hoy`, `exito-c`, `exito-min`).

## Los seis ajustes de Jürgen

1. Con teclado, descripción y monto suben y dejan aire sobre el teclado.
2. Ningún chip recorta su texto. La subcategoría sube bajo el monto; al elegirla salen debajo su categoría y su necesidad.
   La fila de abajo es Hoy · Cuenta · Etiqueta.
3. Hoy siempre primero.
4. Categoría y necesidad no van como chips rellenos: texto informativo, o con un puntito de color.
5. En dólares, el estimado en soles va pequeño al lado y abajo del monto grande; el tipo de cambio debajo, sin doble fila.
6. Pantalla de éxito: la de la C, o un rediseño minimalista recomendado.

## Especificación de la recomendada (hoja B1 + éxito minimalista)

### Barra de arriba
- Como la ronda 1: X a la izquierda, título-menú en el centro («Nuevo gasto ▾»), «···» a la derecha del tamaño de la X.
- Al editar, «Editar gasto/ingreso/transferencia» sin menú; tras Duplicar, «Duplicar …». En «solo gastos» y en lo que
  viene de un grupo, el título no abre menú.
- «···» lleva un punto cuando Mi parte o Recurrente están activos.

### Favoritos
- Rótulo «Favoritos», chips de solo icono de 40 pt (icono y color de su categoría; en transferencia, de la cuenta de
  destino) y «Ver todos ›». Al tocar uno se estira con su nombre (ronda 1).
- **Con el teclado abierto se pliegan** y vuelven al cerrarlo: es lo que da aire al ajuste 1. Decidido sin consultar; el
  artifact pregunta si los quiere siempre.

### Centro
- Descripción, pista de atajos, sugerencias y menciones como hoy.
- Pregunta del monto y, en la misma línea de base: cápsula de moneda «S/ ▾» a la izquierda, monto grande y, si la moneda
  no es la preferida, el estimado «≈ S/ 91.50» en `subheadline` secundario a la derecha (ajuste 5). Si no cabe a lo ancho
  (texto grande, monto de muchas cifras), el estimado baja bajo el monto.
- Debajo, la cápsula del tipo de cambio de siempre (`ExchangeRateCapsule`, rótulo dentro): una sola fila.
- Debajo, el chip de **subcategoría** (`SelectionChip`, relleno de su color, como hoy en la fila).
- Elegida la subcategoría, una línea de texto `subheadline` secundario: «● Alimentación · ● Opcional ▾», con un punto de
  8 pt del color de la categoría y otro del de la necesidad (B1). La necesidad sigue siendo un botón que abre
  `NeedSelectorSheet`. En ingresos, solo la categoría. El icono de pago programado va al final de la línea.
- Con Mi parte o Recurrente activos, debajo: «% Tu parte: S/ 625.00 de S/ 1,250.00» y «↻ Cada mes».
- «Convertir a gasto compartido» sigue debajo al editar.
- Con teclado, el bloque central se reparte hacia arriba (más aire abajo que arriba).

### Fila de abajo
- `RecordSelectorChips` centrada: **Hoy · Cuenta · #** (transferencia: Hoy · Origen · Destino). Nunca recorta: si no
  cabe, baja a otra línea en ese orden.
- «Hoy» se pinta como valor puesto (texto principal sobre la cápsula, sin relleno de color).
- «#» es un chip de solo icono; con etiquetas, relleno con el color de la primera y su número («# 2»). Las pastillas por
  etiqueta con ✕ (L2-19) pasan a la hoja de etiquetas. (B2 las deja en la fila, como hoy.)
- Una tarjeta con varias monedas pierde sus pastillas PEN/USD: la cápsula de moneda elige la línea.

### Guardar
- «Agregar otro» (`plus`, cápsula `.thCard`) a la izquierda y «Guardar S/ 45.50» (primario) a la derecha, lado a lado. Si
  no caben, «Agregar otro» queda como «+» con su etiqueta. Nunca uno debajo del otro.
- «Para guardar, falta…» encima, como hoy.
- Con teclado, en la barra sobre él: la fila Hoy · Cuenta · # y debajo la pareja de botones.

### Menú «···»
- Mi parte (solo gasto), Guardar como favorito, Hacer recurrente (no en transferencia ni en lo de un grupo), cada uno con
  su estado debajo. Al editar, separación y Duplicar y Eliminar (rojo).

### Pantalla de éxito (minimalista)
- «Editar» arriba a la derecha.
- Check pequeño en el color del tipo junto a «Gasto guardado» / «Ingreso guardado» / «Transferencia guardada».
- Monto grande (`AmountText`, `heroAmount`), y la transferencia entre monedas como hoy.
- Tarjeta sin rótulos (VoiceOver los lee): subcategoría con su categoría al lado, necesidad con su color, cuenta (u origen
  y destino), fecha, descripción y etiquetas. La fila «Tipo» sale: lo dice el título.
- Dos botones iguales en una fila: «★ Favorito» y «↻ Recurrente» (en transferencia solo Favorito). Abren las hojas de hoy.
- Abajo, lado a lado: «Registrar otro» (secundario) y «Aceptar» (primario).
- Oferta de prueba y permiso de avisos, como hoy.

## Alternativas (por si Jürgen elige otra en el artifact)

| Punto | Recomendada | Alternativa |
|---|---|---|
| Categoría y necesidad | B1: texto con puntito | B2: solo texto |
| Etiquetas | B1: «#» con número | B2: «# Etiquetas» y pastillas con ✕ como hoy |
| Éxito | Minimalista | La de la C: la de hoy (círculo, «¡Listo!», tarjeta con rótulos) + dos filas explicadas «Guardar como favorito · Repítelo con un toque la próxima vez» y «Hacer recurrente · Yala lo apunta solo cada mes», con botones lado a lado |
| Favoritos con teclado | Se pliegan | Siempre a la vista |

## Inventario

El inventario completo, elemento por elemento y con su marca (igual, se mueve, al menú «···», cambia de forma, nuevo),
está en el artifact. Lo que cambia de sitio o de forma:

| Elemento (hoy) | En la B ajustada |
|---|---|
| Título «Nuevo registro» | Título-menú con el tipo |
| Selector Gasto · Ingreso · Transferencia | Dentro del título-menú |
| Favoritos con nombre y monto | Solo icono; se pliegan con teclado |
| Pastilla «Hoy» sobre la descripción | Primera de la fila de abajo |
| Símbolo pegado al monto | Cápsula «S/ ▾» a la izquierda del monto |
| Pastillas PEN/USD de tarjeta con varias monedas | Las reemplaza la cápsula de moneda |
| Equivalencia «≈ S/ …» en línea propia | Pequeña, al lado y abajo del monto |
| Tipo de cambio en segunda fila | Una sola fila bajo el monto |
| Chip de subcategoría en la fila | Bajo el monto |
| Chips rellenos de categoría y necesidad | Línea de texto con puntito; necesidad editable |
| Mi parte, Favorito, Recurrente (círculos) | Menú «···» (+ Favorito y Recurrente en el éxito) |
| Duplicar, Eliminar (al editar) | Menú «···» |
| Chip de cuenta / origen y destino | Fila Hoy · Cuenta · # |
| Pastillas de etiqueta con ✕ | «#» con número (B1) |
| «Guardar» | «Guardar S/ …» con «Agregar otro» al lado |
| Barra sobre el teclado (cuenta, categoría, Guardar) | Fila Hoy · Cuenta · # + Agregar otro y Guardar |
| Éxito: «Aceptar» encima de «Registrar otro» | Lado a lado |
| Éxito: círculo grande y fila «Tipo» | Check pequeño junto al título; sin fila «Tipo» |

## Textos nuevos

Van en su tabla de traducción propia de esta entrega, no en `Localizable.strings` a mano. Suman a los de la ronda 1
(`nr.title.*`, `nr.favorites.label`, `nr.more.*`, `nr.save.withAmount`, `nr.addAnother`, `nr.saved.toast.*`).

| Clave propuesta | es |
|---|---|
| `nr.success.saved.expense` | Gasto guardado |
| `nr.success.saved.income` | Ingreso guardado |
| `nr.success.saved.transfer` | Transferencia guardada |
| `nr.success.favorite` | Favorito |
| `nr.success.recurring` | Recurrente |
| `nr.recurring.monthlyChip` | Cada mes |
| `nr.tags.a11yCount` | Etiquetas, %d puestas: %@ |
| `nr.success.c.favoriteHint` (solo si gana la C) | Repítelo con un toque la próxima vez |
| `nr.success.c.recurringHint` (solo si gana la C) | Yala lo apunta solo cada mes |

## Riesgos

- **Accesibilidad.** El título-menú se lee con «Cambiar tipo»; «···», «Más opciones»; los favoritos de icono conservan su
  nombre; «#» se lee con el número y los nombres. Zona de toque de 44 pt en los chips de 40. Desde AX1, los favoritos con
  nombre, la fila baja a varias líneas y el estimado bajo el monto. El puntito nunca va solo: el nombre va al lado.
- **Descubrimiento.** Mi parte y Recurrente quedan en «···»; los mitigan el punto en «···», las líneas «Tu parte» y «Cada
  mes» y los botones de la pantalla de éxito.
- **Siri, atajos y widgets.** Centro de Control, el widget, el atajo de Siri y ⌘N abren como gasto: sin cambio. Lo que
  llega con datos (Yala IA, Duplicar, Editar, favorito) llega con su tipo en el título. Siri y Apple Pay dejan borradores
  en la Bandeja: no pasan por esta hoja.
- **Pruebas automáticas.** Las que tocan `new_transaction_type_*`, los círculos de acciones, `new_transaction_date_chip`,
  las pastillas de etiqueta y la barra del teclado se migran en el mismo PR.
- **Guía del primer registro.** Sus anclas de fecha y categoría cambian de sitio.

## Fuera de alcance

- No cambia qué se guarda ni cómo.
- iPad, el Duo y la ventana ancha se miden al implementar (las maquetas son de iPhone).
- Nuevo gasto de Grupos no cambia.

## Cómo se sabe que está bien

- Capturas antes/después en el 17 Pro y el SE, claro y oscuro, con y sin teclado, en los diez escenarios del artifact.
- Ningún chip recorta texto con «Interbank Sueldo Soles» y «Mantenimiento y reparaciones» en el SE.
- XCUITest: tipo por el título-menú, guardar con «Guardar S/ …», «Agregar otro» deja la hoja lista, «···» › Hacer
  recurrente, Favorito y Recurrente desde la pantalla de éxito.
- VoiceOver: título-menú, «···», favoritos, línea de categoría, «#» y los dos botones del éxito se leen con nombre.
