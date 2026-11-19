---
id: 2026-11-17-asistente-nuevo-grupo
status: done
priority: medium
area: ux
created: 2026-11-17
updated: 2026-11-18
source: encargo 2026-11-18-asistente-nuevo-grupo (Jürgen, 17-nov 20:51 Lima, captura de Planificación)
---
# «Nuevo grupo» por pasos, con «Usar formulario»

Jürgen (17-nov): al tocar crear, en vez del formulario, un proceso por pasos con una pregunta clara por pantalla,
valores sugeridos y progreso arriba; arriba y siempre a la vista, la salida al formulario de siempre con lo ya
respondido; al final un resumen breve y el botón de crear, nunca un botón debajo del otro. Tercera vista de la serie
(presupuesto creó el patrón; faltan pago planificado, cuenta y favorito).

## Qué cambia para quien usa la app

- Grupos › «Nuevo grupo» (barra, fila sin grupos, botón + y «Crear grupo» desde un gasto) abre un asistente:
  ¿Cómo se llama el grupo? → ¿Con qué icono lo reconoces? → ¿Cómo suelen dividir los gastos? → ¿Juntamos las deudas
  para que haya menos pagos? → ¿Cómo ven lo que se deben? → ¿Lo creamos así?
- El nombre trae ideas (Viaje, Casa, Pareja, Amigos, Trabajo) que también proponen su icono, y «Traer un grupo de
  Splitwise o Tricount» sigue en esa primera pregunta.
- Lo demás llega con lo de un grupo nuevo ya marcado (partes iguales, menos pagos, cada gasto en su moneda).
- «Usar formulario» arriba a la derecha en todas las preguntas: abre el formulario de siempre con lo respondido, y
  «Más opciones» desplegadas si alguna no es la de siempre.
- En el resumen, cada respuesta (y el icono) se toca para cambiarla y «Siguiente» vuelve al resumen.
- La X y bajar la hoja, con un nombre escrito o una pregunta pasada, preguntan antes de descartar; también el
  formulario abierto desde el asistente.
- Al crear pasa lo de siempre: la hoja de invitar o, si se venía a apuntar un gasto, el gasto.
- Editar un grupo sigue en el formulario. El primer grupo desde la bienvenida tampoco cambia.

## Paso 0 y «Decidido sin consultar»

En el encargo (`encargos/lanzados/2026-11-18-asistente-nuevo-grupo.md`, viaja al PR). Resumen:

- Texto de la salida: «Usar formulario», el del contenedor compartido (no se modifica el patrón).
- Un nombre escrito cuenta como respuesta para preguntar antes de cerrar (el presupuesto solo cuenta lo pasado con
  «Siguiente»).
- Lo respondido llega al formulario por el entorno (`\.groupFormPrefill`) para no cambiar la llamada de la pestaña,
  que fija un source-scan.
- No se recuerda la elección de usar el formulario.
- Seis pruebas de interfaz que abrían el formulario de crear pasan antes por «Usar formulario» (helper
  `pasarDelAsistenteAlFormularioDeGrupo`), y el conteo de construcciones de `GroupsMembershipClient` sube a 10.

## Pendiente

- La entrada del primer grupo desde la bienvenida (`ContentView`) sigue en el formulario: lleva el nombre de la
  persona y el alta, y no estaba declarada.
- El patrón compartido no se tocó; no le faltó nada para grupos.
