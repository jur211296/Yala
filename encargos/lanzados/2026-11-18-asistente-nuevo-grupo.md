Yala
# Nuevo grupo por pasos con preguntas y opción «Prefiero formulario»
---
toca: Yala/App/Views/Groups/GroupsContainerView.swift,Yala/App/Views/Groups/GroupFormView.swift,Yala/Resources/de.lproj/AsistenteGrupo.strings,Yala/Resources/en-GB.lproj/AsistenteGrupo.strings,Yala/Resources/en.lproj/AsistenteGrupo.strings,Yala/Resources/es-419.lproj/AsistenteGrupo.strings,Yala/Resources/es-AR.lproj/AsistenteGrupo.strings,Yala/Resources/es-ES.lproj/AsistenteGrupo.strings,Yala/Resources/es.lproj/AsistenteGrupo.strings,Yala/Resources/fr.lproj/AsistenteGrupo.strings,Yala/Resources/it.lproj/AsistenteGrupo.strings,Yala/Resources/ja.lproj/AsistenteGrupo.strings,Yala/Resources/nl.lproj/AsistenteGrupo.strings,Yala/Resources/pl.lproj/AsistenteGrupo.strings,Yala/Resources/pt-BR.lproj/AsistenteGrupo.strings,Yala/Resources/pt-PT.lproj/AsistenteGrupo.strings,Yala/Resources/pt.lproj/AsistenteGrupo.strings,Yala/Resources/zh-Hans.lproj/AsistenteGrupo.strings,YalaTests/AsistenteGrupo/,YalaUITests/AsistenteGrupo/,tickets/done/2026-11-17-asistente-nuevo-grupo.md
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
- Tocar «Nuevo grupo» en Grupos. Hoy abre `GroupFormView` (desde `GroupsContainerView`; también hay una entrada en `ContentView.swift`, que no está declarada: si hace falta cambiarla, anótala como pendiente). Mira `GroupsTutorialFlowView` y `GroupCreateRoutingLogic` como referencia. Al terminar, mantén lo que pasa hoy después de crear (por ejemplo, la hoja de invitar). Editar un grupo existente sigue en el formulario.
- Reúsa el patrón compartido de `Yala/App/Views/Shared/AsistenteCreacion/` que dejó la sesión del presupuesto, sin modificarlo (no está en tu toca). Si le falta algo, resuélvelo en tu vista y anótalo como pendiente.

## Cómo entregar
- Tests de la lógica de pasos y del paso a formulario con lo respondido en `YalaTests/AsistenteGrupo/`; prueba de UI del recorrido completo y de «Prefiero formulario» en `YalaUITests/AsistenteGrupo/`.
- Capturas de cada paso y del formulario (iPhone 17 y SE, también con letra grande, claro y oscuro, y iPad).
- Puedes usar un segundo simulador en la Max además del de otra sesión, o el iPhone 14 por DeviceMCP. En la Mini, solo uno.
- Entregable visual: artifact de Claude con el recorrido paso a paso y el antes y después.
- Commits y PR sin firma de IA. Toca solo lo declarado; lo menor, con la opción recomendada, anotado en «Decidido sin consultar». Textos nuevos en `AsistenteGrupo.strings` de cada `.lproj`, nunca en `Localizable.strings`.
- Lo vital, según el modo fijado al arrancar (semi: pregunta y espera viva; nocturno: checkpoint recuperable y card «Espera decisión», sin mergear lo incompleto).
- Cierre: completo y CI verde, `/cerrar-total` con «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada», y el link del artifact.

## Paso 0 — decisiones

> Resueltas por la sesión (modo semi, decisiones menores y reversibles): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Qué preguntas tiene el asistente?** → Cinco y el resumen: nombre (con ideas «Viaje, Casa, Pareja, Amigos, Trabajo» y «Traer de Splitwise o Tricount»), icono, cómo dividen los gastos, menos pagos entre ustedes, en qué moneda ven las deudas; resumen con «Crear grupo».
Por qué: son exactamente los campos del formulario, uno por pantalla, con el valor de un grupo nuevo ya elegido. Alternativa descartada: solo nombre + resumen (no sería «por pasos con preguntas»).

**D2 · ¿Texto del botón de arriba?** → «Usar formulario», el del contenedor compartido.
Por qué: el patrón no se modifica (no está en el toca) y la serie entera dice lo mismo. Alternativa descartada: «Prefiero formulario», que exigiría tocar el contenedor.

**D3 · ¿Dónde viven los ficheros nuevos?** → `Yala/App/Views/Groups/AsistenteGrupo/` (carpeta nueva, sin `pbxproj` por grupos sincronizados).
Por qué: el toca no declara carpeta de vistas y una carpeta nueva no choca con nadie. Alternativa descartada: meter todo en `GroupsContainerView` (1.400 líneas ya).

**D4 · ¿Cómo llega lo respondido al formulario?** → Por el entorno (`\.groupFormPrefill`), no por un parámetro nuevo.
Por qué: un source-scan (`UXAudit22Lote12y13Tests`) fija la llamada literal `GroupFormView(group: nil, onCreated: { receiveCreatedGroup($0) })` en la pestaña; así sigue igual y el test sigue midiendo lo que mide. Alternativa descartada: parámetro `prefill:` y tocar ese test (fuera del toca).

**D5 · ¿Cuándo pregunta antes de descartar?** → Asistente: con una pregunta pasada o con el nombre ya escrito. Formulario abierto desde el asistente: siempre que lleve lo respondido.
Por qué: un nombre escrito es una respuesta aunque no se haya tocado «Siguiente». Alternativa descartada: solo tras «Siguiente» (el presupuesto lo hace así, pero perdería el nombre sin avisar).

**D6 · ¿Se recuerda «Usar formulario» entre usos?** → No.
Por qué: el encargo lo deja opcional y no es trivial (habría que dar la vuelta al asistente desde el formulario).

**D7 · ¿Y la entrada de `ContentView` (primer grupo desde la bienvenida)?** → Sigue en el formulario; anotado como pendiente.
Por qué: no está declarada y lleva el nombre de la persona y el alta, que no son preguntas de este asistente.

**D8 · ¿Los XCUITest que abren el formulario de crear?** → Pasan antes por «Usar formulario» con un ayudante (`abrirFormularioDeNuevoGrupo`), como hizo la sesión del presupuesto, y `qa/coverage-index.json` gana el área del asistente.
Por qué: sin eso se ponen rojos; cambiar la entrada es el encargo. Están fuera del toca y se anotan.
