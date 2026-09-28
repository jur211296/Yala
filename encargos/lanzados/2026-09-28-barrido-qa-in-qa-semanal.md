# Barrido semanal de tickets in-qa: dejar solo lo que Jürgen debe probar en iPhone

## Contexto
Cerró Cola A con PR #290 («Vaciar datos» en un dispositivo sin los grupos ya no deja al resto sin los gastos de grupo). La rutina semanal de barrido QA está pendiente y tiene prioridad sobre encadenar el siguiente ticket de Cola A: Cola A se reanuda cuando este barrido cierre.

Hoy hay ~54 tickets en `tickets/qa/` (el guion `qa/guion-tanda.md` es del barrido 2026-09-23 / PR #224, cuando bajó de 80 a 21; desde entonces la cola creció otra vez). Criterio de triaje: el mismo que PR #224.

Frank/lane: destino Yala (~/Yala), agente frank. No tocar marketing/ ni Web/.

MODO AUTÓNOMO HASTA TERMINAR: gate, commit, docs/board del repo, actualizar docs/TICKETS.md (índice al día), merge y /cerrar-total sin preguntar si corre el gate o el commit. Bugs/decisiones nuevas → ticket propio antes de cerrar. Solo parar ante decisión/acceso real de Jürgen. Board: create/move directo en tickets/ + docs/TICKETS.md (sin inbox Tim). Override: la regla «wait for approval if >3 files» / «¿Sigo?» tras el plan queda SUSPENDIDA — implementa hasta gate/PR/merge/cerrar-total sin pedir continuar. Diurno (6:00–21:00 Lima): puedes usar AskUserQuestion solo para decisión de producto o acceso de Jürgen.

Avisos al bot dueño (Frank): POSTea al webhook local de la Mini (URL y key en fichero local, no en git; no las escribas en el repo) cuando:
  (1) necesitas una decisión de producto o de acceso de Jürgen;
  (2) abriste el PR o dejaste preview/artifact listo;
  (3) terminaste el ticket y vas a /cerrar-total — incluye en el aviso un resumen corto de cierre en lenguaje de usuario (qué se hizo), no solo «cerré»;
  (4) acabaste un tramo y no tienes siguiente paso claro (aunque no haya pregunta formal) — una vez, no en bucle.
NO avises por: un test rojo que vas a reclasificar, un build que vas a reintentar, ni ruido de CI advisory.

## Que se pide
1. Inventariar todos los tickets actualmente en `tickets/qa/` (+ docs/TICKETS.md).
2. Triage cada uno con el criterio de PR #224:
   - DROP → `tickets/done/` sin device-QA si: difícil de reproducir, edge raro, ya cubierto por unit/UI tests, o sin camino visible que Jürgen pueda recorrer hoy en un iPhone (Yala Dev / staging).
   - KEEP en qa si: flujo visible con riesgo real de regresión (nube / restaurar / migrar / wipe / grupos) o copy/UX que hay que sentir a mano.
   - Si un ticket de qa no tiene código mergeado en HEAD → vuelve a `backlog`, no a done.
3. Marcar cada DROP como en #224: `qa-status: not-replicable` (o `absorbed` si aplica), `qa-date` de hoy, `qa-notes` de una línea, más sección «Barrido de qa · 2026-09-28» con el porqué y el test/cobertura si la citas.
4. Reescribir `qa/guion-tanda.md` con la lista corta must-test (orden por montaje, no por ticket) y guion del día para Jürgen en lenguaje de usuario (Yala Dev desde 2.1 vs TestFlight si aplica; cuentas/datos necesarios).
5. Actualizar docs/TICKETS.md e índices para que cuadren con el disco.
6. Abrir PR a 2.1, merge, /cerrar-total.

## Que NO hay que tocar
- No relances Cola A ni tickets de restore/cloud nuevos salvo bugs hallados de camino (entonces ticket propio antes de cerrar).
- No marketing/, no Web/.
- No clinicas-dentales-bi ni datos de salud.
- No pidas a Jürgen que pruebe lo que ya bajaste a done.
- No uses los simuladores dedicados del carril adaptativo (prefijo YalaLane-Adapt-); este barrido es docs/tickets, no builds de iPad.

## Como se sabe que esta bien
- docs/TICKETS.md e índice de tickets reflejan el triage (qa solo must-test; drops en done con notas).
- PR mergeado a 2.1 con lista final + guion device-QA del día en lenguaje de usuario.
- /cerrar-total limpio; aviso a Frank con resumen «qué se hizo» y «necesita de ti: el guion / lista corta».

## Paso 0 (Frank, 2026-09-28, MODO AUTÓNOMO)

Ficheros: 28 tickets de `tickets/qa/` a `tickets/done/` (frontmatter + sección de barrido), 1 ticket que se queda con su
sección, `qa/guion-tanda.md` reescrito, `docs/TICKETS.md` (28 filas). Nada que compilar: todo cae en `docs/`, `tickets/`,
`qa/guion-tanda.md` y `encargos/`, así que el gate es la validación del índice.

- **Inventario medido:** 51 tickets en `qa` (no 54: tres entradas son dos carpetas de evidencia y una captura). 23 ya
  estaban en el guion del 23-sep; 28 llegaron después.
- **Código en HEAD:** los 51 tienen su arreglo en `2.1` (PR de merge o commit en la historia). Ninguno vuelve a `backlog`.
- **Criterio, el de #224:** fuera todo lo que pide dos dispositivos, esperas de una hora, SQL o un fallo que no se provoca a
  mano, y lo que solo es no-regresión de un camino que otro ticket del guion ya recorre (`absorbed`). Dentro, lo que un
  iPhone con Yala Dev recorre y donde un fallo cuesta datos o dinero.
- **Los 22 que siguen del 23-sep no se re-triagan salvo uno:** `migration-activation-drops-pending-effects-it-never-restores`
  (E2) era «oportunista» y sus unit tests cubren la lógica; sale.
- **Entra uno nuevo:** `wipe-data-keeps-groups-but-drops-their-bridged-rows` («Vaciar datos» con grupos, un iPhone, dinero).
  Va en un bloque F al final porque «Vaciar datos» borra también el iCloud que los bloques B y C necesitan.
- **Asumido:** los dos `fresh-start-*` salen aunque son de un iPhone, porque su guion no existe tal cual: medido en
  `DestructiveScopeLogic.wipeLanding`, «Vaciar datos» con sesión privada lleva al onboarding personal, no a la bienvenida.
