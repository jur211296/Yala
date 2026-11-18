---
id: 2026-11-17-asistente-nuevo-favorito
status: done
priority: medium
area: ux
created: 2026-11-17
updated: 2026-11-18
source: encargo 2026-11-18-asistente-nuevo-favorito (Jürgen, 17-nov 20:51 Lima, captura de Planificación)
---
# «Nuevo favorito» por pasos, con «Usar formulario»

Jürgen (17-nov): al tocar crear, en vez del formulario, un proceso por pasos con una pregunta clara por pantalla,
valores sugeridos y progreso arriba; arriba y siempre a la vista, la salida al formulario de siempre con lo ya
respondido; al final un resumen breve y el botón de crear, nunca un botón debajo del otro. Quinta vista de la serie
(presupuesto creó el patrón; pago planificado, grupo y cuenta van aparte).

## Qué cambia para quien usa la app

- Ajustes › Registros favoritos › «+» (o «Crear favorito» con la lista vacía) abre un asistente. Para un gasto o un
  ingreso: ¿Qué quieres guardar? → ¿En qué categoría va? → ¿Cómo lo llamamos? → ¿Cuánto pagas normalmente? → ¿Con qué
  cuenta pagas? → ¿Lo creamos así?
- Para una transferencia la categoría no sale, y la cuenta se pregunta dos veces: ¿De qué cuenta sale? y ¿A qué cuenta
  va? (sin ofrecer la de origen).
- Con «Solo gastos» no se pregunta el tipo: empieza en la categoría.
- Lo sugerido llega marcado: Gasto, «Sin categoría» (con las cuatro más recientes y «Otra categoría»), el nombre de la
  categoría elegida, la cuenta del último registro y, en una transferencia, la primera cuenta distinta del origen. El
  monto puede quedar vacío: se pone al usar el favorito.
- «Usar formulario» arriba a la derecha en todas las preguntas: abre el formulario de siempre con lo respondido (tipo,
  nombre, monto, categoría y cuentas).
- En el resumen, cada respuesta se toca para cambiarla; el botón dice «Crear favorito».
- La X (y bajar la hoja), con algo respondido, pregunta antes de descartar; también el formulario abierto desde el
  asistente.
- Editar un favorito y «Guardar como favorito» desde un registro siguen en el formulario.

## Paso 0 y «Decidido sin consultar»

En el encargo (`encargos/lanzados/2026-11-18-asistente-nuevo-favorito.md`, viaja al PR). Resumen:

- Texto de la salida: «Usar formulario», el del contenedor compartido (el encargo proponía «Prefiero formulario»; el
  contenedor no está en el alcance).
- Etiquetas, nota y naturaleza no se preguntan: quedan vacías, como en el formulario recién abierto.
- Ficheros nuevos en `Yala/App/Views/Favorites/AsistenteFavorito/`.
- No se recuerda la elección de usar el formulario.
- Tres pruebas de interfaz que creaban un favorito por el formulario pasan antes por «Usar formulario» (helper
  `abrirFormularioDeNuevoFavorito`).

## Pendiente del patrón compartido

- El navegador compartido (`AsistenteCreacionNavegador`) vuelve al resumen en cuanto la pregunta siguiente ya está
  contestada. Al pasar de gasto a transferencia desde el resumen, «¿A qué cuenta va?» aparece nueva pero detrás de
  «¿Cómo lo llamamos?», así que no se pregunta. Aquí se resuelve en la vista: el destino sugerido llega puesto y el
  resumen tiene su fila para cambiarlo. Si otro asistente tiene una pregunta nueva que no va justo detrás de la que se
  cambió, conviene que el navegador pregunte las nuevas antes de volver.
- Los textos del contenedor siguen en `AsistentePresupuesto.strings` (ya anotado en el ticket del pago planificado).

## Encontrado (sin tocar)

- El vídeo del tutorial de favoritos (`TutorialVideoRecordingUITests`, fuera del CI) enseña el formulario: el paso 1 ya
  pasa por «Usar formulario», pero el vídeo queda viejo.
- La lista de Favoritos en modo «elegir» (la estrella de Nuevo registro) también tiene «+», y abre el mismo asistente.
