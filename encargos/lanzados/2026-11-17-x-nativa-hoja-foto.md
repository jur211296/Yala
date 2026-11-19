Yala
# Hoja de foto (personal y Grupos): X nativa, cabecera ordenada, descripción editable en «Esto leí» y cierre automático al guardar todo
---
toca: Yala/App/Views/Image/ImageSelectionView.swift,Yala/App/Views/Groups/Captura/GroupCaptureChrome.swift,Yala/App/Views/Groups/Captura/GroupPhotoCaptureView.swift,YalaTests/XNativaHojaFoto/,YalaUITests/XNativaHojaFoto/,tickets/done/2026-11-17-x-nativa-hoja-foto.md
esfuerzo: medium
cierre: cierra-sola
---

Arreglos de UI que pidió Jürgen el 17-nov (18:03 y 18:14 Lima), con captura suya del iPhone. Base 2.3, un PR. Sesión enfocada solo en esta vista (Jürgen: no mezclar vistas en una sesión).

## 1. La X de la hoja «Registrar con foto o archivo» es diminuta y no es nativa
- Hoy, `ImageSelectionView.swift` (cabecera, `image_close`) y `GroupCaptureHeader` en `Groups/Captura/GroupCaptureChrome.swift` dibujan `YalaToolbarButton("xmark")` con `.buttonStyle(.glass)` dentro del contenido de la hoja, fuera de una barra. Queda chica.
- Debe ser el botón de cerrar nativo de iOS 26, con el tamaño y la zona táctil del sistema, igual al que tienen las demás hojas de Yala (por ejemplo la X de Nuevo registro): `Button(role: .close)` o la X en la barra de navegación (`ToolbarItem` con `.cancellationAction`/`.topBarTrailing`), la que encaje con el alto variable de la hoja (`ImageEntrySheetHeight.swift`). Mantén `image_close` y el identificador de Grupos para no romper las pruebas.
- Revisa en Grupos todas las hojas de captura (foto, archivo, chat IA de grupo) y deja la misma X nativa donde haya una hecha a mano dentro de la hoja. No toques las X chicas de los banners descartables (no son cierres de hoja). Si encuentras otra hoja fuera de lo declarado con el mismo problema, anótala en el cierre como pendiente y no la toques.
- Respeta «Omitir» de la lista de primeros pasos en la misma fila, y la regla dura: nunca un botón debajo del otro.

## 2. Cabecera ordenada (sin hueco arriba)
- En las fases «Esto leí» y «Guardado», el título, la miniatura de la imagen y la X quedan desordenados: hay un hueco arriba (fila de la X sola) y luego el título con la miniatura a la derecha. Reubica título, miniatura y X nativa para que se vea ordenado y sin espacio vacío (por ejemplo, título y miniatura en la misma línea que la X, o la X en la barra nativa con el título). Elige la opción más limpia y nativa, y muéstrala en el artifact. Igual en Grupos.

## 3. Editar la descripción ahí mismo en «Esto leí»
- Al tocar el texto de la descripción de una fila leída (p. ej. «Municipalidad Metropolita»), se edita en el lugar (campo en línea, teclado, Listo/Enter confirma), sin abrir Nuevo registro. Tocar el resto de la fila sigue abriendo el formulario completo como hoy. Lo editado es lo que se guarda. Funciona con una y con varias fotos, y en Grupos si la fila tiene descripción.

## 4. Cierre automático cuando ya se guardó todo
- Cuando se guarda el último pendiente y ya están guardados todos, la hoja se cierra sola (tras una confirmación breve, como el check de «Guardado» de medio segundo con háptica), sin pedir «Listo». Si queda alguno sin guardar o hubo error, no se cierra. Igual en Grupos.

## Cómo entregar
- Compila y pasa los tests afectados. Capturas antes y después de: hoja de foto personal y de Grupos en las fases elegir, «Esto leí» (editando la descripción) y guardado con cierre automático (iPhone 17 y SE, también con letra grande).
- Puedes usar un segundo simulador en la Max además del de otra sesión, o el iPhone 14 por DeviceMCP. En la Mini, solo uno.
- Entregable visual: artifact de Claude con antes y después lado a lado.
- Commits y PR sin firma de IA. Toca solo lo declarado; lo menor, con la opción recomendada, anotado en «Decidido sin consultar». Textos nuevos, si hiciera falta alguno, en una tabla propia (`XNativaHojaFoto.strings`), nunca en `Localizable.strings`.
- Lo vital, según el modo fijado al arrancar (semi: pregunta y espera viva; nocturno: checkpoint recuperable y card «Espera decisión», sin mergear lo incompleto).
- Cierre: completo y CI verde, `/cerrar-total` con «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada», y el link del artifact.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass, modo nocturno): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Qué X «nativa» y dónde?** → `Button(role: .close)` de iOS 26 (la X del sistema), con la zona táctil de 44 pt de las barras, en la fila de la cabecera de la hoja; no se envuelve la hoja en un `NavigationStack`.
Por qué: la hoja cambia de alto (`ImageEntrySheetHeight`) y presenta cuatro hojas y un cover encima; meter una pila de navegación cambia fondo, foco y anclas de todo eso por una X. Alternativa descartada: título inline en la barra de navegación, que en el SE y en alemán se corta y con letra grande no crece.

**D2 · ¿Cómo queda la cabecera sin hueco?** → Una sola fila: título (y en «Esto leí»/«Guardado», las miniaturas) a la izquierda y la X a la derecha, alineados al centro de la X. Vale para elegir, contraseña y «Esto leí»; leyendo (sin X) y fallo (icono centrado) quedan como estaban. Con «Omitir» de primeros pasos, la fila es «Omitir … X» y el título va debajo, para no apretar tres cosas.
Por qué: es lo que pide Jürgen («título y miniatura en la misma línea que la X») y la hoja se lee igual en todas sus fases. Alternativa descartada: arreglarlo solo en «Esto leí», que dejaba elegir con el hueco dentro de la misma hoja.

**D3 · Grupos** → La cabecera compartida de Voz y Foto de Grupos (`GroupCaptureHeader`) pasa a la misma X nativa y acepta el título en su fila; Foto lo usa en elegir y en «lo entendido». Voz solo hereda la X. El chat IA de grupo ya tiene la X del sistema en su barra: no se toca.
Por qué: una sola pieza compartida; tocar Voz más allá de la X es otra vista (Jürgen: no mezclar vistas).

**D4 · Editar la descripción en «Esto leí»** → Tocar el texto de la descripción lo convierte en un campo en línea con teclado; «Listo»/Intro o tocar fuera confirma, y lo escrito se guarda en el borrador al momento (como ya hacen las píldoras). Vacío = sin descripción. Tocar el resto de la fila sigue abriendo el formulario. Es opcional por parámetro en `VoiceDraftReviewCard` y `MultiDraftReviewList`: solo la hoja de foto lo enciende; la de voz no cambia. En Grupos, el nombre de cada línea del reparto se edita igual (alimenta la descripción del gasto).
Por qué: las filas son compartidas con voz y el encargo es solo la hoja de foto. Toca dos ficheros de `Voice/` y `GroupReceiptSplitView.swift`, fuera del `toca:`: sin ellos no hay forma de editar en la fila.

**D5 · Cierre automático** → Cuando un guardado deja la hoja sin nada pendiente (todo guardado o, con varios, lo marcado ya guardado) y sin error, la hoja enseña «Guardado» con su háptica de éxito ~0,6 s y se cierra sola. Con algo pendiente o un error, no. En Grupos «Usar este reparto» ya cerraba la hoja: no cambia.
Por qué: lo pide el encargo; el retardo deja ver el check. Alternativa descartada: cerrar en el acto, sin confirmación visible.

**D6 · Textos nuevos** → Ninguno: el campo usa como marcador la descripción de respaldo que ya se pinta, y la acción de VoiceOver reutiliza claves existentes si las hay; si hiciera falta una, va a `XNativaHojaFoto.strings`.

Ninguna decisión dura más allá de este cambio: no hay ADR.
