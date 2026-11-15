---
id: 2026-11-14-texto-presupuesto-pasado
status: done
priority: medium
area: budgets
created: 2026-11-14
updated: 2026-11-14
source: encargo 2026-11-14-texto-presupuesto-pasado (decisión de Jürgen del 14-nov, mascota 7 de 7, opción A)
---
# Texto de presupuesto pasado: dar el dato y ofrecer ajustar el límite

Antes: «Pasaste tu presupuesto, ¡el próximo período será mejor!» en la fila y en el detalle. Consolaba sin dato ni
salida.

## Qué cambia para el usuario

- **Detalle del presupuesto pasado:** «Te pasaste por S/ 2,917.00. ¿Ajustamos el límite?» y un botón «Ajustar límite»
  que abre la edición del presupuesto.
- **Fila de Planificación:** desaparece la línea de consuelo. El dato ya estaba arriba («Te pasaste por S/ 2,917.00»)
  y repetirlo era ruido; la fila entera es un botón, así que la acción vive en el detalle.

## Hecho

- Claves `budgets.exceeded.overByAdjust %@` y `budgets.exceeded.adjustLimit` en los 16 idiomas; retirada
  `budgets.exceeded.encouragement`. El español es el mismo en es, es-419, es-AR y es-ES (sin vosotros ni voseo: no hace
  falta).
- Test `YalaTests/PresupuestoPasado/PresupuestoPasadoTextoTests`: 16 idiomas, un `%@` exacto, clave vieja ausente.
- Probado en el simulador (iPhone 17 Pro, semilla `-uitest-seed-budget-states`): texto con monto y el botón abre
  «Editar presupuesto».

## Decidido sin consultar

- La fila no repite el monto: ya lo muestra su cabecera.
- Se mantiene el corazón y el fondo rosa de la nota del detalle: el encargo cambia el texto, no el componente.

## Pendiente

- Prueba en el iPhone 14: Device MCP estaba duplicando otro iPhone y no se pudo conducir. Guion: Planificación ›
  Presupuestos › mes con un presupuesto pasado › abrirlo › bajar hasta la nota › «Ajustar límite» abre la edición.
