# Welcome «privacidad total» en visita: pantalla propia + no promete seed

## Contexto
Ticket: `tickets/backlog/welcome-privacy-branch-has-no-secondary-door.md` (medium). En sesión secundaria, «Es mi primera vez → privacidad total» no dice que estás de visita (la rama de Grupos sí). Ya no daña datos; es coherencia + seed que promete y no crea.

**Decisión Jürgen (2026-09-06) — no repreguntar:** pantalla propia (molde `welcome.groups.secondary*`), informa sin bloquear; onboarding en visita deja de ofrecer categorías de ejemplo que no crea.

Cola medium autónoma (Frank): tras /cerrar-total → panel-colapsa-cuentas → reentry-killswitch → features → CI timeout.

## Que se pide
- Pantalla propia en el camino `.privateAccount` / secundaria: estás de visita, lo tuyo no se mezcla, y sigue.
- Seed: no ofrecer categorías de ejemplo en secundaria (o crearlas de verdad — preferir no ofrecer, alineado a la decisión).
- Copy 16 `.lproj`; coherencia con rama Grupos documentada.
- Board + `docs/TICKETS.md` al día.

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board, `docs/TICKETS.md`, merge y `/cerrar-total` sin preguntar. Bugs/decisiones nuevas → ticket propio. Solo parar ante decisión/acceso real de Jürgen.

## Que NO hay que tocar
- marketing/, clinicas-dentales-bi.
- No bloquear la rama (encauzar, no bloquear).
- No reabrir el aislamiento de preferencias/onboarding ya cerrado.

## Como se sabe que esta bien
- AC del ticket; PR mergeado a 2.1; board + índice; `/cerrar-total`.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL/key en fichero local, no en git) cuando:
  (1) decisión/acceso Jürgen; (2) PR abierto; (3) /cerrar-total con resumen de usuario; (4) sin siguiente paso — una vez.
NO avises por test rojo a reclasificar, build a reintentar, ni CI advisory.
