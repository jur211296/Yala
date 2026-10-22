# Un miembro pendiente no puede abrir el detalle del grupo (cerrar puerta en cliente)

## Contexto
Ticket: `tickets/backlog/groups-pending-member-can-open-group.md` (high). Hallazgo de Jürgen (2026-08-28, TestFlight 2.1): el pendiente ve el grupo en la lista y al tocarlo ENTRA al detalle sin estar aprobado. Veredicto del owner: eso está mal.

**Decisión Jürgen (2026-09-06) — no repreguntar:** cerrar la puerta solo en el cliente. La tarjeta del grupo no abre el detalle mientras el miembro esté en `pendingApproval`; en su lugar, superficie que diga que la solicitud está en revisión y qué puede hacer. El servidor no se toca (`is_group_member` sigue admitiendo pending; `is_group_writer` ya reserva escritura a active). Descartó «explicar la espera dentro» y «quitarlo también de la lista».

Quien arranca: contexto limpio. Lee el ticket entero. Antes de código, mide lo que «Lo que NO se midió» dejó abierto (quién gatea hoy `GroupDetailView` con pendingApproval; si el cliente pinta botones de escritura).

Vecino: `guest-decline-has-no-screen` — su copy de sala de espera vive en la lista; al dejar de navegar, sigue teniendo sitio.

## Que se pide
Implementar según ticket + AC:
- Con miembro en `pendingApproval`, tocar la tarjeta no abre el detalle; superficie de «en revisión».
- Al ser aprobado, la puerta se abre sin relanzar la app.
- Nada de contenido financiero ni botones de escritura a la vista para un pendiente.
- Servidor sin cambios.
- Tests + gate; board + `docs/TICKETS.md` al día.

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board, actualizar `docs/TICKETS.md`, merge y `/cerrar-total` sin preguntar si corre el gate o el commit. Bugs/decisiones nuevas → ticket propio antes de cerrar. Solo parar ante decisión/acceso real de Jürgen.

## Que NO hay que tocar
- marketing/, clinicas-dentales-bi.
- No tocar DDL / servidor para quitar pending de la lista.
- No reabrir la tensión de producto (puerta vs sala de espera) — ya decidida.
- No inventar selector de heredero ni tocar owner-transfer salvo residual documentado en ticket propio.

## Como se sabe que esta bien
- AC del ticket cumplidos.
- Gate verde; PR mergeado a 2.1; board + `docs/TICKETS.md` al día; `/cerrar-total`.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL y key en fichero local, no en git; no las escribas en el repo) cuando:
  (1) necesitas una decisión de producto o de acceso de Jürgen;
  (2) abriste el PR o dejaste preview/artifact listo;
  (3) terminaste el ticket y vas a /cerrar-total — incluye en el aviso un resumen corto de cierre en lenguaje de usuario (qué se hizo), no solo «cerré»;
  (4) acabaste un tramo y no tienes siguiente paso claro (aunque no haya pregunta formal) — una vez, no en bucle.
NO avises por: un test rojo que vas a reclasificar, un build que vas a reintentar, ni ruido de CI advisory. URL/key solo en la Mini.
