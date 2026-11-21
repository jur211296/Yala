---
id: 2026-11-21-reusar-registro-gastos-de-grupo
status: done
priority: medium
area: "planificacion, pagos-planificados, grupos"
created: 2026-11-21
updated: 2026-11-21
source: "Jürgen, 21-nov 07:17 y 07:21 Lima, TestFlight 2.3: «Reusar» no deja elegir gastos de grupo; el asistente nunca pregunta si es compartido; en el formulario el interruptor está abajo y lo obligatorio arriba"
---

# Pago planificado compartido completo: «Reusar» con gastos de grupo, asistente que pregunta y formulario claro

## Qué pidió Jürgen

1. «Reusar» (Elige un registro) tiene que aceptar gastos de grupo y crearlos como pago planificado compartido de ese
   grupo, y probar a fondo que «Reusar» funciona.
2. El asistente de «Nuevo pago planificado» completo: si hay grupos activos, preguntar si es compartido (grupo, moneda y
   división) y cubrir las opciones avanzadas; el resumen enseña todo y cada respuesta se puede cambiar.
3. En el formulario, encender «¿Es un gasto compartido?» no puede dejar campos obligatorios escondidos.

## Qué cambió para quien usa la app

- **«Elige un registro» trae los gastos de grupo** con su chip (p. ej. «Luz Del Sur · Jurpi»). Elegir uno abre el
  formulario ya compartido con ese grupo: el total de la factura, la moneda y el reparto tal como estaba. No se guarda
  nada hasta tocar ✓. Si el grupo está archivado, ya no está o saliste de él, la fila sale apagada con una línea que lo
  dice. El pie de la hoja ya no dice que los gastos de grupo no salen.
- **El asistente pregunta si es compartido** (solo si tienes algún grupo en el que sigues activo) justo después del
  monto, y con un grupo elegido, «¿Cómo lo dividen?», con la división del grupo ya puesta y «Cambiar la división».
  Después del aviso, **«¿Algo más?»**: cuenta, descripción, etiquetas, fecha de fin y activo, todo ya puesto, así que
  «Siguiente» sigue de largo. El resumen enseña lo compartido y lo avanzado; cada fila lleva a su pregunta.
- **En el formulario**, «¿Es un gasto compartido?» va en su propia caja «Gasto compartido», y al encenderlo Grupo,
  Moneda y División aparecen justo debajo. Si falta algo al guardar, la pantalla baja a la fila, la tiñe y una línea dice
  qué falta. El selector de grupo ya no ofrece grupos de los que saliste.
- Una cuenta archivada de un registro no pasa al formulario: hay que elegir otra (antes el pago la usaba).

## Decidido

- Quién paga no se guarda en el pago planificado: se elige al registrar cada pago desde la Bandeja (tú por defecto).
  Decisión de Jürgen del 21-nov, opción A (t1872u): sin cambios en iCloud ni Supabase.
- El resto, en el Paso 0 del PR (D1-D10): qué fila de grupo entra, qué copia, cuándo sale apagada, sin buscar «parecidos»
  para un gasto de grupo, dónde pregunta el asistente lo compartido y lo avanzado, y dónde va el interruptor.

## Cómo se prueba

- Unit: `YalaTests/ReusarRegistroGrupos/` (qué entra, disponibilidad, reparto, prellenado, casos personales) y
  `YalaTests/AsistentePagoCompartido/` (pasos, creación, de la Bandeja al gasto de grupo con el monto real y el saldo,
  textos en 16 idiomas).
- XCUITest: `ReusarRegistroGruposUITests` (de punta a punta y el apagado con motivo) y `AsistentePagoCompartidoUITests`
  (asistente con grupo y formulario que dice qué falta). Fixture `-uitest-seed-reusar-grupo`.

## Queda para el iPhone

- Que el gasto registrado desde la Bandeja aparezca en el grupo para los dos miembros necesita dos cuentas reales con
  el canal de Grupos: el simulador no tiene sesión de nube. Guion en el PR.
