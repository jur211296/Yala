# «Empezar desde cero» en Restaurar promete sin datos previos y los deja bajando

## Contexto
Cola autónoma Jürgen (bypass). Tras #154 (403 de infra ya no sella el canal de Grupos), toca este high de la cola del rediseño: Welcome → Restaurar desde iCloud → «Empezar desde cero» dice «sin tus datos previos» y el espejo de iCloud sigue importando el corpus por debajo.

Es la misma familia que el bug del paso 4 (`welcome-private-fresh-start-skips-icloud-check`), por otra puerta. Ticket: `restore-start-fresh-keeps-the-imported-corpus` (backlog, high).

Avisos al bot dueño (Frank): POSTea al webhook local de la Mini (URL y key en fichero local, no en git; no las escribas en el repo) cuando:
  (1) necesitas una decisión de producto o de acceso de Jürgen;
  (2) abriste el PR o dejaste preview/artifact listo;
  (3) terminaste el ticket y vas a /cerrar-total — incluye en el aviso un resumen corto de cierre en lenguaje de usuario (qué se hizo), no solo «cerré»;
  (4) acabaste un tramo y no tienes siguiente paso claro (aunque no haya pregunta formal) — una vez, no en bucle.
NO avises por: un test rojo que vas a reclasificar, un build que vas a reintentar, ni ruido de CI advisory.

MODO AUTÓNOMO HASTA TERMINAR: gate, commit, docs/board, actualizar `docs/TICKETS.md` (índice al día), merge y /cerrar-total sin preguntar si corre el gate o el commit. Bugs/decisiones nuevas → ticket propio antes de cerrar. Solo parar ante decisión/acceso real.

## Que se pide
1. Leer el ticket entero y contrastar con `welcome-private-fresh-start-skips-icloud-check` / `welcome-start-fresh-wipes-before-ask` (misma familia, otra puerta).
2. Si hay corpus, «Empezar desde cero» debe **borrar** (segunda confirmación: zona iCloud + lo importado) — o no ofrecerlo desde aquí y devolver a la puerta. Tras onboarding + sync, cero datos previos.
3. El mismo recorrido desde «Activar Yala completo → privado → Restaurar» deja la sesión de grupos intacta (restricción del paso 8: wipeAllUserData no debe mandar a solo-grupos).
4. Tests + mutantes; PR a `2.1`; board + `docs/TICKETS.md`; device-QA a `tickets/qa/` si el sim no basta; `/cerrar-total`.

## Que NO hay que tocar
marketing/. Otros tickets de la cola (apple-id-change, remote-wipe, paso 13). El high de producto `cloud-signout-collapses-every-groups-transient-into-permanent` (espera decisión de Jürgen). Ampliar wipe fuera de este botón.

## Como se sabe que esta bien
Criterios del ticket; tras «Empezar desde cero» no reaparecen datos previos; grupos intactos en el recorrido Activar Yala completo; PR mergeado; `/cerrar-total`.

---

## Paso 0 — decisiones (resueltas en autónomo, bypass · 2026-09-14)

El árbol completo, con lo que se midió para contestar cada nodo, vive en la sección «Paso 0» del
propio ticket (`tickets/in-progress/restore-start-fresh-keeps-the-imported-corpus.md`). Resumen de
lo que queda decidido, para que se pueda discutir en el PR sin abrir el diff:

1. **«Empezar desde cero» devuelve a la puerta del paso 4** (`WelcomePrivateICloudGateView`) en vez
   de construir fases nuevas en la pantalla de restaurar. El ticket ofrecía las dos; la puerta ya
   hace las cinco cosas que hacen falta (sonda a CloudKit, cifras, doble confirmación, arm kill-safe,
   testigo del espejo tardío) y **mide algo que la pantalla de restaurar no puede medir**: su resumen
   cuenta filas del store, así que un import que no cupo en el tope de 90 s sale de ahí como
   «no encontramos tus datos» con el corpus intacto arriba.
2. **El `confirmationDialog` de la vista se queda**, copy y claves incluidos: la vista tiene dos
   consumidores y el segundo no cambia en este PR.
3. **La limpieza de residuales sale del callback** — regla de `welcome-start-fresh-wipes-before-ask`:
   se limpia cuando se borra, no cuando se pregunta. Aquel ticket había exceptuado este call-site con
   un motivo que este cambio invalida (ahora sí hay dónde cancelar).
4. **`deviceCorpusGate` no se toca.** El primer diseño le quitaba el guard del mount; el repo tenía
   medido que eso vacía el iCloud de la persona en todos sus dispositivos (el borrado por filas con
   el espejo puesto exporta los deletes).
5. **Se cierra el alert espurio de fresh-start** que este cambio habría hecho frecuente: el borrado
   de la puerta no bajaba los dos flags de «hay datos», y desde Restaurar el mount ya no relanza.
6. **La activación de Yala completo queda fuera, con ticket `high` propio**
   (`activation-restore-start-fresh-keeps-the-imported-rows`): ahí el borrado es de zona por la
   restricción del paso 8, y cerrarlo pide un borrador que no existe. El AC nº2 del ticket —grupos
   intactos en ese recorrido— se cumple igual, porque ese cableado no se toca.
