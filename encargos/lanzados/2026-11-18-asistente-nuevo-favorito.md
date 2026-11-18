Yala
# Nuevo favorito por pasos con preguntas y opción «Prefiero formulario»
---
toca: Yala/App/Views/Favorites/FavoritesListView.swift,Yala/App/Views/Favorites/FavoriteEditorView.swift,Yala/Resources/de.lproj/AsistenteFavorito.strings,Yala/Resources/en-GB.lproj/AsistenteFavorito.strings,Yala/Resources/en.lproj/AsistenteFavorito.strings,Yala/Resources/es-419.lproj/AsistenteFavorito.strings,Yala/Resources/es-AR.lproj/AsistenteFavorito.strings,Yala/Resources/es-ES.lproj/AsistenteFavorito.strings,Yala/Resources/es.lproj/AsistenteFavorito.strings,Yala/Resources/fr.lproj/AsistenteFavorito.strings,Yala/Resources/it.lproj/AsistenteFavorito.strings,Yala/Resources/ja.lproj/AsistenteFavorito.strings,Yala/Resources/nl.lproj/AsistenteFavorito.strings,Yala/Resources/pl.lproj/AsistenteFavorito.strings,Yala/Resources/pt-BR.lproj/AsistenteFavorito.strings,Yala/Resources/pt-PT.lproj/AsistenteFavorito.strings,Yala/Resources/pt.lproj/AsistenteFavorito.strings,Yala/Resources/zh-Hans.lproj/AsistenteFavorito.strings,YalaTests/AsistenteFavorito/,YalaUITests/AsistenteFavorito/,tickets/done/2026-11-17-asistente-nuevo-favorito.md
esfuerzo: medium
cierre: cierra-sola
depende: Yala/asistente-nuevo-presupuesto
---

Pedido de Jürgen del 17-nov (20:51 Lima), con captura de Planificación. Base 2.3, un PR. Sesión enfocada solo en esta vista (una vista por sesión). Es parte de una serie: presupuesto (crea el patrón), pago planificado, grupo, cuenta y favorito.

## Qué quiere
- Al tocar crear, en vez del formulario, se abre un **proceso por pasos con preguntas** (una pregunta clara por pantalla, en lenguaje simple, con valores sugeridos y progreso arriba).
- Arriba, siempre visible, una opción para quien prefiere lo de siempre, por ejemplo «Prefiero formulario» (elige el texto más claro y corto). Al tocarla se muestra el formulario actual, con lo ya respondido pasado al formulario.
- Al final, un resumen breve y el botón de crear. Nunca un botón debajo del otro. X nativa para salir; si ya respondió algo, pregunta antes de descartar, igual que el formulario.
- No hace falta recordar la elección «Prefiero formulario» entre usos salvo que sea trivial; si lo haces, que se pueda volver al asistente.

## Esta vista
- Tocar «Nuevo favorito» en la lista de Favoritos. Hoy abre `FavoriteEditorView`. Guardar como favorito desde un registro (`SaveAsFavoriteSheet`) sigue igual; no lo toques. Editar uno existente sigue en el formulario.
- Reúsa el patrón compartido de `Yala/App/Views/Shared/AsistenteCreacion/` que dejó la sesión del presupuesto, sin modificarlo (no está en tu toca). Si le falta algo, resuélvelo en tu vista y anótalo como pendiente.

## Cómo entregar
- Tests de la lógica de pasos y del paso a formulario con lo respondido en `YalaTests/AsistenteFavorito/`; prueba de UI del recorrido completo y de «Prefiero formulario» en `YalaUITests/AsistenteFavorito/`.
- Capturas de cada paso y del formulario (iPhone 17 y SE, también con letra grande, claro y oscuro, y iPad).
- Puedes usar un segundo simulador en la Max además del de otra sesión, o el iPhone 14 por DeviceMCP. En la Mini, solo uno.
- Entregable visual: artifact de Claude con el recorrido paso a paso y el antes y después.
- Commits y PR sin firma de IA. Toca solo lo declarado; lo menor, con la opción recomendada, anotado en «Decidido sin consultar». Textos nuevos en `AsistenteFavorito.strings` de cada `.lproj`, nunca en `Localizable.strings`.
- Lo vital, según el modo fijado al arrancar (semi: pregunta y espera viva; nocturno: checkpoint recuperable y card «Espera decisión», sin mergear lo incompleto).
- Cierre: completo y CI verde, `/cerrar-total` con «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada», y el link del artifact.

## Paso 0 (decidido por la sesión, modo semi; nada vital pendiente)

- **Preguntas.** Gasto o ingreso: tipo → categoría → nombre → monto → cuenta → resumen (6). Transferencia: tipo →
  nombre → monto → desde qué cuenta → a qué cuenta → resumen (6). Con «Solo gastos» no se pregunta el tipo (5).
  Etiquetas, nota y naturaleza no se preguntan: quedan vacías, como en el formulario recién abierto.
- **Sugerido ya elegido.** Tipo: Gasto. Categoría: «Sin categoría» (opcional, como en el formulario), con las 4 más
  recientes y «Otra categoría». Nombre: el de la categoría (o «Transferencia»). Monto: vacío = «lo pones al usarlo».
  Cuenta: la del último registro (o la única); destino: la primera distinta del origen.
- **«Usar formulario»**: es el texto del contenedor compartido (`asistente.useForm`), que no está en mi `toca`; no lo
  cambio a «Prefiero formulario». Abre el formulario de siempre en la misma hoja con lo respondido, y ese formulario
  pregunta antes de descartar. No se recuerda la elección.
- **Dónde vive.** Ficheros nuevos en `Yala/App/Views/Favorites/AsistenteFavorito/` (carpeta nueva, sin choque posible).
  Las pruebas de UI que creaban por el «+» (`FavoritesCrudUITests`, `FavoritesAlRegistrar23UITests`,
  `TutorialVideoRecordingUITests`) pasan antes por «Usar formulario», como hizo el pago planificado, y el índice de QA
  se actualiza en el mismo commit: los tres y `qa/coverage-index.json` quedan fuera del `toca` declarado.
- **Guardado.** Por `FavoriteEditorViewModel.saveFavorite`, el mismo camino que el formulario.
