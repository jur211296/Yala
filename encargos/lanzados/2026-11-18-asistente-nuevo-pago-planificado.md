Yala
# Nuevo pago planificado por pasos con preguntas y opción «Prefiero formulario»
---
toca: Yala/App/Views/Planning/ScheduledPaymentsView.swift,Yala/App/Views/Planning/ScheduledPaymentsListView.swift,Yala/App/Views/Planning/ScheduledPaymentEditorView.swift,Yala/App/Views/Onboarding/PrimerosPasos/FirstScheduledPaymentFlowView.swift,Yala/Resources/de.lproj/AsistentePagoPlanificado.strings,Yala/Resources/en-GB.lproj/AsistentePagoPlanificado.strings,Yala/Resources/en.lproj/AsistentePagoPlanificado.strings,Yala/Resources/es-419.lproj/AsistentePagoPlanificado.strings,Yala/Resources/es-AR.lproj/AsistentePagoPlanificado.strings,Yala/Resources/es-ES.lproj/AsistentePagoPlanificado.strings,Yala/Resources/es.lproj/AsistentePagoPlanificado.strings,Yala/Resources/fr.lproj/AsistentePagoPlanificado.strings,Yala/Resources/it.lproj/AsistentePagoPlanificado.strings,Yala/Resources/ja.lproj/AsistentePagoPlanificado.strings,Yala/Resources/nl.lproj/AsistentePagoPlanificado.strings,Yala/Resources/pl.lproj/AsistentePagoPlanificado.strings,Yala/Resources/pt-BR.lproj/AsistentePagoPlanificado.strings,Yala/Resources/pt-PT.lproj/AsistentePagoPlanificado.strings,Yala/Resources/pt.lproj/AsistentePagoPlanificado.strings,Yala/Resources/zh-Hans.lproj/AsistentePagoPlanificado.strings,YalaTests/AsistentePagoPlanificado/,YalaUITests/AsistentePagoPlanificado/,tickets/done/2026-11-17-asistente-nuevo-pago-planificado.md
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
- Tocar «Nuevo pago planificado» en Planificación › Pagos planificados. Hoy abre `ScheduledPaymentEditorView`. Reúsa el flujo de primeros pasos `FirstScheduledPaymentFlowView` si sirve, sin romperlo. Los caminos que ya vienen con datos (crear desde un registro, desde Nuevo registro o desde una propuesta de pago recurrente) siguen abriendo el formulario prellenado; no los toques. Editar uno existente sigue en el formulario.
- Reúsa el patrón compartido de `Yala/App/Views/Shared/AsistenteCreacion/` que dejó la sesión del presupuesto, sin modificarlo (no está en tu toca). Si le falta algo, resuélvelo en tu vista y anótalo como pendiente.

## Cómo entregar
- Tests de la lógica de pasos y del paso a formulario con lo respondido en `YalaTests/AsistentePagoPlanificado/`; prueba de UI del recorrido completo y de «Prefiero formulario» en `YalaUITests/AsistentePagoPlanificado/`.
- Capturas de cada paso y del formulario (iPhone 17 y SE, también con letra grande, claro y oscuro, y iPad).
- Puedes usar un segundo simulador en la Max además del de otra sesión, o el iPhone 14 por DeviceMCP. En la Mini, solo uno.
- Entregable visual: artifact de Claude con el recorrido paso a paso y el antes y después.
- Commits y PR sin firma de IA. Toca solo lo declarado; lo menor, con la opción recomendada, anotado en «Decidido sin consultar». Textos nuevos en `AsistentePagoPlanificado.strings` de cada `.lproj`, nunca en `Localizable.strings`.
- Lo vital, según el modo fijado al arrancar (semi: pregunta y espera viva; nocturno: checkpoint recuperable y card «Espera decisión», sin mergear lo incompleto).
- Cierre: completo y CI verde, `/cerrar-total` con «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada», y el link del artifact.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass, sesión nocturna): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Sobre qué base?** → Sobre la rama del asistente de presupuesto (su PR está en cola de auto-merge), y un solo rebase a `2.3` antes de abrir el PR.
Por qué: el encargo declara `depende:` y el patrón compartido aún no está en `2.3`. Alternativa descartada: copiar el patrón (dos fuentes).

**D2 · ¿Texto de la salida al formulario?** → «Usar formulario», el que ya pinta el contenedor compartido.
Por qué: el patrón no se modifica y la serie debe decir lo mismo en todas las vistas. Alternativa descartada: «Prefiero formulario» (exigiría tocar el patrón).

**D3 · ¿Qué preguntas?** → Siete pantallas: tipo (con «Es una suscripción») → nombre → monto (con «Cambia cada vez») → cada cuánto → qué día → aviso → resumen.
Por qué: una pregunta por pantalla; las respuestas y textos de tipo, día y aviso son los de Primeros pasos. Alternativa descartada: nombre y monto juntos como en Primeros pasos (dos preguntas en una).

**D4 · ¿Valores sugeridos?** → Mensual, el día de hoy (como el formulario), aviso 3 días antes, nombre propuesto por el tipo con ejemplos; el tipo NO llega elegido y el monto llega vacío.
Por qué: elegir un tipo o un monto por la persona metería datos falsos. Alternativa descartada: preseleccionar «Renta».

**D5 · ¿Ingreso o gasto?** → Solo gasto en el asistente; un cobro planificado se crea con «Usar formulario».
Por qué: Primeros pasos tampoco pregunta y la mayoría son gastos. Alternativa descartada: una pregunta más para todos.

**D6 · ¿Cuenta?** → La última usada, como el formulario y Primeros pasos; se ve en la tarjeta del resumen y se cambia en el formulario.
Por qué: no añade pregunta. Alternativa descartada: pregunta de cuenta.

**D7 · ¿Dónde viven los ficheros nuevos?** → `Yala/App/Views/Planning/AsistentePagoPlanificado/` (fuera del `toca`, carpeta nueva, sin choque posible).
Por qué: el patrón compartido no se toca y Planificación es el área de la vista. Alternativa descartada: subcarpeta dentro de `Shared/AsistenteCreacion/`.

**D8 · ¿Cómo pasa lo respondido al formulario?** → Un `ScheduledPaymentWizardPrefill` nuevo en el editor (no el `ScheduledPaymentPrefill` de «desde un registro»), y el formulario abierto así pregunta antes de descartar.
Por qué: el de registro no lleva frecuencia, día, suscripción ni aviso, y además quita el tope de fecha mínima. Alternativa descartada: ampliar el de registro (tocaría los caminos que el encargo pide no tocar).

**D9 · ¿Se recuerda «Usar formulario»?** → No.
Por qué: el encargo lo deja opcional y recordarlo pediría una preferencia nueva.

**D10 · ¿Permiso de notificaciones?** → Al crear, solo si eligió aviso, con la misma hoja que el formulario (`NotificationPrimerMoments`).
Por qué: el formulario la pide al guardar un pago nuevo; preguntarla tras «No, gracias» no tiene sentido.

**D11 · ¿Pruebas de interfaz existentes que crean por el formulario?** → Pasan por «Usar formulario» (seis clases, cambio de dos líneas), como hizo el presupuesto.
Por qué: el cambio de comportamiento es justo ese. El vídeo del tutorial (`TutorialVideoRecordingUITests`, fuera del CI) queda anotado en «Encontrado».

**D12 · ¿Primeros pasos?** → No cambia; solo se hacen reusables (estáticos) los textos de tipo, nombre propuesto y ejemplos de `FirstScheduledPaymentFlowView`.
