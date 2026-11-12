---
name: un-flag-de-estado-tiene-varios-escritores
description: Antes de reinterpretar un booleano de estado («isActive = pausado»), enumera quién lo escribe; el lote 10 casi borra lo pagado de un pago completado.
metadata:
  type: feedback
---

Antes de dar a un flag un significado de usuario («inactivo = pausado») en un cálculo o en un rótulo, busca TODOS
sus escritores (`grep -n "isActive = false"`), no solo el interruptor de la pantalla.

**Why:** lote 10 (2026-10-14). Para cuadrar Pagado + Pendiente con el total, saqué de las dos cifras los pagos con
`isActive == false` y la fila pasó a decir «Inactivo». La review de cálculo lo cazó: `advanceToNextDueDate` también
apaga un pago de una sola vez al aprobarlo y uno recurrente tras su última fecha, y el puente de grupos pausa los
suyos. Un pago de una sola vez ya pagado habría desaparecido de «Pagado» y su fila diría «Inactivo». Familia de
[[el-escritor-que-imagina-el-ticket]] y [[el-estado-compartido-no-es-testigo-de-su-rama]].

**How to apply:** si el flag mezcla significados, decide por el dato que sí distingue (aquí: ¿hay pago registrado
para esa fecha?). Lo pagado cuenta siempre; lo pendiente, solo si está activo.
