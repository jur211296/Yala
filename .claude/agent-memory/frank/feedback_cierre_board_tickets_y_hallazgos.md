---
name: cierre-board-tickets-y-hallazgos
description: Mandato de Jürgen (2026-09-06) para TODO cierre — docs/TICKETS.md al día con el disco, y cada bug o decisión que salga de camino lleva ticket propio; el hallazgo se BUSCA antes de escribirlo, que ya dupliqué uno.
metadata:
  type: feedback
---

**En `/cerrar-total` —y en todo cierre— el board no basta: `docs/TICKETS.md` tiene que quedar al día,
con el índice cuadrando con el disco y los conteos correctos. Y todo bug o decisión que aparezca de
camino lleva ticket propio ANTES de cerrar.**

**Why:** mandato de Jürgen del 2026-09-06, dado justo cuando yo iba a cerrar el KPI de Balance
dejando dos hallazgos —una decisión de producto sobre la coherencia entre pestañas y un límite con
dos cuentas seleccionadas— **solo** en el cuerpo del PR y en el ticket que estaba cerrando. Sus
palabras: «no los dejes solo en ESTADO ni en el cuerpo del PR». Un hallazgo dentro del PR de otra
cosa no se busca ni se prioriza: cuando el PR se mergea, deja de ser un sitio donde nadie mira. Y un
índice que no cuadra con el disco es peor que no tenerlo, porque se consulta creyendo que es cierto.

**How to apply:**

- **El índice es una afirmación verificable, así que se comprueba, no se edita a ojo.** Cuenta los
  `.md` de cada carpeta de `tickets/` y cruza cada fila del índice contra el fichero real: el
  `status` del índice tiene que ser el nombre de la carpeta donde está hoy. Mover un ticket de
  carpeta y no tocar el índice deja drift silencioso.
- **El conteo del encabezado (`## Index (N)`) entra en la comprobación.** Es lo primero que alguien
  lee y lo último que alguien actualiza.
- **Un hallazgo por ticket.** Si de un trabajo salen tres cosas —una decisión de producto, un bug
  preexistente y una deuda—, son tres ficheros en `tickets/`, no tres párrafos en el PR que estoy
  cerrando. El ticket del trabajo enlaza a ellos.
- **Antes de escribir el ticket del hallazgo, BÚSCALO. Ya existía.** El 2026-09-09, capturando ideas
  de Jürgen, medí que el `commit-msg` de ADR-013 no corre en Yala, lo escribí como ticket nuevo y lo
  mergeé. Ya había uno desde el 8-sep —`el-hook-que-prohibe-atribuir-a-una-ia-no-corre-en-este-repo`,
  **high**, con la causa, cuatro caminos y su AC— y encima el `docs/ESTADO.md` lo citaba como bloqueo
  abierto. Lo vi al reescribir ese mismo ESTADO en el cierre, y tuve que retirar mi duplicado.
  **La causa es de método, y es la que hay que recordar:** hice la búsqueda de duplicados para las
  cinco ideas del encargo y **no** para lo que salió de camino, como si un hallazgo naciera en
  terreno virgen por ser mío. El grep cuesta lo mismo en los dos casos. Búscalo por el **síntoma**
  —«commit-msg», «trailer», «hook»— y no por el slug que tú le pondrías: los dos ids no se parecen
  en nada. Y si un documento vivo lo menciona, `docs/ESTADO.md` es el primer sitio donde mirar.
- **Distingue qué clase de ticket es.** Una decisión pendiente de Jürgen y un bug no se priorizan
  igual ni se cierran igual; el ticket lo dice en su cuerpo, no lo deja implícito.
- Esto **no** sustituye a escribir el hallazgo en el PR: el PR sigue contando qué cambió y qué queda.
  Lo que cambia es que además existe donde se busca el trabajo pendiente.

Relacionado: [[el-tablero-antes-que-el-bug]] — ya prefería sanear el board antes de atacar
producción; esto lo convierte en parte obligatoria del cierre. Y [[la-premisa-del-encargo-tambien-se-mide]],
porque el índice es exactamente el tipo de documento que envejece sin avisar.
