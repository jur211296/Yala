# Acotar el re-ancla al salir y volver a Restaurar (sin reabrir el hermano)

## Contexto
Sale medido de la review de `restore-timeout-closes-the-session-window-with-the-import-still-running` (PR #203, mergeado a 2.1). Ticket: `tickets/backlog/leaving-and-reentering-restore-renews-the-hard-cap.md`.

Hoy `noteRestoreStarted` re-ancla el reloj cuando la ventana está huérfana y `hasObservedImportActivity` (latch monótono de proceso) sigue true. Cualquier salir-y-volver a Restaurar estrena 600 s de ventana del guard cross-cuenta — superficie distinta del reintento «en sitio» que cerró el #203.

NO es regresión del #203. El re-ancla existe a propósito por `abandoned-restore-no-longer-clears-the-session-window-clock` (quien se arrepiente y vuelve minutos después no debe heredar un reloj muerto). Hay que acotar el rebote sin deshacer ese hermano.

Es de noche en Lima (21:00–6:00). NO uses AskUserQuestion. Elige la opción recomendada abajo y sigue. Solo aparca (ticket propio / no inventar) si el riesgo es demasiado alto para asumir.

**Decisión de producto (ya elegida por Frank en nocturno — no reabrir):**
Camino recomendado del propio ticket: **exigir descarga VIGENTE, no histórica**. Sustituir el latch monótono `hasObservedImportActivity` por un testigo con fecha: re-anclar solo si hubo un `.importEvent` (o equivalente real) en los últimos X segundos razonables. Es el término que hace monótono el agujero y el que menos toca el diseño del hermano. Documenta X y el razonamiento en el ticket/PR. No implementes «tope de proceso aparte» ni «contar N re-anclas» salvo que al medir descubras que el testigo con fecha no cierra el criterio 1.

MODO AUTÓNOMO HASTA TERMINAR: gate, commit, docs/board del repo, actualizar `docs/TICKETS.md` (índice al día), merge y /cerrar-total sin preguntar si corre el gate o el commit. Bugs/decisiones nuevas → ticket propio antes de cerrar. Solo parar ante decisión/acceso real no cubierto arriba. Board de proyectos: create/move directo (sin inbox Tim). Mueve este ticket a in-progress al empezar y a qa al cerrar si Jürgen debe probar a mano.

## Qué se pide
1. Leer el ticket completo y el código citado (`ICloudRestoreSessionSignal.noteRestoreStarted`, flujos FullModeActivationView / ContentView que desmontan y remontan Restaurar).
2. Implementar el testigo con fecha (no latch monótono) para el re-ancla.
3. Tests que recorran el ciclo salir-volver (criterio 3 del ticket), no solo source-scan.
4. Verificar que el caso del hermano (entrar → arrepentirse → volver una vez ~7 min con descarga real) sigue estrenando ventana legítima.
5. Actualizar board + `docs/TICKETS.md` + ESTADO breve si aplica. PR a 2.1, merge, /cerrar-total.

## Qué NO hay que tocar
- No deshacer `abandoned-restore-no-longer-clears-the-session-window-clock`.
- No reabrir el arreglo del #203 (reintento en sitio).
- No marketing/. No pedir go/merge/cerrar.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL y key en fichero local, no en git; no las escribas en el repo) cuando:
  (1) necesitas una decisión de producto o de acceso de Jürgen;
  (2) abriste el PR o dejaste preview/artifact listo;
  (3) terminaste el ticket y vas a /cerrar-total — incluye en el aviso un resumen corto de cierre en lenguaje de usuario (qué se hizo), no solo «cerré»;
  (4) acabaste un tramo y no tienes siguiente paso claro (aunque no haya pregunta formal) — una vez, no en bucle.
NO avises por: un test rojo que vas a reclasificar, un build que vas a reintentar, ni ruido de CI advisory.

## Cómo se sabe que está bien
- [ ] Ciclo salir-volver repetido no mantiene la ventana del guard más allá de un techo acotado y medible.
- [ ] El caso del hermano (una vuelta legítima minutos después con descarga real) sigue OK.
- [ ] Test de ciclo, no solo scan.
- [ ] Board + docs/TICKETS.md al día; PR mergeado; /cerrar-total hecho sin preguntar.

## Paso 0 — decisiones (resueltas en autónomo/bypass por Frank, 2026-09-21 noche)

El encargo ya fijó el CAMINO (testigo con fecha, no latch monótono) y dejó una puerta abierta:
«no implementes tope de proceso ni contar re-anclas **salvo que al medir descubras que el testigo
con fecha no cierra el criterio 1**». Se midió. Estas son las decisiones.

### D1 · ¿Qué fecha sella el testigo?

**El instante de OBSERVACIÓN del `.importEvent`, no su `endDate`/`startDate`.**
`endDate` describe el import; el testigo describe qué sabe este proceso y cuándo lo supo. Un import
largo que cierra con un `endDate` de hace cinco minutos acaba de dar señal de vida AHORA. Además el
instante de observación sube siempre, así que un evento fuera de orden no retrasa el sello.

### D2 · ¿Sólo la fecha del último evento? — NO: también el import EN CURSO. (Medido)

Medido leyendo `iCloudSyncService.apply`: un `.importEvent` sin `endDate` deja `status =
.syncing(.importing)` y **el evento terminal puede tardar minutos** — un import grande emite uno al
empezar y otro al acabar. Con un testigo basado sólo en la fecha del último evento, la vuelta
legítima del hermano (entrar → arrepentirse → volver a los 7 min con la descarga viva) llegaría con
el sello caducado y **no re-anclaría**: heredaría un reloj de 7 min, su tope duro caducaría a media
bajada y se reabriría `abandoned-restore-no-longer-clears-the-session-window-clock`, que es
justamente lo que el encargo prohíbe romper.

⇒ **descarga vigente = `status.isImporting` **O** un `.importEvent` observado hace menos de 60 s.**
El 60 s no es un número nuevo: es `graceForNoActivity`, el plazo con el que `isRestoringNow` ya
declara «sin actividad de import no hay descarga que justifique la ventana». Usar otro haría que las
dos decisiones dijeran cosas distintas sobre el mismo mundo.

### D3 · ¿Cierra eso el criterio 1 por sí solo? — NO. (Medido ⇒ se levanta la puerta del encargo)

`status.isImporting` **no tiene watchdog**: el de `scheduleForceSyncWatchdog` se cancela en cuanto
llega el primer evento, y su propio docblock lo dice — «si emitiera un evento inicial y luego se
colgara sin el terminal, el watchdog ya estaría cancelado». O sea que un import pegado deja el
testigo encendido indefinidamente y el ciclo salir-volver vuelve a renovar sin techo. El testigo con
fecha hace **no-monótono** el término, pero no da techo.

⇒ Se añade **el techo de la CADENA de re-anclas**, la primera opción del ticket, acotada: un reloj
propio (`reanchorChainStartedAt`) que nace cuando la ventana se ESTRENA y que **ningún re-ancla
mueve**. Pasados `reanchorCap = 600 s` desde él, la huérfana ya no se re-ancla.

**El techo medible que queda: una ventana estrenada en t está abierta como máximo hasta t + 1200 s**
(600 de cadena + 600 del tope duro de la última ventana re-anclada), pase lo que pase con los toques.

### D4 · Dos términos, ¿no es eso una segunda capa defensiva?

No: responden preguntas distintas y su alcance se mide por separado.
- El testigo contesta **«¿hay descarga que justifique una ventana nueva?»** y cierra el caso grande —
  re-anclar apoyándose en un import que terminó hace veinte minutos.
- El techo contesta **«¿cuánto puede durar una cadena de re-anclas?»** y es lo único que da un número.
Cada uno tiene su test y su mutante: quitar uno deja rojo un test que el otro no cubre.

### D5 · El baseline irreductible, y por eso «techo» significa esto

Matar la app y volver a entrar estrena TODO —la señal vive en memoria a propósito—, así que ningún
techo impide renovar a quien esté dispuesto a relanzar. Lo que el techo compra es que **dejar de ser
gratis**: renovar pasa de dos toques a esperar con el guard cerrado. Es lo que el criterio 1 puede
pedir de verdad y así se redacta en el ticket.

### D6 · Residuo aceptado

Una descarga que dure más de 1200 s deja de estar cubierta: el dueño legítimo con un restore de más
de veinte minutos vuelve a ver el bloqueo cross-cuenta. Es el mismo residuo que el tope duro ya
declaraba a los 600 s («un import que lleva diez minutos sin asentar es un estado atascado»), con el
doble de margen. No se abre ticket: es la decisión, no un hallazgo.

### D7 · Firma del verbo

`noteRestoreStarted(hasObservedImportActivity:)` pasa a `noteRestoreStarted(hasLiveImportActivity:)`,
sin valor por defecto como hasta ahora. El **rename** es deliberado: rompe los ~15 call-sites de test
y obliga a releer cada uno, en vez de dejarlos verdes afirmando una premisa que cambió de
significado.
