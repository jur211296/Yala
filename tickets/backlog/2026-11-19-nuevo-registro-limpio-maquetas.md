---
id: 2026-11-19-nuevo-registro-limpio-maquetas
status: backlog
area: transactions
created: 2026-11-19
updated: 2026-11-19
source: idea de Jürgen del 2026-11-19 (13:03 Lima) y sesión de maquetas del mismo día
---

# Nuevo registro más limpio: título-menú, favoritos de icono, una fila y «···»

## Qué pide Jürgen

Hoy la hoja «Nuevo registro» enseña seis capas con el mismo peso antes de guardar. Su idea, base de todo lo de abajo:

1. Fuera el control segmentado. Arriba, un título-menú «Nuevo gasto ▾» que cambia a «Nuevo ingreso» o «Nueva transferencia».
2. Los favoritos se quedan, más pequeños: rótulo «Favoritos» y chips de solo icono. Al tocar uno, se estira y dice su nombre.
3. «Hoy» va en una sola fila con cuenta y categoría. Etiquetas, en esa fila y solo con su icono.
4. La moneda va al lado del monto, como en Grupos, y filtra las cuentas que salen al elegir cuenta.
5. Mi parte, Favorito y Recurrente pasan a un botón «···» arriba a la derecha, a la altura de la X. La pantalla de
   éxito ofrece convertir el registro en favorito o en recurrente.

## Maquetas

Artifact con las tres variantes interactivas, la hoja de hoy capturada en el simulador y la referencia:
https://claude.ai/artifact/Jgd7zCpGnst4SLNqVgHrtc — tipo, estado, teclado, moneda, tema y iPhone (17 Pro y SE). Al pie,
el bloque «Tu decisión» guarda la variante elegida y los puntos sueltos en la base del artifact (colección `decision`,
documento `jurgen`). **Antes de implementar, leer esa decisión**: lo de abajo es la recomendación, no lo elegido.

## Estado de partida (medido en `origin/2.3` el 2026-11-19)

- Las categorías sugeridas bajo el monto ya no están (commit `3e7d3634b`, decisión 21 de 2.3, C2).
- El tipo lo elige `TransactionTypeSelectorView` (`NewTransactionView.transactionTypeSelector`). La misma vista la usa
  `CashFlowAddLineSheet`: **no se borra**, solo deja de usarse en Nuevo registro.
- Favoritos: `FavoriteChipsRow` (icono, nombre y monto por chip, «Ver todos» al final, solo los del tipo elegido).
- Mi parte, Favorito y Recurrente: `quickActionsBar`, círculos de color de `DS.FormAction`. Al editar un registro
  guardado la barra suma Duplicar y Eliminar.
- Hoy es una pastilla aparte encima de la descripción (`RecordPillButton`, `new_transaction_date_chip`).
- Cuenta, categoría y etiquetas: `bottomChips` (`RecordSelectorChips`, baja a dos líneas si no cabe). Una tarjeta con
  varias monedas añade sus pastillas de moneda al lado de la cuenta.
- El símbolo de la moneda va pegado al monto y sigue a la cuenta (L2-16). `AccountSelectorSheet` ya acepta
  `currencyFilter`, hoy solo para un gasto de grupo (Caso A).
- Con teclado, la barra fina de encima lleva cuenta, categoría y «Guardar» (G1, decisión 20 de la revisión 2.3).
- Grupos pinta la moneda como cápsula `S/ ▾` a la izquierda del monto (`GroupExpenseFormView.currencyChip`).
- Éxito: `TransactionSuccessView` con «Editar», «¡Listo!», monto, detalle, «Aceptar» y «Registrar otro».

## Especificación de la opción recomendada (B · Referencia)

### Barra de arriba
- Izquierda: la X de siempre. Centro: título-menú con el tipo y `chevron.down`. Derecha: «···» (`ellipsis`) del mismo
  tamaño que la X (`YalaToolbarButton`).
- El título-menú es un `Menu` con tres filas: icono del tipo en su color, nombre y marca en el actual. Cambiar de tipo
  hace lo mismo que hoy el `onTypeChange` (vacía la categoría; en transferencia prepara origen y destino).
- Títulos: «Nuevo gasto», «Nuevo ingreso», «Nueva transferencia»; al editar, «Editar gasto/ingreso/transferencia»; tras
  Duplicar, «Duplicar gasto/…». En solo-gastos y en lo que viene de un grupo (solo lectura) el título no es menú.

### Favoritos
- Fila: rótulo «Favoritos» (caption, secundario) y un chip circular de 40 pt por favorito, con el icono de su categoría
  en su color, sobre `theme.card` con el borde fino y la sombra suave del contraste en claro (decisión del 19-nov,
  13:52). Al final, «Ver todos ›».
- Al tocar uno: el chip se estira a cápsula con icono y nombre, relleno con `Color.selectedFill(color)` y texto blanco;
  los demás bajan al 42 % de opacidad. Muelle `DS.Animation.selection`; con Reducir movimiento, solo fundido.
- El monto no va en el chip: se ve grande en el formulario.
- **Favoritos de transferencia**: hoy todos llevan ⇄ y con solo icono no se distinguen. Llevan el icono y el color de la
  cuenta de destino.
- Con texto de accesibilidad (AX1 en adelante), cada chip enseña siempre su nombre.

### Centro
- Descripción y pregunta del monto como hoy. Hoy (la fecha) sale de aquí: pasa a la fila.
- Monto con la cápsula de moneda a su izquierda (`S/ ▾`, el molde de Grupos). La cápsula abre un menú con las monedas en
  las que hay al menos una cuenta (o una línea de tarjeta), con cuántas cuentas tiene cada una; sin cuentas en otra
  moneda, la cápsula no abre nada y no lleva flecha.
- Elegir moneda: si la cuenta elegida no la tiene, pasa a la primera cuenta en esa moneda (o a la línea de la tarjeta);
  el selector de cuenta se abre filtrado a esa moneda (`currencyFilter`). El monto escrito no se convierte (L2-16) y la
  equivalencia y la cápsula de tasa siguen como hoy.
- Lo activado desde «···» se ve en el formulario: «Tu parte: S/ 7.25» (ya existe) y una cápsula «Cada mes» al hacerlo
  recurrente. Cuando hay algo activo, «···» lleva un punto.

### Fila
- Orden: **Categoría · Cuenta · Hoy · #**. En transferencia: Origen · Destino · Hoy (sin categoría ni etiquetas).
- Una sola línea. Los nombres largos de cuenta y categoría se cortan con «…»; Hoy y # no encogen. Con texto de
  accesibilidad vuelve a dos líneas, como hoy.
- «#» es un chip circular de 40 pt; con etiquetas puestas lleva su número («# 2»). Las pastillas por etiqueta de hoy
  (L2-19) se mueven a la hoja de etiquetas.
- Lo que falta para guardar sigue marcado con el borde de acento y la línea «Para guardar, falta…» encima del botón.

### Guardar y «Agregar otro»
- Abajo: «Agregar otro» (secundario, a la izquierda, `plus`) y «Guardar S/ 14.50» (primario, con el monto y su moneda).
  Sin monto, «Guardar» a secas y los dos apagados.
- «Agregar otro» guarda, vibra como un guardado, enseña el aviso «Gasto guardado» y deja la hoja vacía con el mismo
  tipo, moneda, cuenta y fecha. No pasa por la pantalla de éxito.
- Si no caben juntos (SE con montos de seis cifras): «Agregar otro» queda como «+» con su etiqueta para VoiceOver.
  Con texto grande, «Guardar» pierde el monto. Nunca baja «Agregar otro» debajo.
- Con teclado: la misma pareja en la barra de encima del teclado; la fila queda justo encima.

### Menú «···»
- `Menu` de iOS con: Mi parte (solo gasto), Guardar como favorito, Hacer recurrente (no en transferencia), cada uno con
  su estado debajo («Todo es tuyo» / «Tu parte: S/ 7.25», «No está en favoritos», «Una sola vez» / «Cada mes»).
- Al editar un registro guardado: separador, Duplicar y Eliminar (rojo). «Convertir a gasto compartido» sigue donde
  está hoy.
- Cada fila abre lo mismo que hoy abre su círculo (calculadora, hoja de favorito, hoja corta de recurrente).

### Pantalla de éxito
- Bajo el monto, dos chips: «☆ Guardar como favorito» y «↻ Hacer recurrente» (solo el primero en transferencia).
  Al tocarlos abren la hoja de siempre; al volver, el chip queda relleno («En favoritos», «Cada mes»).
- El resto, igual: «Editar», detalle, «Aceptar» y «Registrar otro».

## Alternativas (por si Jürgen elige otra en el artifact)

| Punto | A · Sobria | C · Guiada |
|---|---|---|
| Favorito al tocarlo | Se estira y se rellena; los demás no cambian | Borde de color y ✕ para deshacer lo que rellenó |
| Orden de la fila | Hoy · Cuenta · Categoría · # | Cuenta · Categoría · Hoy · # |
| «Guardar» | Sin monto | Con monto |
| «Agregar otro» | No | No |
| Menú «···» | `Menu` sin estado | Hoja corta (detent) con las tres opciones explicadas |
| Con teclado | Barra con «Guardar» | Barra G1 de hoy: lo que falta + «Guardar S/ …» |
| Éxito | Tarjeta «¿Lo registras seguido?» con dos botones | Dos filas explicadas con chevron |

## Textos nuevos

Van en su tabla de traducción propia (`L10n` de esta entrega), no en `Localizable.strings` a mano.

| Clave propuesta | es |
|---|---|
| `nr.title.newExpense` | Nuevo gasto |
| `nr.title.newIncome` | Nuevo ingreso |
| `nr.title.newTransfer` | Nueva transferencia |
| `nr.title.editExpense` / `editIncome` / `editTransfer` | Editar gasto / Editar ingreso / Editar transferencia |
| `nr.title.duplicateExpense` / `…Income` / `…Transfer` | Duplicar gasto / Duplicar ingreso / Duplicar transferencia |
| `nr.title.a11yChangeType` | Cambiar tipo |
| `nr.favorites.label` | Favoritos |
| `nr.currency.accountsCount` | %d cuentas (1: «1 cuenta») |
| `nr.more.a11y` | Más opciones |
| `nr.more.splitState.all` | Todo es tuyo |
| `nr.more.favorite` | Guardar como favorito |
| `nr.more.favoriteState.no` | No está en favoritos |
| `nr.more.recurring` | Hacer recurrente |
| `nr.more.recurringState.once` | Una sola vez |
| `nr.more.recurringState.monthly` | Cada mes |
| `nr.save.withAmount` | Guardar %@ |
| `nr.addAnother` | Agregar otro |
| `nr.saved.toast.expense` / `income` / `transfer` | Gasto guardado / Ingreso guardado / Transferencia guardada |
| `nr.success.favorited` | En favoritos |

## Riesgos

- **Accesibilidad.** Los chips de solo icono conservan su etiqueta («Usar el favorito Starbucks»); zona de toque de 44 pt.
  «#» se lee «Etiquetas» con el número como valor. El título-menú lleva «Cambiar tipo» como pista y el tipo como valor.
- **Descubrimiento.** Mi parte y Recurrente dejan de verse a primera vista. Mitigan: el punto en «···», las líneas de
  estado del formulario y las dos ofertas de la pantalla de éxito. La guía de primer registro (`NewRecordTutorialGuide`)
  necesita un paso nuevo para el título y mover sus anclas (fecha y categoría cambian de sitio).
- **Siri, atajos y widgets.** Centro de Control, el widget, ⌘N y el atajo de Siri abren la hoja como gasto: sin cambio.
  Lo que llega con datos (borrador de Yala IA, Duplicar, Editar) llega con su tipo y el título lo dice.
- **Pruebas automáticas.** Dependen de los controles que se mueven (contado en `YalaUITests` el 2026-11-19):
  `new_transaction_type_*` en 7 ficheros, `new_transaction_favorite_action` en 3, `new_transaction_delete_action` en 3,
  `new_transaction_split_action`, `new_transaction_recurring_action`, `new_transaction_date_chip`,
  `new_transaction_favorite_chip_*` y `new_transaction_duplicate_action` en 2 cada uno. Se migran al título-menú y a
  «···» en el mismo PR.
- **Una sola fila.** Corta nombres largos («Interbank Sueldo», «Supermercados»), sobre todo en el SE. Hoy no corta nada.
- **Moneda que filtra.** Quien solo tiene cuentas en soles no puede elegir dólares desde la cápsula. Hoy sí se apunta
  un importe en dólares en una tarjeta de varias monedas; eso se mantiene por sus líneas.

## Fuera de alcance

- No cambia qué se guarda ni cómo: solo dónde está cada control.
- iPad, el Duo y la ventana ancha se miden al implementar (las maquetas son de iPhone).
- La hoja de Nuevo gasto de Grupos no cambia.

## Cómo se sabe que está bien

- Capturas antes/después en el 17 Pro y el SE, claro y oscuro, con y sin teclado, gasto, ingreso y transferencia.
- XCUITest: cambiar de tipo por el título-menú, tocar un favorito y guardar con «Guardar S/ …», «Agregar otro» deja la
  hoja vacía con la misma cuenta, «···» › Hacer recurrente, y elegir dólares filtra el selector de cuenta.
- VoiceOver: los chips de favorito, «#», el título-menú y «···» se leen con nombre.
