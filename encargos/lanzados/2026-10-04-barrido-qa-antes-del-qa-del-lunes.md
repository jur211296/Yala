# Barrido de tickets in-qa antes del QA del lunes: dejar solo lo que Jürgen debe probar en el iPhone, con un guion del día

## Contexto
Hoy, domingo 4 de octubre, se cerró todo el diseño que entraba en 2.1 antes del QA del lunes: trends (#345), el hero del Panel en las subvistas (#346), las cards de registro nuevo en Yala IA (#348), el detent medium de cuenta, etiquetas y subcategoría en el registro nuevo (#349), el panel de escucha del dictado (#350), el registro por voz (#351), el registro por imagen (#353) y las vistas del registro en grupos (#354, en cola de merge a 2.1 con su CI corriendo). Cada uno dejó su guion de device-QA en `tickets/qa/` (por ejemplo `chat-dictation-looks-poor.md`, `image-entry-end-to-end-redesign` y `group-expense-views-redesign.md`). En la cola de Jürgen sigue este barrido y, después, la subida a TestFlight en otra sesión.

El último barrido fue el 28 de septiembre (PR #291, encargo `encargos/lanzados/2026-09-28-barrido-qa-in-qa-semanal.md`). Dejó 23 tickets para el iPhone y un guion de un día en `qa/guion-tanda.md`. Desde entonces la cola volvió a crecer: hoy hay unas 44 entradas en `tickets/qa/`. El criterio de triaje es el mismo de #224 y #291; está escrito en ese encargo, léelo de ahí.

Destino Yala (~/Yala), agente frank. No tocar `marketing/` ni `Web/`.

MODO AUTÓNOMO HASTA TERMINAR: gate, commit, board del repo (`tickets/` y `docs/TICKETS.md`), PR a 2.1 con auto-merge y `/cerrar-total` sin preguntar. La regla de pedir aprobación con más de tres ficheros y el «¿Sigo?» tras el plan quedan suspendidos. Bugs o decisiones nuevas que aparezcan de camino van a un ticket propio antes de cerrar. Solo paras ante una decisión de producto o un acceso real de Jürgen.

## Qué se pide
1. Inventariar, medido en disco, todo lo que hay en `tickets/qa/` y en `docs/TICKETS.md`.
2. Triar cada ticket con el criterio de #224 y #291:
   - DROP a `tickets/done/`, sin device-QA, si es difícil de reproducir, un caso raro, ya cubierto por unit o UI tests, o no tiene un camino visible que Jürgen pueda recorrer hoy en un iPhone.
   - KEEP en qa si es un flujo visible con riesgo real de regresión (nube, restaurar, migrar, vaciar datos, grupos) o copy y UX que hay que sentir a mano.
   - Si un ticket de qa no tiene su código en HEAD de 2.1, vuelve a `backlog`, no a done.
3. Marcar cada DROP como en #291: `qa-status: not-replicable` (o `absorbed`), `qa-date` del día, `qa-notes` de una línea y una sección «Barrido de qa · <fecha>» con el porqué.
4. Reescribir `qa/guion-tanda.md` con la lista corta que hay que probar, ordenada por montaje y no por ticket, y el guion del lunes en lenguaje de usuario. Los rediseños de hoy (dictado, voz, imagen, cards de Yala IA, detent de cuenta y etiquetas, grupos) van en un bloque propio, porque son cambios visibles que hay que sentir a mano. Di para cada bloque si se prueba en Yala Dev desde 2.1 o en el TestFlight que sale después, y qué cuentas o datos hacen falta.
5. Dejar `docs/TICKETS.md` y los índices cuadrando con el disco.
6. PR a 2.1 con auto-merge y `/cerrar-total`.

## Qué NO hay que tocar
- Código de producto. Un bug que aparezca va a su ticket.
- La subida a TestFlight: es la sesión siguiente, no esta.
- `marketing/`, `Web/`, clinicas-dentales-bi y cualquier dato de salud.
- No pidas a Jürgen que pruebe lo que bajaste a done.
- Ni simulador ni build: el barrido es de docs y tickets. Si por algo tuvieras que compilar, va el pipeline serial de la Mini (limpiar, `xcodebuild -jobs 2` sin simulador, arrancar un solo simulador, tests, apagarlo y borrar su data). Al lanzar y al cerrar, borra solo el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees ya retirados o cuyo PR ya se mergeó, sin pedir aprobación. No toques DerivedData ni cachés de un worktree que sigue vivo. Si el borrado falla, dilo en el cierre.

## Antes del gate
La sesión arranca ya, sobre `origin/2.1`. No esperes a que el PR anterior (#354) entre, y no partas de su rama. Justo antes del gate, mira si #354 sigue en CI. Si sigue, espera a que entre y rebasa una sola vez. Si 2.1 no se movió, sigue de frente. Si ese CI falla, no esperes: rebasa con lo que haya y sigue.

## Cómo se sabe que está bien
- `tickets/qa/` solo tiene lo que hay que probar en el iPhone; los drops están en done con sus notas; lo que no tiene código en HEAD está en backlog.
- `qa/guion-tanda.md` es un guion del lunes que Jürgen puede seguir sin abrir los tickets, con el bloque de los rediseños de hoy.
- `docs/TICKETS.md` cuadra con el disco.
- PR a 2.1 con auto-merge y `/cerrar-total` limpio, con un resumen que diga cuántos quedan para el iPhone y qué necesita de Jürgen el lunes.

## Paso 0 (Frank, 2026-10-04, MODO AUTÓNOMO)

Ficheros: 14 tickets de `tickets/qa/` a `tickets/done/` (frontmatter + sección de barrido), `qa/guion-tanda.md`
reescrito, `docs/TICKETS.md` (14 filas) y este encargo. Nada que compilar: el gate es la validación del índice.

- **Inventario medido:** 49 tickets en `qa` (las otras 3 entradas son dos carpetas de evidencia y una captura). 23
  vienen del guion del 28-sep; 26 llegaron después.
- **Código en HEAD:** los 26 nuevos tienen su commit en `2.1` (símbolos clave buscados con `git grep`). Ninguno
  vuelve a `backlog`.
- **Criterio, el de #224 y #291.** Salen 14: los 2 de CI (no hay nada que ver en un iPhone), los 5 de iPad (lo que
  falta solo se ve en un iPad con la ventana estrechada), y 7 que piden dos dispositivos, SQL contra staging,
  bajar el rollout del gateway, un Apple ID de pruebas que se borra o una carrera con modo avión.
- **Se quedan 12 nuevos**, casi todos rediseños visibles: los 8 de hoy-ayer (trends, hero, cards de Yala IA,
  detent, dictado, voz, imagen) más el chat (#2-oct), Personalización, login y guías por pasos, y archivar cuentas
  (toca el total del Panel).
- **Los 23 del 28-sep siguen.** Nadie los probó todavía y nada en el código los volvió más baratos. Se retocan A2/A3
  porque la card del chat cambió hoy (ya no hay «Editar», el importe sale con símbolo).
- **#354 (grupos):** si entra antes del gate, su ticket va al bloque de rediseños; si no, queda fuera y se dice.
- **Asumido:** todo se prueba en Yala Dev compilada desde `2.1` el lunes; el TestFlight que sale después solo hace
  falta para el paso 4 de `previous-person-…`. El número de build no se escribe (regla del repo).
