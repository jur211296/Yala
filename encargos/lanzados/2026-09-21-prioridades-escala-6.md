# Ampliar prioridades a 6 peldaños y remap mecánico del board abierto

## Contexto
Jürgen (2026-09-21) pidió en el 1:1 con Frank ampliar la escala de prioridades del board Yala de 3 a 6 peldaños, con limpieza sencilla y remap mecánico YA:

  critical → very-high → high → medium → low → very-low

Decisión explícita del widget: «Sí: critical…very-low y remap mecánico ahora».

Hoy los tickets abiertos usan solo `priority: high|medium|low` (aprox. 47 high / 187 medium / 128 low / ~19 sin priority). El esquema documentado en `docs/TICKETS.md` (y cualquier mención en CLAUDE.md / scripts / skills) hay que actualizarlo.

Hay una sesión hermana viva en el ticket in-progress `restore-timeout-closes-the-session-window-with-the-import-still-running` (cola A de código). NO compitas por Swift ni por el cuerpo de ese ticket: solo puedes tocar su frontmatter `priority:` si entra en las reglas de abajo. Si chocáis en `docs/TICKETS.md` u otros docs de board, rebase/reintenta; no reescribas su trabajo de producto.

MODO AUTÓNOMO HASTA TERMINAR: gate, commit, docs/board del repo, actualizar `docs/TICKETS.md` (índice al día), merge a 2.1 y /cerrar-total sin preguntar si corre el gate o el commit. Bugs/decisiones nuevas → ticket propio antes de cerrar. Solo parar ante decisión/acceso real. Board de proyectos: create/move directo (sin inbox Tim).

Diurno (6:00–21:00 Lima): puedes AskUserQuestion a Jürgen solo si aparece una decisión de producto/acceso NO cubierta abajo. NO preguntes go, ni OK de plan, ni «¿mergeo?», ni confirmación de /cerrar-total.

## Qué se pide

1) **Esquema (fuente de verdad)**  
   Actualiza `docs/TICKETS.md` (y cualquier validador/docs/CLAUDE que fije la escala) para admitir exactamente:

   `critical` | `very-high` | `high` | `medium` | `low` | `very-low`

   Definiciones cortas (ajusta redacción al tono del doc, no inventes proceso):
   - `critical` — emergencia en producción / ship roto ahora. Reservado; no se usa “por si acaso”.
   - `very-high` — bloquea salir 2.1 en modo nube sin callejón (dato en riesgo o usuario atrapado).
   - `high` — importante; incluye device-QA que Jürgen debe correr, sin ser callejón de código abierto.
   - `medium` — mejora clara, no urgente.
   - `low` — nice-to-have.
   - `very-low` — polish, tooling lejano, docs de higiene.

   Sigue valiendo: omitir `priority` si el origen no tenía valor real; no inventar priority en tickets que hoy no la tienen.

2) **Remap mecánico (solo frontmatter `priority:`, sin reescribir cuerpos)** en tickets NO cerrados (`backlog`, `in-progress`, `blocked`, `qa` — no toques `done` salvo que el índice lo exija por consistencia de esquema en ejemplos):

   - `critical`: dejar **vacío** (0 tickets). Reservado.
   - `very-high`: promover desde `high` SOLO tickets que sean **trabajo de código aún abierto** (status backlog o in-progress o blocked, **no** `qa`) y que describan un **callejón de nube/restore/reverse/sesión** donde el usuario puede quedarse atrapado o perder/confundir datos al salir 2.1. Si tras leer títulos+área ninguno califica con claridad, deja `very-high` vacío y documéntalo en el PR — no fuerces promociones dudosas.
   - Resto de `high` (incluidos casi todos los de `qa` / device-QA): **se quedan `high`**.
   - `medium`: sin cambio de valor.
   - `low`: sin cambio, salvo democión a `very-low` si es claramente tooling/docs lejano. Candidatos ya mirados (confirma leyendo 10 líneas; demuéelos solo si encajan):
     - `xcode-project-config-json-format-when-27-2-stable`
     - `indice-readme-cuenta-los-ficheros-de-los-worktrees-anidados`
     - `indice-readme-barre-worktrees-anidados`
     - `el-turno-del-simulador-cubre-tambien-la-compilacion`
     - `gateway-typecheck-roto-y-fuera-del-ci`
     (si alguno no es “lejano/higiene”, déjalo `low`)
   - Tickets **sin** `priority`: no les inventes una.

3) **Índice**  
   Regenera/actualiza `docs/TICKETS.md` (conteos y cualquier tabla por prioridad) para que coincida con el disco.

4) **PR a 2.1**  
   Un PR claro: esquema + remap. Título/body en lenguaje de humano. Merge cuando el gate lo permita (docs-only: no inventes fallos de UI test advisory como bloqueo). Luego `/cerrar-total`.

## Qué NO hay que tocar
- Código Swift, gateway, CI de app, marketing/.
- Cuerpos de tickets (salvo una línea de nota de esquema si el propio ticket de proceso lo pide — preferible no).
- No crear tickets nuevos de producto.
- No vaciar `qa` ni mover status.
- No pedir go/merge/cerrar.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL y key en fichero local, no en git; no las escribas en el repo) cuando:
  (1) necesitas una decisión de producto o de acceso de Jürgen;
  (2) abriste el PR o dejaste preview/artifact listo;
  (3) terminaste el ticket y vas a /cerrar-total — incluye en el aviso un resumen corto de cierre en lenguaje de usuario (qué se hizo), no solo «cerré»;
  (4) acabaste un tramo y no tienes siguiente paso claro (aunque no haya pregunta formal) — una vez, no en bucle.
NO avises por: un test rojo que vas a reclasificar, un build que vas a reintentar, ni ruido de CI advisory.

## Cómo se sabe que está bien
- [ ] El esquema documenta los 6 valores y sus definiciones.
- [ ] Ningún ticket abierto tiene un `priority:` fuera de esos 6.
- [ ] `critical` = 0; `very-high` solo con el criterio de callejón código-abierto (o 0 si no hay).
- [ ] Device-QA en `qa` que eran `high` siguen `high`.
- [ ] Un puñado justificado pasó a `very-low` (o 0 si no convencen).
- [ ] `docs/TICKETS.md` índice/conteos cuadran con el disco.
- [ ] PR mergeado a 2.1 + `/cerrar-total` hecho sin preguntar.
