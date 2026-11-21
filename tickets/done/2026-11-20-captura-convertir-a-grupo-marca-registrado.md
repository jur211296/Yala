---
id: 2026-11-20-captura-convertir-a-grupo-marca-registrado
status: done
priority: high
area: "inbox-convert-to-group, image-entry, voice-entry"
created: 2026-11-20
updated: 2026-11-20
source: "bug de Jürgen en su iPhone, 2026-11-20 09:42"
---

# Al convertir a gasto compartido un registro leído de una foto, queda marcado como registrado

## Qué pasaba

En la pantalla de lo leído de una foto, «Convertir a gasto compartido» abría el formulario de Grupos y el gasto se
guardaba bien, pero al volver la fila seguía ahí, sin marcar, como si no se hubiera hecho nada.

## Causa

Al guardar el gasto de grupo, el borrador se borra. La pantalla lo quitaba de la lista mirando `isDeleted`, que tras el
guardado vuelve a `false`: la fila se quedaba y la hoja no se enteraba. La pantalla de voz usa el mismo flujo y tenía el
mismo hueco.

## Arreglo

- El flujo de conversión copia lo registrado antes de borrar el borrador y se lo devuelve a la pantalla.
- Foto y voz enseñan esa fila como guardada («Guardado», con el grupo debajo) y sin botón: no puede volver a guardarse
  como personal.
- En la foto, si era el único, la hoja se cierra sola como al guardar el último. En la voz, igual que al guardar el
  último allí: «Guardado» y «Listo».
- Cancelar el formulario de grupo no cambia nada: el registro sigue pendiente.

## Pruebas

- `YalaTests/CapturaConvertirAGrupo/` — guardar en grupo marca registrado, cerrar si era el único, cancelar no marca, y
  el cableado de las dos pantallas.
- `YalaUITests/Flows/CaptureConvertToGroupUITests` — foto (marca y cierre), foto cancelando y voz.
