---
id: 2026-11-17-asistente-nuevo-pago-planificado
status: done
priority: medium
area: ux
created: 2026-11-17
updated: 2026-11-18
source: encargo 2026-11-18-asistente-nuevo-pago-planificado (Jürgen, 17-nov 20:51 Lima, captura de Planificación)
---
# «Nuevo pago planificado» por pasos, con «Usar formulario»

Jürgen (17-nov): al tocar crear, en vez del formulario, un proceso por pasos con una pregunta clara por pantalla,
valores sugeridos y progreso arriba; arriba y siempre a la vista, la salida al formulario de siempre con lo ya
respondido; al final un resumen breve y el botón de crear, nunca un botón debajo del otro. Segunda vista de la serie
(presupuesto creó el patrón; siguen grupo, cuenta y favorito).

## Qué cambia para quien usa la app

- Planificación › Pagos planificados › «Nuevo pago planificado» (y el «+» flotante) abre un asistente: ¿Qué pagas cada
  cierto tiempo? → ¿Cómo lo llamamos? → ¿Cuánto pagas cada vez? → ¿Cada cuánto toca pagar? → ¿Qué día? → ¿Te avisamos?
  → ¿Lo creamos así?
- Lo sugerido llega marcado: cada mes, el día de hoy, aviso 3 días antes, y el nombre propuesto por el tipo con tres
  ejemplos. El tipo y el monto no llegan elegidos.
- «Usar formulario» arriba a la derecha en todas las preguntas: abre el formulario de siempre con lo respondido.
- En el resumen, cada respuesta se toca para cambiarla y «Siguiente» vuelve al resumen; el botón dice «Crear pago».
- La X (y bajar la hoja), con algo respondido, pregunta antes de descartar; también el formulario abierto desde el
  asistente.
- Editar un pago, crearlo desde un registro («Reusar»), desde Nuevo registro o desde una propuesta de pago recurrente
  siguen abriendo el formulario. Primeros pasos no cambia.

## Paso 0 y «Decidido sin consultar»

En el encargo (`encargos/lanzados/2026-11-18-asistente-nuevo-pago-planificado.md`, viaja al PR). Resumen:

- Texto de la salida: «Usar formulario», el del contenedor compartido (no se modifica el patrón).
- Solo gasto: un cobro planificado se crea con «Usar formulario».
- La cuenta es la última usada, como el formulario; se ve en la tarjeta del resumen.
- Ficheros nuevos en `Yala/App/Views/Planning/AsistentePagoPlanificado/`.
- No se recuerda la elección de usar el formulario.
- El permiso de notificaciones se pide al crear solo si se eligió un aviso.
- Seis pruebas de interfaz que creaban un pago por el formulario pasan antes por «Usar formulario» (helper
  `abrirFormularioDeNuevoPago`).

## Pendiente del patrón compartido

- Los textos del contenedor (`asistente.*`) viven en `AsistentePresupuesto.strings` y se leen con
  `AsistenteCreacionTexto`, que solo mira esa tabla: cada asistente nuevo necesita su propia función de lectura para su
  tabla. Si la serie sigue, convendría que el contenedor leyera sus claves de una tabla propia (`AsistenteCreacion`).

## Encontrado (sin tocar)

- El vídeo del tutorial de pagos planificados (`TutorialVideoRecordingUITests`, fuera del CI) enseña el formulario:
  queda viejo.
- Ajustes no crea pagos planificados: no hay otra entrada a «Nuevo pago planificado» aparte de la pestaña (medido con
  un grep de `ScheduledPaymentEditorView(`).
