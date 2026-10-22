# Etiquetar el hero de Estadísticas (stock vs flujo entre pestañas)

## Contexto
Ticket: `tickets/backlog/hero-estadisticas-stock-vs-flujo-entre-pestanas.md` (medium). Tras #78, Distribución muestra saldo (stock) y Tendencias/Insights/Registros muestran neto del período (flujo), mismo hueco visual sin rótulo.

**Decisión Jürgen (2026-09-06) — no repreguntar:** etiquetar el número. No igualar a stock/flujo ni dejarlo sin rótulo. No revierte el 26-ago (Distribución = Panel).

Cola medium autónoma (Frank): tras /cerrar-total, Frank lanza welcome-privacy → panel-cuentas → reentry-killswitch → features → CI timeout.

## Que se pide
Implementar AC del ticket:
- Rótulo bajo el hero en las 4 pestañas: Distribución «Saldo de cuentas» (o equivalente brand); las otras tres «Neto del período».
- Copy 16 `.lproj`; `/l10n-check` verde.
- Cero cambio de cálculo.
- Reescribir comentario TrendsTabView de «coherencia cross-tab».
- Device-QA documentado (4 pestañas deslizando) — si no hay device, ticket a qa con AC marcado.
- Board + `docs/TICKETS.md` al día.

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board, `docs/TICKETS.md`, merge y `/cerrar-total` sin preguntar. Bugs/decisiones nuevas → ticket propio. Solo parar ante decisión/acceso real de Jürgen.

## Que NO hay que tocar
- marketing/, clinicas-dentales-bi.
- No cambiar el cálculo de ningún hero ni revertir Distribución = Panel.
- No igualar las cuatro a stock o flujo.

## Como se sabe que esta bien
- AC (salvo device-QA explícito en qa); PR mergeado a 2.1; board + índice; `/cerrar-total`.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL/key en fichero local, no en git) cuando:
  (1) decisión/acceso Jürgen; (2) PR abierto; (3) /cerrar-total con resumen de usuario; (4) sin siguiente paso — una vez.
NO avises por test rojo a reclasificar, build a reintentar, ni CI advisory.
