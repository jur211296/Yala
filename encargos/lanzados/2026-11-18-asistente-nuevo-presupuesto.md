Yala
# Nuevo presupuesto por pasos con preguntas y opción «Prefiero formulario» (y patrón compartido de asistentes)
---
toca: Yala/App/Views/Shared/AsistenteCreacion/,Yala/App/Views/Planning/BudgetsListView.swift,Yala/App/Views/Planning/PlanningView.swift,Yala/App/Views/Planning/BudgetEditorView.swift,Yala/App/Views/Onboarding/PrimerosPasos/FirstBudgetFlowView.swift,Yala/Resources/de.lproj/AsistentePresupuesto.strings,Yala/Resources/en-GB.lproj/AsistentePresupuesto.strings,Yala/Resources/en.lproj/AsistentePresupuesto.strings,Yala/Resources/es-419.lproj/AsistentePresupuesto.strings,Yala/Resources/es-AR.lproj/AsistentePresupuesto.strings,Yala/Resources/es-ES.lproj/AsistentePresupuesto.strings,Yala/Resources/es.lproj/AsistentePresupuesto.strings,Yala/Resources/fr.lproj/AsistentePresupuesto.strings,Yala/Resources/it.lproj/AsistentePresupuesto.strings,Yala/Resources/ja.lproj/AsistentePresupuesto.strings,Yala/Resources/nl.lproj/AsistentePresupuesto.strings,Yala/Resources/pl.lproj/AsistentePresupuesto.strings,Yala/Resources/pt-BR.lproj/AsistentePresupuesto.strings,Yala/Resources/pt-PT.lproj/AsistentePresupuesto.strings,Yala/Resources/pt.lproj/AsistentePresupuesto.strings,Yala/Resources/zh-Hans.lproj/AsistentePresupuesto.strings,YalaTests/AsistentePresupuesto/,YalaUITests/AsistentePresupuesto/,tickets/done/2026-11-17-asistente-nuevo-presupuesto.md
esfuerzo: high
cierre: cierra-sola
---

Pedido de Jürgen del 17-nov (20:51 Lima), con captura de Planificación. Base 2.3, un PR. Sesión enfocada solo en esta vista (una vista por sesión). Es parte de una serie: presupuesto (crea el patrón), pago planificado, grupo, cuenta y favorito.

## Qué quiere
- Al tocar crear, en vez del formulario, se abre un **proceso por pasos con preguntas** (una pregunta clara por pantalla, en lenguaje simple, con valores sugeridos y progreso arriba).
- Arriba, siempre visible, una opción para quien prefiere lo de siempre, por ejemplo «Prefiero formulario» (elige el texto más claro y corto). Al tocarla se muestra el formulario actual, con lo ya respondido pasado al formulario.
- Al final, un resumen breve y el botón de crear. Nunca un botón debajo del otro. X nativa para salir; si ya respondió algo, pregunta antes de descartar, igual que el formulario.
- No hace falta recordar la elección «Prefiero formulario» entre usos salvo que sea trivial; si lo haces, que se pueda volver al asistente.

## Esta vista
- Tocar «+ Nuevo presupuesto» en Planificación › Presupuestos. Hoy abre el formulario `BudgetEditorView`. Ya existe un flujo por pasos de primeros pasos (`FirstBudgetFlowView`, abierto desde `Panel/PrimerosPasosPlanningPresentations.swift`): reúsalo o extráelo, sin romper los primeros pasos.
- **Esta sesión crea el patrón compartido** en `Yala/App/Views/Shared/AsistenteCreacion/` (contenedor de pasos con progreso arriba, pregunta por pantalla, Atrás/Siguiente, X nativa, y la opción «Prefiero formulario» arriba), documentado para que las sesiones de pago planificado, grupo, cuenta y favorito lo reusen tal cual. Sigue la referencia de UI por pasos de `docs/design/referencias/2026-09-15-flujo-por-pasos-cancelar-suscripcion.jpg`.
- Abrir el presupuesto existente para editarlo sigue yendo al formulario.

## Cómo entregar
- Tests de la lógica de pasos y del paso a formulario con lo respondido en `YalaTests/AsistentePresupuesto/`; prueba de UI del recorrido completo y de «Prefiero formulario» en `YalaUITests/AsistentePresupuesto/`.
- Capturas de cada paso y del formulario (iPhone 17 y SE, también con letra grande, claro y oscuro, y iPad).
- Puedes usar un segundo simulador en la Max además del de otra sesión, o el iPhone 14 por DeviceMCP. En la Mini, solo uno.
- Entregable visual: artifact de Claude con el recorrido paso a paso y el antes y después.
- Commits y PR sin firma de IA. Toca solo lo declarado; lo menor, con la opción recomendada, anotado en «Decidido sin consultar». Textos nuevos en `AsistentePresupuesto.strings` de cada `.lproj`, nunca en `Localizable.strings`.
- Lo vital, según el modo fijado al arrancar (semi: pregunta y espera viva; nocturno: checkpoint recuperable y card «Espera decisión», sin mergear lo incompleto).
- Cierre: completo y CI verde, `/cerrar-total` con «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada», y el link del artifact.

## Paso 0 — decisiones (sesión nocturna, auto-contestadas)

| Pregunta | Decisión | Por qué |
|---|---|---|
| ¿Choca con la sesión que tocaba `BudgetsListView`? | No: su PR (unslop de Registros, Grupos y Presupuestos) ya está mergeado. | Medido con `gh pr list`. El aviso de `lanzar-sesion` era viejo. |
| ¿Reusar `FirstBudgetFlowView` o extraerlo? | Se reusan sus piezas (`FirstBudgetFlowLogic`: nombre propuesto y avisos; `TutorialSelectableTile`; `TutorialPlanningMath`; `FirstBudgetCardPreview` en el resumen) y Primeros pasos no se toca. | Primeros pasos es un chat con la tarjeta llenándose y página de intro; el asistente es otra forma (referencia del 15-sep). Extraer su vista arriesgaba romper el onboarding sin ganar nada. |
| ¿Qué preguntas? | 6 a 8 pantallas: ¿Qué gastos cuenta? → (¿Cuáles?) → ¿Cada cuánto? → (¿Entre qué fechas?) → ¿Cuánto como máximo? → ¿Cómo lo llamamos? → ¿Te avisamos? → Revisa y crea. | Lo obligatorio más lo que más cambia el número. Cuentas, etiquetas, necesidad, gastos de grupo, widget y subcategorías sueltas siguen en el formulario con sus valores de siempre. |
| ¿Elegir avanza solo? | No: elegir marca y «Siguiente» avanza; cada pregunta llega con el valor sugerido ya marcado. | Así el mismo botón sirve en todas las pantallas y lo marcado viaja al formulario. |
| Texto de la salida al formulario | «Usar formulario», arriba a la derecha en la barra. | Más corto que «Prefiero formulario» y dice la acción. |
| Atrás / Siguiente | En una fila abajo: Atrás como círculo con flecha y «Siguiente» ancho al lado; en el resumen, «Crear presupuesto». Nunca uno debajo del otro, a ningún tamaño de letra. | Lo pide el encargo; el círculo cabe también a AX5. |
| ¿Recordar «Usar formulario»? | No. | El encargo lo deja opcional; no es trivial hacerlo bien (volver al asistente) y nadie lo pidió. |
| Lo respondido, ¿dónde vive? | En quien presenta la hoja (`BudgetsListView`), y se tira al cerrarla. | Regla de `swiftui-ds.md`: el contenido de una hoja puede rehacerse y perder su `@State`. |
| X con respuestas | Pregunta «¿Descartar este presupuesto?» (Descartar / Seguir), también al bajar la hoja. | Molde de los formularios de Grupos. |
| El formulario hoy cierra sin preguntar | Abierto desde el asistente con respuestas, pregunta igual; abierto a mano o para editar, sin cambios. | El encargo da por hecho que el formulario pregunta y no lo hace (inventario del 15-nov). Lo mínimo coherente es no tirar lo respondido. |
| Sugerencias de tope | Lo gastado el período anterior con lo elegido, redondeado, y un 10 % y un 20 % menos. Sin datos, sin chips. | «Valores sugeridos» con el gasto real, como Primeros pasos. |
| Permiso de avisos | Al crear con aviso, como Primeros pasos (`TutorialPermissionMoments.remindMeChosen`) y enciende el interruptor general si queda permitido. | Mismo comportamiento que el otro flujo guiado. |
| Editar | Sigue abriendo el formulario. | Lo dice el encargo. |
| Documentación del patrón | Comentario de cabecera largo en `AsistenteCreacionView.swift` (cómo se usa, paso a paso) en vez de un README. | Un `.md` dentro de `Yala/` entraría como recurso en el bundle por los grupos sincronizados. |
