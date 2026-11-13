---
name: el-iphone-14-lo-ve-tambien-la-otra-maquina
description: El iPhone 14 se conduce desde la Mini y la Max a la vez (devicectl y Device MCP por red); antes de probar, mira si la otra sesión de Yala lo usa
metadata:
  type: feedback
---

El iPhone 14 va por cable a una máquina, pero la sesión de Yala de la OTRA máquina lo alcanza por red con `devicectl`
y Device MCP. El 13-nov, la sesión de la Mini («adopt a medias») desinstaló mi build a los 3 minutos de ponerla,
instaló la suya, entró con Google y mató la app a mitad del adopt. Yo tomé ese estado por un bug nuevo y saqué
capturas que no valían. Jürgen lo sospechó antes que yo («mira si la sesión de la Mini provocó eso»).

**Why:** que el `toca:` de dos encargos no se cruce no basta: los dos pueden necesitar el mismo teléfono físico.

**How to apply:** antes de instalar en el iPhone 14 y ante un estado inesperado (app abierta en otra cuenta, otra
build), mira el transcript de la otra sesión de Yala (`ssh mini` + jsonl, filtrando tool_use con `00008110`). Si
la otra también lo usa, pregúntale a Jürgen quién va primero (el 13-nov eligió «primero la Mini») y avísale a la otra
con `decirle`. Ver [[segundo-simulador-en-la-max]], [[iphone-14-libre-para-pruebas]].
