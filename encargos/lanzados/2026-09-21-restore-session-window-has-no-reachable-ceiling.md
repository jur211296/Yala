# Techo alcanzable (o declarado) para la ventana de sesión del restore

## Contexto
Residual medido de la review de `leaving-and-reentering-restore-renews-the-hard-cap` (PR #204, mergeado a 2.1). Ticket: `tickets/backlog/restore-session-window-has-no-reachable-ceiling.md`.

El #204 cerró la mitad monótona: el re-ancla ya exige descarga VIGENTE (`hasLiveImportActivity`), no histórica. El criterio 1 del ticket pedía además un techo acotado. Se implementó un techo de cadena (`reanchorChainStartedAt`) y **la review lo tumbó midiendo sus dos mitades** antes de commitear: (1) no acotaba — «Empezar desde cero» → «Volver» → Restaurar llama `noteRestoreFinished` con el import vivo y estrena ventana/cadena nuevas en tres toques; (2) sí bloqueaba al dueño legítimo de forma permanente en el proceso. Baseline irreductible: matar la app estrena todo (señal en memoria a propósito).

Ticket hermano low del mismo cierre (NO lo abras aquí): `import-activity-latch-survives-an-icloud-account-change`.

Es de noche en Lima (21:00–6:00). NO uses AskUserQuestion. Elige la opción recomendada abajo y sigue. Solo aparca (ticket propio / no inventar / no mergear a medias) si al medir descubres que el camino recomendado reintroduce la mitad 2 o abre un agujero nuevo de producto.

**Decisión de producto (ya elegida por Frank en nocturno — no reabrir):**
Camino **2 del ticket**: que volver desde la puerta de descarte («Empezar desde cero» → «Volver» sin haber borrado) **NO estrene** ventana nueva — distinguir «volví sin descartar» de una entrada nueva. Cierra el recorrido de tres toques medido y deja intacto el baseline de relanzar la app.

NO elijas camino 1 (presupuesto de proceso dentro de `isRestoringNow`) salvo que al medir 2 resulte imposible sin romper el hermano `abandoned-restore…`. NO elijas camino 3 (aceptar que no hay techo) salvo que 2 resulte inseguro o imposible: si llegas ahí, documenta por qué y deja el ticket en backlog/blocked con la medición, sin inventar un techo que la review ya tumbaría igual.

MODO AUTÓNOMO HASTA TERMINAR: gate, commit, docs/board del repo, actualizar `docs/TICKETS.md` (índice al día), merge y /cerrar-total sin preguntar si corre el gate o el commit. Bugs/decisiones nuevas → ticket propio antes de cerrar. Solo parar ante decisión/acceso real no cubierto arriba. Board de proyectos: create/move directo (sin inbox Tim). Mueve este ticket a in-progress al empezar y a qa al cerrar si Jürgen debe probar a mano (o done si no hace falta QA de dispositivo).

## Qué se pide
1. Leer el ticket completo y el recorrido medido (WelcomeRestoreView / FullModeActivationView / ContentView: `noteRestoreFinished` desde «Empezar desde cero» y el remount que estrena).
2. Implementar camino 2: volver desde la puerta de descarte sin descartar no estrena `restoreStartedAt` / cadena.
3. Tests que recorran el ciclo completo incluido el paso por `noteRestoreFinished` (criterio 3).
4. Verificar que ningún camino deja al dueño legítimo sin poder abrir ventana el resto del proceso (no reintroducir mitad 2 del techo de cadena).
5. Verificar que el hermano abandoned-restore (vuelta legítima minutos después con descarga viva) sigue OK.
6. Board + `docs/TICKETS.md` + ESTADO breve. PR a 2.1, merge, /cerrar-total.

## Qué NO hay que tocar
- No reintroducir el techo de cadena `reanchorChainStartedAt` que la review tumbó.
- No deshacer #204 (`hasLiveImportActivity`) ni `abandoned-restore-no-longer-clears-the-session-window-clock` ni #203.
- No abrir de paso `import-activity-latch-survives-an-icloud-account-change`.
- No marketing/. No pedir go/merge/cerrar.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL y key en fichero local, no en git; no las escribas en el repo) cuando:
  (1) necesitas una decisión de producto o de acceso de Jürgen;
  (2) abriste el PR o dejaste preview/artifact listo;
  (3) terminaste el ticket y vas a /cerrar-total — incluye en el aviso un resumen corto de cierre en lenguaje de usuario (qué se hizo), no solo «cerré»;
  (4) acabaste un tramo y no tienes siguiente paso claro (aunque no haya pregunta formal) — una vez, no en bucle.
NO avises por: un test rojo que vas a reclasificar, un build que vas a reintentar, ni ruido de CI advisory.

## Cómo se sabe que está bien
- [ ] «Empezar desde cero» → «Volver» → Restaurar no estrena ventana nueva, o está escrito por qué se acepta (solo si aparcaste tras medir).
- [ ] Ningún camino deja al dueño legítimo sin ventana el resto del proceso.
- [ ] Test de ciclo completo con `noteRestoreFinished`.
- [ ] Board + docs/TICKETS.md al día; PR mergeado; /cerrar-total hecho sin preguntar.

## Paso 0 — decisiones (resueltas en autónomo (bypass), 2026-09-21)

El encargo ya fijaba la decisión grande —camino 2 del ticket— así que el árbol que quedaba era de
mecanismo. Cada nodo, con lo que lo zanjó.

1. **¿Cómo se distingue «volví sin descartar» de una entrada nueva?** → Con un reloj APARCADO en la
   señal (`parkedStartedAt`), no con una marca de «vengo de la puerta». *Por qué:* una marca de
   procedencia hay que limpiarla desde la UI y tiene tantos caminos como salidas tenga la puerta; el
   reloj se consume solo en el estreno, que es por donde pasan todos.

2. **¿Verbo nuevo o parámetro en `noteRestoreFinished`?** → Verbo nuevo
   (`noteRestoreDiscardRequested`). *Por qué:* un `Bool` en la firma tendría que decidirlo cada
   call-site y los dos valores rompen algo distinto; con dos verbos, el escáner de unicidad puede
   pinnear cada uno a su sitio. Efecto lateral bueno: `noteRestoreFinished` vuelve a significar
   «terminó de verdad» y deja de ser alcanzable desde la UI con el import vivo.

3. **¿El aparcado caduca, y con qué número?** → Sí, con el mismo tope duro de la ventana (600 s).
   *Por qué:* es la única frontera defendible —más allá de ella, el reloj heredado nacería muerto— y
   es lo que impide reeditar el bloqueo permanente del techo que la review tumbó. Se midió además
   que los tres `600` del subsistema eran literales independientes: pasan a una constante única.

4. **¿La herencia depende del testigo del import vivo, como el re-ancla?** → No. *Por qué:* los dos
   modos de fallo son opuestos. En el re-ancla, conceder ABRE de más, así que el testigo protege;
   aquí heredar es el lado seguro (cierra antes) y exigir el testigo haría que, sin descarga viva, se
   ESTRENARA — más abierto, no menos.

5. **¿Qué pasa si la vuelta no puede restaurar nada?** *(nodo que trajo la review)* → El aparcado se
   tira (`noteRestoreUnavailable`) en los dos `return` tempranos de `startSearch`. *Por qué:* si no,
   se queda varado y lo hereda una descarga NUEVA, con un tope que puede tener un segundo de vida.

6. **¿Se arregla el callejón de la ventana agotada, que es preexistente?** *(nodo que trajo la
   review)* → Sí, entra en este cambio. *Por qué:* es el criterio 2 del ticket, y mi propio fix le
   quitaba la salida que tenía. Acotado a `currentFlow != nil` para no deshacer el PR anterior.

7. **¿Los dos agujeros nuevos que destapó la review se arreglan aquí?** → No: ticket propio cada uno
   (`wiped-state-reaches-the-discard-gate-with-the-window-open`,
   `restore-retry-reopens-the-session-window-every-90-seconds`). *Por qué:* el segundo es más barato
   que el que este ticket cierra —un toque cada 91 s— y su arreglo toca la gracia de 60 s, que es
   otra decisión de producto.
