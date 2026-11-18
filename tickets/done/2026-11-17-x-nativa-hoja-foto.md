---
id: 2026-11-17-x-nativa-hoja-foto
status: done
priority: medium
area: "image-entry, groups-capture"
created: 2026-11-17
updated: 2026-11-17
source: "Jürgen, 17-nov 18:03 y 18:14 (Lima), con captura del iPhone"
---

# Hoja de foto: X nativa, cabecera ordenada, descripción editable y cierre automático

En la hoja «Registrar con foto o archivo» (personal y Grupos) la X era un botón dibujado a mano, de ~30 pt, en una fila
sola encima del título: quedaba un hueco arriba y el título con la miniatura debajo. Para corregir la descripción de lo
leído había que abrir el formulario completo, y tras guardar todo la hoja pedía «Listo».

## Hecho cuando

- La X es la del sistema, con los 44 pt de las barras, en personal y en las hojas de captura de Grupos.
- Título (y en «Esto leí»/«Guardado», las miniaturas) en la misma fila que la X, sin hueco.
- Tocar la descripción de una fila de «Esto leí» la edita ahí mismo; el resto de la fila abre el formulario.
- Al guardar el último pendiente con todo guardado, la hoja enseña «Guardado» y se cierra sola; con algo pendiente o un
  error, no.

## Resolución (2026-11-17)

- `EntrySheetCloseButton`: `Button(role: .close)` con círculo de cristal de 44 pt. La usan `ImageSelectionView` (`image_close`)
  y `GroupCaptureHeader` (Foto y Voz de Grupos, `receipt_split_close`). El chat IA de grupo ya tenía la X del sistema en su
  barra.
- La cabecera de la hoja personal lleva el título de la fase (elegir, contraseña, «Esto leí»/«Guardado») y las miniaturas en
  la fila de la X. Con «Omitir» de primeros pasos, la fila es «Omitir … X» y el título queda debajo. Foto de Grupos, igual
  (elegir y «lo entendido»).
- `DraftNoteInlineEditor`: la descripción es un botón propio dentro de la fila; al tocarlo pasa a campo con teclado, y
  «Listo», Intro o tocar fuera lo confirma y lo guarda en el borrador. Solo lo enciende la hoja de foto
  (`editsNoteInPlace`); la de voz no cambia. En Grupos, el nombre de cada línea del reparto se edita igual.
- `ImageEntryAutoCloseLogic`: se cierra tras ~0,6 s si todo quedó guardado y no hay error, fotos sin leer ni páginas que no
  entraron. Lo guardado desde el formulario completo cuenta igual. «Usar este reparto» de Grupos ya cerraba la hoja.
- Pruebas: `YalaTests/XNativaHojaFoto` (lógica y cableado) y `YalaUITests/XNativaHojaFoto` (X de 44 pt en la fila del
  título, edición en línea, cierre solo, fila fuera de la descripción abre el formulario, uno sin guardar no cierra, Grupos).

## Device-QA (iPhone 14, cuando se pueda)

1. Abre Yala Dev → Registros → «Foto» → «Fotos» y elige un recibo.
2. En «Esto leí», toca el texto de la descripción: tiene que salir el teclado con el texto en la fila. Escribe algo y pulsa
   «Listo». Esperado: la fila enseña lo nuevo, sin abrir Nuevo registro.
3. Toca el importe de la misma fila. Esperado: abre el formulario completo.
4. Ciérralo y pulsa «Guardar». Esperado: el título pasa a «Guardado», vibra, y la hoja se cierra sola en menos de un segundo.
5. Compara la X con la de Nuevo registro: mismo tamaño.
