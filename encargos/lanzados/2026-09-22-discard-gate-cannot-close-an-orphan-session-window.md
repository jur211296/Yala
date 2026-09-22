# La puerta de descarte puede apagar una ventana huérfana (decisión de noche)

## Contexto
Sale del residual de PR #207 (`wiped-state-reaches-the-discard-gate-with-the-window-open`, mergeado a 2.1). Ese ticket cerró el camino en el que LA MISMA instancia tiene el `flowToken`. Queda el hermano: salir de Restaurar y volver a entrar deja la ventana **viva y huérfana** (`currentFlow = nil`, `restoreStartedAt` vivo), y «Empezar desde cero» hace no-op porque `noteRestoreDiscardRequested(flowToken)` exige titularidad.

Ticket: `tickets/backlog/discard-gate-cannot-close-an-orphan-session-window.md`
Lee `docs/ESTADO.md` (sesión #207), el ticket hermano en qa, y el invariante de `abandoned-restore-no-longer-clears-the-session-window-clock`.

## MODO AUTÓNOMO HASTA TERMINAR
Cola A nocturna (03:40 Lima). Bypass. No preguntes merge ni /cerrar-total.
Tras PR abierto: mergea a `2.1` y `/cerrar-total` sin esperar a Jürgen. Device-QA en qa no bloquea el cierre.
Bugs/decisiones nuevas → ticket propio (`--solo-crear` / fichero en tickets/) **y** actualiza `docs/TICKETS.md` antes de cerrar.
Board Yala = `tickets/` + `docs/TICKETS.md` (índice al día). Mueve este ticket a in-progress al empezar; a qa al cerrar con guion de device-QA si aplica.

## DECISIÓN DE NOCHE (Frank · no AskUserQuestion)
**Sí: el descarte puede apagar una ventana que no es de su intento.** Quien pulsa «Empezar desde cero» declara que no quiere esas filas; la premisa de proteger el import deja de valer para ese gesto. Es el único verbo que puede apagar sin titularidad.

Implementación esperada (verifica y ajusta si el código dice otra cosa):
- Verbo o parámetro de descarte que apague **sin** el `guard` de dueño vigente.
- El `parked` que deje sigue siendo el **reloj viejo** (no estrenar techo nuevo).
- Quien abandona y vuelve **sin** descartar sigue con ventana viva (invariante de abandoned-restore).
- Alcance: las **tres** instanciaciones de la puerta (`WelcomePrivateICloudGateView`), no solo `onStartFresh` vía Restaurar. Incluye «Soy nuevo» → «Privado» (`WelcomeFlowContainer`) si llega con ventana huérfana.

Anota la decisión en el ticket y en ESTADO/DECISIONS según convención del repo.

## Qué se pide
1. Cerrar el agujero del recorrido de 6 pasos del ticket (timeout → atrás → reentrar → return temprano → Empezar desde cero = no-op).
2. Tests que recorran ese camino; mutantes/adversarial al nivel del hermano.
3. Si el criterio del escáner `everyPathToTheDiscardGateClosesTheSessionWindow` queda mal acotado, reescribirlo con el alcance real **después** del fix (ya no debería hacer falta acotar a la baja si el descarte sí apaga huérfanas).
4. No tocar marketing/ ni Web/.

## Qué NO hay que tocar
- marketing/, Web/
- El invariante abandoned-restore (ventana viva sin descarte)
- Relanzar tickets en qa de device-QA

## Como se sabe que está bien
- Criterios del ticket marcados.
- Gate del repo (build, unit, mutantes relevantes, índice QA si toca).
- PR mergeado a 2.1 + `/cerrar-total` + `docs/TICKETS.md` al día.
- Ticket en qa con guion de teléfono si hace falta device-QA.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL y key en fichero local, no en git; no las escribas en el repo) cuando:
  (1) necesitas una decisión de producto o de acceso de Jürgen;
  (2) abriste el PR o dejaste preview/artifact listo;
  (3) terminaste el ticket y vas a /cerrar-total — incluye resumen corto de cierre en lenguaje de usuario;
  (4) acabaste un tramo y no tienes siguiente paso claro — una vez, no en bucle.
NO avises por: test rojo que vas a reclasificar, build que vas a reintentar, ni ruido de CI advisory.

## Paso 0 — decisiones (resueltas en autónomo, bypass)

Medido antes de decidir: `WelcomePrivateICloudGateView(` tiene **tres** instanciaciones vivas en
producción — `WelcomeFlowContainer.swift:250` (step `.privateICloudGate`), y `FullModeActivationView`
`:123` (`.privateGate`) y `:144` (`.restoreDiscardGate`). Y los **dos** consumidores de
`WelcomeRestoreView.onStartFresh` desembocan en una de ellas: `ContentView` en
`returnToWelcomeChooser(step: .privateICloudGate)` y `FullModeActivationView` en
`go(to: .restoreDiscardGate)`. O sea: la puerta es el destino común de los siete caminos de Restaurar
**y** de los dos que nunca pasan por Restaurar.

**D1 · ¿El descarte puede apagar una ventana que no es de su intento?** → **Sí.** Es la decisión de
noche del encargo y se ratifica midiendo lo que el `guard` protegía: «una pantalla vieja que confirma
tarde». Con el apagado en la puerta, quien llama no tiene token ninguno, así que ese escenario deja de
existir por construcción. Los otros dos verbos (`noteRestoreAbandoned`, `noteRestoreFinished`)
CONSERVAN su guard: a ésos los llama una pantalla que sí guarda token.

**D2 · ¿Dónde vive el apagado: en el gesto (Restaurar) o en el destino (la puerta)?** → **En la
puerta**, y el punto único de `WelcomeRestoreView.discardImportAndStartFresh()` (#207) **sube un nivel
y se retira**. Tres razones medidas: (a) es el único sitio que alcanza las tres instanciaciones —el
punto de Restaurar no cubre «Soy nuevo» → «Privado», que es el alcance que pide el encargo—; (b)
conservar los dos deja un escritor cuyo borrado **no cambia nada observable** (los siete caminos de
Restaurar acaban en la puerta igual), que es la firma exacta del código que sobra y que enmascara
mutantes; (c) el criterio del ticket hermano —«ningún camino a la puerta deja la ventana viva»— pasa a
ser **verdad**, no una promesa acotada. #207 no se deshace: se cumple mejor.

**D3 · ¿El `parked` se escribe incondicional?** → **No: solo si hay reloj que aparcar.** La rama es
alcanzable, no defensiva — `.onAppear` puede correr dos veces sobre la misma puerta, y la segunda
pasada con la asignación incondicional escribe `nil` encima del reloj que la primera guardó. Eso
reabre el recorrido de tres toques de `restore-session-window-has-no-reachable-ceiling`.

**D4 · ¿Firma con token opcional o sin parámetro?** → **Sin parámetro.** Un `FlowToken?` que ya no
decide nada es decorativo y deja los ~15 call-sites de la suite en verde afirmando una premisa que ya
no es suya. Sin parámetro, el compilador obliga a revisarlos uno a uno.

**D5 · Residual aceptado y medido.** Con el apagado en la puerta, quien abandona Restaurar y elige
«Soy nuevo» → «Privado» **aparca el reloj viejo** en vez de re-anclar su ventana al volver por «Traer
mis datos». Es el lado seguro (cierra antes, nunca después) y es el mismo trato que ya recibía la
vuelta desde la puerta por el camino de Restaurar desde #205. Se anota en el ticket.
