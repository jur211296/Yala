---
name: el-mutante-tiene-que-caer-por-su-caso
description: Un banco donde TODO está rojo mata todos los mutantes; exige que cada mutante tumbe el caso de su regla, no «algún rojo».
metadata:
  type: feedback
---

Un mutante «muerto» solo cuenta si cae el caso de SU regla. Comprobarlo por nombre de caso, no por «hubo algún rojo».

**Why:** el 2026-10-21, en el banco SQL de `g22_01` (set_member_role), la primera corrida dio 33 rojos y los cuatro
mutantes «muertos»: todas las llamadas salían sin sesión porque el `set_config` de los claims iba dentro de un
`select … where false` que el planificador no evaluaba. Con el banco roto entero, cualquier mutante muere.

**How to apply:** al escribir un banco con mutantes, el script de mutantes recibe el nombre del caso que tiene que caer
y lo busca en la salida (`grep "✗ <caso>"`). Y antes de mirar los mutantes, la batería real tiene que estar verde.
Relacionado: [[el-oraculo-del-mutante-es-el-efecto-que-produce]], [[la-asercion-que-no-puede-fallar]].
