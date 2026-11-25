---
id: 2026-11-24-bandeja-fila-con-fuentes
status: done
area: "bandeja, apple pay, correo del banco, aviso del banco, yala web, conector de IA"
created: 2026-11-24
updated: 2026-11-24
source: "Jürgen, 24-nov (14:30 y 14:32 Lima): «vamos con todo lo recomendado» de docs/propuestas/bandeja-sin-duplicados/README.md (opción B). Lote 3 del plan, en 2.3"
---

# Bandeja: una fila por consumo con sus fuentes, «¿Es el mismo gasto?» y «Ya registrado» (lote 3)

## Qué se pidió
Siguiendo las maquetas de la propuesta: la fila de un pendiente unido dice de qué fuentes viene («Apple Pay · Correo ·
Aviso de BCP») y el borrador lleva «Separar»; la coincidencia dudosa sale agrupada como «¿Es el mismo gasto?» con «Es el
mismo» y «Son distintos»; lo que ya está guardado dice «Ya registrado el 15 oct · Descartar / Guardar igual». Capturas
antes y después en iPhone y iPad.

## Qué cambia para la persona
- Un pendiente que la Bandeja juntó enseña una cápsula por fuente, en el orden en que llegaron. El borrador dice las
  mismas fuentes junto a «Separar».
- Dos pendientes que pueden ser el mismo gasto (por ejemplo Apple Pay a las 23:50 y el correo del día siguiente con la
  propina) salen juntos en una tarjeta «¿Es el mismo gasto?». **Es el mismo** los junta en un pendiente con el importe
  del banco y «Separar» en el borrador; **Son distintos** los deja como dos y no se vuelve a preguntar en este teléfono.
- Un pendiente que se parece a un registro ya guardado dice **Ya registrado el 15 oct** con **Descartar** (a
  Archivados, con Deshacer) y **Guardar igual** (lo guarda sin la pregunta; si le falta algo, abre el borrador). Es el
  mismo criterio que hace que «Guardar los listos» lo deje pendiente: la fila lo dice antes.
- Lo que se separa con «Separar» no vuelve a preguntarse como «¿Es el mismo gasto?».

## Decisiones (Paso 0 del encargo, auto-contestado en nocturno)
- «Son distintos» y «Separar» se recuerdan solo en este teléfono (`UserDefaults`, como «Quitar de aquí»): un campo
  sincronizado pediría otra migración. En otro aparato se volvería a preguntar.
- En la lista nunca se une nada solo: también lo fuerte que no se unió al llegar (de antes de la unión) se pregunta.
- «Ya registrado» usa `InboxDuplicateCheck` (lote 0), no la ventana de 72 h del emparejador: así avisa justo de lo que
  frenaría el guardado.

## Qué se tocó
- `InboxDraftRowView`: cápsulas por fuente, pie «Ya registrado» con sus dos botones fuera del botón de la fila, y la
  tarjeta `InboxSameExpensePairCard`.
- `InboxViewModel`: `InboxSameExpensePairing` (pura, uno a uno), `InboxSameExpenseDistinct`, «Ya registrado» y
  `listSections`.
- `InboxArrivalJoin.joinPending` («Es el mismo» por el camino de la unión al llegar); `InboxView` lo pinta y cablea.
- `InboxDraftEditSheet`: nombres de fuente de la fila y marca de distintos al separar.
- Textos en `BandejaUnir.strings` (16 idiomas); semilla `-uitest-inbox-same-expense-pair`; clave retirada por el borrado
  de datos.

## Pruebas
- `YalaTests/BandejaFilaConFuentes/`: qué se pregunta (dudoso, misma fuente, reembolso, distinto, uno a uno), «Es el
  mismo» con el importe del banco y «Separar», «Ya registrado», el tope de lo distinto, cableado y textos.
- `YalaUITests/BandejaFilaConFuentes/`: fuentes en la fila, la tarjeta, «Son distintos», «Es el mismo» con «Separar» y
  «Descartar» de «Ya registrado».
