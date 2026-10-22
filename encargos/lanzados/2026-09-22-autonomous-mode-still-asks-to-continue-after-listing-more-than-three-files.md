# Alinear CLAUDE.md / agente frank: MODO AUTÓNOMO no pide «¿Sigo?» ni visto bueno por >3 ficheros

## Contexto
En la cola autónoma de Yala (bypass + MODO AUTÓNOMO HASTA TERMINAR) Claude sigue
parándose tras listar el plan si toca más de 3 ficheros, o tras implementar
pidiendo que Jürgen mergee / haga QA de iPhone. Acaba de pasar en
`snapshot-upload-has-no-ceiling-and-no-way-out` (PR #212): plan listo → «¿Sigo?»;
PR verde → «mergea tú».

Jürgen (2026-09-22) ordenó: al cerrar ese ticket, lanzar este arreglo. La norma
de producto diurna (AskUserQuestion 6:00–21:00 Lima para producto/acceso) SE
MANTIENE. Lo que se corta es el checkpoint mecánico de proceso.

Reglas hoy en conflicto (hay que reescribirlas, no borrarlas a ciegas):

1. `CLAUDE.md` ~L31 (General Rules):
   «Antes de editar, listar archivos… Esperar aprobación si son más de 3 archivos.»

2. `.claude/agents/frank.md` ~L73–74 (Control de ejecución):
   «Más de 3 ficheros: esperas aprobación.»

3. `CLAUDE.md` § Control de Ejecución y el paralelo en `frank.md`:
   «Tras implementar… detenerse. No encadenar tests, QA ni commits sin que los pida.»
   Eso choca con gate → commit → PR → merge → `/cerrar-total` de la cola.

Crea el ticket en `tickets/` (slug =
`autonomous-mode-still-asks-to-continue-after-listing-more-than-three-files`),
prioridad `high`, área tooling/proceso, y actualiza `docs/TICKETS.md`.

## Que se pide
1. Reescribir esas reglas para que quede explícito:
   - **Sesión interactiva / sin MODO AUTÓNOMO:** se mantiene listar ficheros; si
     son >3, esperar OK antes de editar; tras implementar, resumir y parar si no
     pedían el tren completo.
   - **MODO AUTÓNOMO / cola bypass / encargo con «HASTA TERMINAR»:** listar
     ficheros está bien como nota, pero **NO** pedir «¿Sigo?», **NO** esperar
     visto bueno por conteo de ficheros, **NO** parar tras implementar ni dejar
     el PR abierto «para que Jürgen mergee». Seguir: implementar → gate →
     commit → PR → CI → merge a la base del encargo → board/`docs/TICKETS.md` →
     `/cerrar-total`.
   - Device-QA de iPhone **no** bloquea el merge: el ticket va a `qa` con el
     guion; Jürgen lo hace cuando pueda.
   - Diurno 6:00–21:00 Lima: AskUserQuestion solo para decisiones reales de
     producto o acceso (igual que ahora). Técnico y de proceso: autónomo.

2. Si hay memorias de agente (`feedback_autonomo_hasta_el_final.md` u otras)
   que refuercen «de día pregunta aunque diga autónomo» de forma que se confunda
   con checkpoints de >3 ficheros / merge, añade una nota corta aclarando que
   eso aplica a producto/acceso, no a «¿sigo con el plan?» ni a «¿mergeo?».

3. Gate + PR + merge a `2.1` + `/cerrar-total`. Sin preguntar.

## Que NO hay que tocar
- Código de producto iOS / Swift / UI.
- La norma día/noche de AskUserQuestion para producto/acceso.
- marketing/.
- No inventar más reglas de proceso de las necesarias para este choque.

## Como se sabe que esta bien
- `CLAUDE.md` y `.claude/agents/frank.md` dejan claro el bifurcado
  interactivo vs MODO AUTÓNOMO.
- Ticket creado, índice al día, PR mergeado a 2.1, `/cerrar-total` hecho.
- Un lector nuevo entiende: en cola autónoma no se pregunta «¿Sigo?» por el
  plan ni se deja el merge a Jürgen.

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board del repo, actualizar `docs/TICKETS.md`, merge y
`/cerrar-total` sin preguntar si corre el gate o el commit. Bugs/decisiones
nuevas → ticket propio antes de cerrar. Solo parar ante decisión/acceso real.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL y key en fichero local, no en git; no
las escribas en el repo) cuando: (1) decisión de producto/acceso de Jürgen;
(2) abriste el PR o preview listo; (3) terminaste y vas a /cerrar-total —
incluye resumen corto de cierre en lenguaje de usuario; (4) acabaste un tramo
sin siguiente paso claro — una vez, no en bucle. NO avises por test rojo que
reclasificas, build a reintentar, ni ruido CI advisory.

## Día (6:00–21:00 Lima)
Puedes AskUserQuestion a Jürgen solo si aparece una decisión REAL de producto
o acceso nueva. Este encargo no debería necesitar ninguna: el criterio ya está
arriba. No uses AskUserQuestion para confirmar el plan, el merge ni el cierre.

## Paso 0

Auto-contestado (MODO AUTÓNOMO; ninguna decisión de producto ni de acceso en juego).

- **Dónde vive la definición de MODO AUTÓNOMO:** una vez, en `CLAUDE.md` § «Control de Ejecución».
  `frank.md` lo dice en corto y apunta ahí, para no crear dos textos que diverjan.
- **Qué cuenta como MODO AUTÓNOMO:** encargo con la sección «MODO AUTÓNOMO HASTA TERMINAR», sesión
  de la cola en bypass, o Jürgen diciendo «autónomo» / «hasta el final». Son las tres formas que
  aparecen en el encargo y en la memoria `autonomo-hasta-el-final`.
- **La regla del merge** («lo mergea él salvo que pida otra cosa») no se borra: se aclara que un
  encargo autónomo *es* pedir otra cosa. El release sigue siendo suyo; mergear no es release.
- **El gate rojo sigue parando en los dos modos.** El encargo no lo relaja y el `frank.md` lo pone
  como innegociable.
- **Asumido:** el ticket nace en `done` dentro del mismo PR, porque su criterio es el merge de este
  PR y no hay device-QA que hacer.
- **Ficheros:** `CLAUDE.md`, `.claude/agents/frank.md`, la memoria `feedback_autonomo_hasta_el_final.md`
  y su línea en `MEMORY.md`, el ticket y `docs/TICKETS.md`. Más de 3: es justo el caso que el
  encargo corta, así que la lista es nota y se sigue.
