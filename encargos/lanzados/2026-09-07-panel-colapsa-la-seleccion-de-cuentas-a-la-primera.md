# El Panel respeta el conjunto de cuentas filtradas (no solo .first)

## Contexto
Ticket: `tickets/backlog/panel-colapsa-la-seleccion-de-cuentas-a-la-primera.md` (medium). Con 2+ cuentas en el filtro, el Panel colapsa a `selectedAccountIDs.first` (inestable); Estadísticas/Distribución respetan el conjunto.

**Decisión Jürgen (2026-09-06) — no repreguntar:** el Panel respeta el conjunto, como Estadísticas. Toca los cuatro sitios que asumen «una o ninguna».

Cola medium autónoma (Frank): tras /cerrar-total → reentry-killswitch → features → CI timeout.

## Que se pide
AC del ticket:
- Con dos cuentas seleccionadas, Panel y Estadísticas (Distribución) muestran el mismo saldo.
- `includeGroupsInPanelTotal` solo al total agregado.
- Unit del caso de dos cuentas en ambos caminos.
- Device-QA documentado (Registros → Filtros, dos cuentas).
- Board + `docs/TICKETS.md` al día.

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board, `docs/TICKETS.md`, merge y `/cerrar-total` sin preguntar. Bugs/decisiones nuevas → ticket propio. Solo parar ante decisión/acceso real de Jürgen.

## Que NO hay que tocar
- marketing/, clinicas-dentales-bi.
- No volver al modelo «Panel = una cuenta».
- No romper el KPI Balance Distribución = Panel (#78).

## Como se sabe que esta bien
- AC (salvo device-QA en qa); PR mergeado a 2.1; board + índice; `/cerrar-total`.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL/key en fichero local, no en git) cuando:
  (1) decisión/acceso Jürgen; (2) PR abierto; (3) /cerrar-total con resumen de usuario; (4) sin siguiente paso — una vez.
NO avises por test rojo a reclasificar, build a reintentar, ni CI advisory.
