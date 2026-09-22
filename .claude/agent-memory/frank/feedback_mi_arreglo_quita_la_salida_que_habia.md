---
name: mi-arreglo-quita-la-salida-que-habia
description: Al cerrar un camino de abuso, enumera a quién le servía de SALIDA — un callejón preexistente y tolerable se vuelve trampa cuando le quitas la puerta de al lado
metadata:
  type: feedback
---

Antes de cerrar un camino porque alguien puede abusar de él, **enumera quién lo usaba para salir de
algún sitio**. Un callejón que hoy se tolera puede estar tolerándose precisamente porque existe otra
puerta — y si la que cierras es esa otra puerta, el callejón pasa de incómodo a trampa.

**Why:** el 2026-09-21, en `restore-session-window-has-no-reachable-ceiling`, cerré el recorrido
«Empezar desde cero» → «Volver» → Restaurar para que dejara de estrenar la ventana del guard de
frontera de cuenta. Medí bien el abuso y no medí la otra mitad. Ese mismo gesto era **la única
salida** de un callejón que ya existía: con la ventana caducada y el dueño todavía en pantalla,
`noteRestoreStarted` no entraba ni al estreno (`restoreStartedAt != nil`) ni al re-ancla
(`currentFlow != nil`), así que ningún «volver a buscar» la resucitaba. Antes de mi cambio, quien se
atascaba descartaba, volvía y estrenaba limpio. Después, no: un import de doce minutos dejaba al
dueño, pasados los diez, con la app diciéndole que sus propios datos eran de otra persona y sin más
salida que matar la app. Es **el mismo defecto que la review había tumbado el día anterior** en el
techo de cadena, entrando por la caducidad en vez de por un presupuesto: no frena a quien quiere
saltárselo y sí castiga a quien no.

**How to apply:**

- Al cerrar un camino, escribe la lista de **estados desde los que ese camino era la salida**. Si
  alguno queda sin otra puerta, el fix no está terminado: la salida nueva entra en el mismo cambio.
- El síntoma que lo delata al leer una lente: «la única salida fiable del dueño legítimo es el
  recorrido que el ticket llama abuso». Si lees eso, para.
- **Y mide el alcance de la salida nueva con su caso hermano.** Mi primer rescate trataba «ventana
  agotada» como «apagada» para cualquiera, y eso deshacía el PR del día anterior: el ciclo
  salir-volver suelta la titularidad en cada vuelta, así que pasaba a estrenar sin necesitar descarga
  viva. Lo cantó su propio test, en rojo. El rescate correcto iba acotado a `currentFlow != nil`:
  quien SALIÓ ya tiene el re-ancla, que le exige una descarga real; quien sigue DENTRO no tiene
  ninguna otra y su gesto es explícito.

Relacionado: [[feedback_el_techo_que_se_resetea_no_es_un_techo]],
[[feedback_la_correccion_de_la_lente_reintroduce_el_bug]],
[[feedback_al_quitar_un_apagado_incondicional_busca_quien_lo_usaba]].
