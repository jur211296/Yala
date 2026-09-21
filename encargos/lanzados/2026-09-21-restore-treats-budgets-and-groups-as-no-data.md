# Restaurar no diga «no hay datos» si solo hay presupuestos o grupos en iCloud

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, tickets/ + docs/TICKETS.md, merge a 2.1 y /cerrar-total SIN preguntar.
Bugs/decisiones nuevas → ticket --solo-crear antes de cerrar.
NO pidas go ni «¿le doy?». Si el ticket ya fija el outcome, implementa.

## Contexto
Ticket: `tickets/backlog/restore-treats-budgets-and-groups-as-no-data.md` (medium, callejón de Restore).
Siguiente de la cola A tras #195/#196. Medido: `hasAnyData` ignora `budgetsCount`/`groupsCount` y niega datos que la UI ya mostró bajando.

## Decisión de producto
Incluir presupuestos y grupos en el criterio de «hay datos» (las dos copias alineadas o una sola). Criterios del ticket mandan.

## Modo día (6:00–21:00 Lima)
AskUserQuestion SOLO si aparece decisión de producto/acceso NO cubierta por el ticket. Nunca para aprobar el plan.

## Qué se pide
Implementar según criterios de aceptación. Tests. PR a 2.1. Board + docs/TICKETS.md. /cerrar-total.

## Avisos al bot dueño (Frank)
Webhook local Mini (URL/key fichero local, no git) cuando: (1) decisión/acceso Jürgen; (2) PR abierto; (3) /cerrar-total con resumen usuario; (4) idle sin paso — una vez.
NO: test a reclasificar, build a reintentar, CI advisory.

## Qué NO tocar
marketing/, Web/. No reabrir #195/#196 salvo acoplamiento real.

## Criterio de hecho
Criterios del ticket + gate verde + PR mergeado + board al día + /cerrar-total.

## Paso 0 — decisiones (resueltas en autónomo (bypass), 2026-09-21)

El árbol completo, con su medición, está escrito **en el ticket**
(`tickets/*/restore-treats-budgets-and-groups-as-no-data.md`, sección «Paso 0 · Decisiones»), que es
donde vive el trabajo y desde donde viaja al PR. Aquí queda el resumen de una línea por nodo:

- **D1** · `ICloudAccountSummary.hasAnyData` pasa a contar **cuatro** cifras: entran los
  presupuestos, **NO los grupos**. ⇒ **contradice el encargo a sabiendas**, y por medición: se
  implementó primero con las cinco y la review adversarial lo refutó. Contar los grupos vuelve
  inalcanzables `.importIncomplete` (el ticket cerrado anteayer), `.cloudPaused`, `.cloudUnverified`
  y `.notFound` para toda la población con grupos —por construcción en `FullModeActivationView`, a
  la que solo se llega desde una sesión solo-grupos—, y la protección que lo motivaba **ya existía**:
  `checkHasExistingData()` cuenta `SplitGroup` y es quien alimenta el aviso con doble confirmación
  de la puerta. El detalle, en el D1 del ticket.
- **D2** · Los grupos tampoco van en `ICloudPersonalCorpusProbe`: `SplitGroup` vive en un store
  `cloudKitDatabase: .none` y no hay `CD_SplitGroup` en el contenedor personal **por diseño** (sí
  hubo residuos legacy hasta el 14-jun-2026, y eso queda escrito). La sonda añade solo
  **presupuestos** (`CD_Budget`). ⇒ **corrige la premisa del encargo**, que daba por hecho un corpus
  de iCloud con grupos.
- **D3** · Las dos copias **no** se funden en una: miden fuentes distintas. Se alinean y cada una
  documenta el término que la otra tiene.
- **D4** · `countsLine` pinta los presupuestos (mismo defecto ya cerrado ahí para categorías).
- **D5** · `visibleCountItems` pinta las categorías — hueco VIVO anterior a este trabajo, cazado al
  revisar el consumidor que el criterio 3 del ticket manda revisar.
- **D6** · El copy **no se toca** («Encontramos tus datos en iCloud:» engloba una card de grupos que
  no vienen de ahí) → ticket propio, `low`.
- **D7** · La decisión de `.notFound` («pregunta SIEMPRE») **no se revierte**, y con D1 corregido ni
  siquiera pierde su razón. Se reescriben los cuatro sitios que citaban el hueco.
- **D8** · Se anota el colateral en `restore-beacon-outlives-account-deletion` §3.
- **D9** · Cuatro observaciones de la review salen en ticket en vez de arreglarse aquí:
  `restore-prefill-skips-currency-for-an-empty-summary`, `restore-found-state-leaves-no-breadcrumb`,
  `group-presence-predicates-disagree-on-archived-and-hidden` y el grid de cinco cards (que va al
  device-QA, no a un ticket: es un grid impar, no un defecto).
