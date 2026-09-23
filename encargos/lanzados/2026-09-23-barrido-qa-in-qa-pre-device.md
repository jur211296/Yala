# Barrido de tickets in-qa: quedarse solo con lo que Jürgen debe probar en iPhone hoy

## Contexto
Cola A de restore/cloud acaba de cerrar PR #223 (snapshot-upload alternating definitive causes → techo corto 15 min). Jürgen ordenó (2026-09-23 ~13:28 Lima): NO seguir cola A; hacer un barrido de los tickets en `in qa` / carpeta qa del board Yala. Objetivo: sacar de la cola de device-QA lo que no merece revisarse a mano (difícil de reproducir, edge raro, ya cubierto por tests/código) y dejar una lista final corta de lo que SÍ hay que probar en el iPhone hoy, más un guion de device-QA del mismo día.

Frank/lane: destino Yala (~/Yala), agente frank. No tocar marketing/ ni Web/.

MODO AUTÓNOMO HASTA TERMINAR: gate, commit, docs/board del repo, actualizar docs/TICKETS.md (índice al día), merge y /cerrar-total sin preguntar si corre el gate o el commit. Bugs/decisiones nuevas → ticket propio antes de cerrar. Solo parar ante decisión/acceso real de Jürgen. Board: create/move directo (sin inbox Tim). Override: la regla «wait for approval if >3 files» / «¿Sigo?» tras el plan queda SUSPENDIDA — implementa hasta gate/PR/merge/cerrar-total sin pedir continuar. Solo AskUserQuestion real de producto/acceso en 06:00–21:00 Lima.

Avisos al bot dueño (Frank): POSTea al webhook local de la Mini (URL y key en fichero local, no en git; no las escribas en el repo) cuando:
  (1) necesitas una decisión de producto o de acceso de Jürgen;
  (2) abriste el PR o dejaste preview/artifact listo;
  (3) terminaste el ticket y vas a /cerrar-total — incluye en el aviso un resumen corto de cierre en lenguaje de usuario (qué se hizo), no solo «cerré»;
  (4) acabaste un tramo y no tienes siguiente paso claro (aunque no haya pregunta formal) — una vez, no en bucle.
NO avises por: un test rojo que vas a reclasificar, un build que vas a reintentar, ni ruido de CI advisory.

## Que se pide
1. Inventariar todos los tickets actualmente en in-qa (carpeta/estado qa en ~/Yala/tickets + docs/TICKETS.md).
2. Triage cada uno: ¿necesita device review en iPhone, o se puede confiar en código/tests y bajarlo a done?
   - Drop (mover a done sin device QA) si: hard-to-reproduce, rare edge, already covered by unit/UI tests, no user-visible path Jürgen can exercise today.
   - Keep for device QA si: user-visible flow on Yala Dev / staging that Jürgen can hit today, regression risk on cloud/restore/migrate, copy/UX he asked to feel.
3. Mover en el board (tickets/ + docs/TICKETS.md) los que drops → done; dejar en qa solo los must-test.
4. Entregar en el PR / cierre:
   - Lista final must-test (orden sugerido, 1 línea cada una: qué probar y por qué).
   - Guion de device-QA del mismo día para Jürgen (pasos concretos en el iPhone, Yala Dev vs staging si aplica, datos/cuenta necesarios).
5. Abrir PR a 2.1, merge, /cerrar-total.

## Que NO hay que tocar
- No relances cola A ni tickets de restore/cloud nuevos salvo bugs hallados de camino (entonces --solo-crear / ticket propio).
- No marketing/, no Web/.
- No inventes emojis ni cifres del board.
- No pidas a Jürgen que pruebe lo que ya bajaste a done.

## Como se sabe que esta bien
- docs/TICKETS.md e índice de tickets reflejan triage (qa solo must-test; drops en done).
- PR mergeado a 2.1 con lista final + guion device-QA del día en lenguaje de usuario.
- /cerrar-total limpio; aviso a Frank con resumen «qué se hizo» y «necesita de ti: el guion / lista corta».

## Paso 0 (auto-contestado, MODO AUTÓNOMO, 2026-09-23 13:35 Lima)

Medido antes de decidir: 80 tickets en `tickets/qa/`, índice `docs/TICKETS.md` 530 = 530 ficheros y 80 = 80 en
`qa`. El guion de la tanda (`qa/guion-tanda.md`) es del 16-sep y cuenta 52: ya no cuadra con la carpeta.

1. **Qué es «hoy».** Un iPhone de Jürgen con `Yala Dev` contra staging (o el TestFlight 13), y como mucho un
   segundo aparato. Lo que pide dos Apple ID, cambiar el Apple ID del teléfono, un kill-switch en producción,
   un teléfono sin App Attest o esperar 24 h no es «hoy». *Asumido.*
2. **Criterio de corte** — el del encargo. KEEP si es un flujo visible que se recorre hoy con riesgo real de
   regresión en nube / restaurar / migrar, o copy que Jürgen pidió sentir. DROP si es raro, difícil de provocar,
   ya cubierto por tests o sin camino visible hoy.
3. **Tercera clase: lo que no está implementado** no es QA. Si un ticket de `qa` resulta no tener código
   mergeado, vuelve a `backlog` en vez de a `done`. *Asumido; `done` sería inventar un cierre.*
4. **Cómo se marca un DROP.** A `tickets/done/` con `qa-status: not-replicable`, `qa-date: 2026-09-23` y
   `qa-notes` de una línea (el schema no admite otro valor), más una sección corta «Barrido 2026-09-23» con el
   porqué. Es el override del owner que el schema ya prevé desde el 16-sep, esta vez por encargo.
5. **Dónde vive la lista corta y el guion del día.** Se reescribe `qa/guion-tanda.md` (es la superficie que ya
   existe para esto) y el PR lleva la lista en lenguaje de usuario.
6. **Gate.** El diff es solo markdown: el gate salta al paso 5 (`bash qa/validate-coverage.sh`). Va por PR
   porque el encargo lo pide, aunque `docs/` y `tickets/` podrían ir directos.

### Addendum tras el triage (medido)

- **Resultado:** 59 a `done` (57 `not-replicable` y 2 `absorbed`, cada uno con su `qa-notes`), 21 en `qa`, ninguno a
  `backlog`: los 80 tenían su código mergeado en HEAD.
- **Dos hechos que cambian el guion:** el TestFlight 13 es `039a12ed` (9-sep) y no lleva casi nada de la lista,
  así que todo va con Yala Dev compilado desde `2.1`; y Yala Dev usa su propio iCloud (`.dev`), así que los
  «datos previos en iCloud» se crean en el bloque A.
- **Recortes dentro de tickets que se quedan:** `full-mode-activation…` solo recorrido 3 (el 1 pide iCloud
  vacío); `previous-person…` paso 3 hoy y paso 4 con el próximo TestFlight; `scheduled-payments…` solo fase 2.
- **Hallazgo con ticket:** `qa-folder-keeps-evidence-of-tickets-that-already-left` (very-low).
