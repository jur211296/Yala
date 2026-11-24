---
id: 2026-11-24-exito-grupos-y-bandeja-como-personal
status: qa
priority: medium
area: "groups, inbox, ui"
created: 2026-11-24
updated: 2026-11-24
source: "QA de Jürgen sobre la 2.3 en su iPhone (24-nov)"
---

# El éxito de Grupos y de la Bandeja, con el diseño minimalista del registro personal

Jürgen vio en la 2.3 que guardar un gasto de grupo enseñaba la pantalla de éxito vieja (círculo verde grande, confeti,
botones apilados), distinta de la de Nuevo registro rediseñada el 20-nov. Las dos de la Bandeja (aprobar uno y varios)
tampoco se habían llevado al diseño nuevo.

## Qué cambió para quien usa la app

- **Gasto de grupo:** «Editar» arriba, un check pequeño junto a «Gasto agregado» (o «Venta agregada»), la descripción
  sobre el monto grande y, debajo, lo que te toca («Debes S/ 40.00 · Se lo debes a Ana»). Una tarjeta sin rótulos con
  grupo, quién pagó («Pagaste tú» / «Pagó Ana»), fecha, categoría, cuenta y el reparto con cada participante. Debajo,
  qué apuntó Yala en tus finanzas con «Partir tu parte» (solo si el puente lo escribió de verdad, como antes). Al pie,
  «Agregar otro gasto» y «Aceptar» lado a lado.
- **Bandeja, aprobar uno:** el mismo esqueleto: «Gasto guardado» / «Ingreso guardado» con su check del color del tipo,
  la nota sobre el monto (sin signo, como en la personal), fecha, cuenta y categoría en la tarjeta, y «Guardar el
  siguiente» junto a «Aceptar».
- **Bandeja, aprobar varios:** «2 registros guardados» con el check, el total grande si todos comparten moneda (si no,
  cuántos), la cuenta común y lo que se quedó en la Bandeja como filas de aviso; «Volver a bandeja» junto a «Ver en
  registros». Si no se guardó nada, el check pasa a aviso.
- Si los dos botones del pie no caben (idioma largo, texto grande), van uno debajo del otro.

## Qué se tocó

- `Views/Shared/MinimalSuccessParts.swift` (nuevo): esqueleto, título, tarjeta, fila sin rótulo y pie, copiados del
  patrón de `TransactionSuccessView`.
- `GroupExpenseSuccessView`, `InboxApproveSuccessView`, `InboxBulkApproveSuccessView` reescritas sobre esas piezas.
- `GroupExpenseSuccessLogic`: orden de las filas, color por gasto/venta y tono de la línea de tu parte.
- Textos nuevos en `ExitoGruposBandeja.strings` (16 idiomas).

## Pruebas

- `YalaTests/ExitoGruposBandeja/`: orden de filas, figura grande de varios, color, paridad de los 16 idiomas y el
  cableado (ids, la oferta al guardar, la verdad del puente).
- `YalaUITests/ExitoGruposBandeja/ExitoGruposBandejaCapturasUITests`: las cuatro pantallas en claro, oscuro y girado.

## Pendiente

- **Refactor:** que `TransactionSuccessView` use las mismas piezas (`MinimalSuccessParts`). No se hizo porque el
  encargo no dejaba tocarla.
- **Device-QA (iPhone):** guardar un gasto de grupo pagado por ti y por otro, aprobar uno y varios en la Bandeja;
  mirar que se vean como la personal y que «Partir tu parte» y «Guardar el siguiente» funcionen.
