---
id: 2026-11-17-asistente-nuevo-presupuesto
status: done
priority: medium
area: ux
created: 2026-11-17
updated: 2026-11-18
source: encargo 2026-11-18-asistente-nuevo-presupuesto (Jürgen, 17-nov 20:51 Lima, captura de Planificación)
---
# «Nuevo presupuesto» por pasos, con «Usar formulario» (y el patrón compartido de asistentes)

Jürgen (17-nov): al tocar crear, en vez del formulario, un proceso por pasos con una pregunta clara por pantalla,
valores sugeridos y progreso arriba; arriba y siempre a la vista, la salida al formulario de siempre con lo ya
respondido; al final un resumen breve y el botón de crear, nunca un botón debajo del otro. Primera vista de una serie
(presupuesto crea el patrón; después pago planificado, grupo, cuenta y favorito).

## Qué cambia para quien usa la app

- Planificación › Presupuestos › «Nuevo presupuesto» abre un asistente: ¿Qué gastos cuenta? → (¿Cuáles?) → ¿Cada cuánto
  se renueva? → (¿Entre qué fechas?) → ¿Cuánto como máximo? → ¿Cómo lo llamamos? → ¿Te avisamos? → ¿Lo creamos así?
- Cada pregunta llega con lo sugerido ya marcado; el tope ofrece lo gastado el período pasado, un 10 % y un 20 % menos.
- «Usar formulario» arriba a la derecha en todas las preguntas: abre el formulario de siempre con lo respondido.
- En el resumen, cada respuesta se toca para cambiarla y «Siguiente» vuelve al resumen.
- La X (y bajar la hoja), con algo respondido, pregunta antes de descartar; también el formulario abierto desde el
  asistente.
- Editar un presupuesto sigue abriendo el formulario. Primeros pasos no cambia.

## Paso 0 y «Decidido sin consultar»

En el encargo (`encargos/lanzados/2026-11-18-asistente-nuevo-presupuesto.md`, viaja al PR). Resumen:

- Texto de la salida: «Usar formulario» (más corto que «Prefiero formulario» y dice la acción).
- Elegir marca y «Siguiente» avanza (no avanza solo al tocar): así lo marcado viaja al formulario.
- No se recuerda la elección de usar el formulario.
- Lo que no pregunta (cuentas, etiquetas, necesidad, gastos de grupo, widget, subcategorías sueltas) queda como en el
  formulario recién abierto.
- El encargo daba por hecho que el formulario ya preguntaba antes de descartar: no lo hacía. Ahora pregunta solo
  cuando llega con lo respondido en el asistente.
- Seis pruebas de interfaz que creaban un presupuesto por el formulario pasan antes por «Usar formulario» (helper
  `abrirFormularioDeNuevoPresupuesto`).

## Para la siguiente sesión de la serie

El patrón vive en `Yala/App/Views/Shared/AsistenteCreacion/`; la cabecera de `AsistenteCreacionView.swift` dice cómo
montar un asistente nuevo en cinco pasos, y `Presupuesto/` es el molde.

## Encontrado (sin tocar)

- Ajustes › Presupuestos también crea con el formulario (`BudgetsFavoritesSettingsView`); no estaba en el encargo.
- El vídeo del tutorial «Crear presupuestos» enseña el formulario: queda viejo (se graba con
  `TutorialVideoRecordingUITests`, que no corre en el CI).
