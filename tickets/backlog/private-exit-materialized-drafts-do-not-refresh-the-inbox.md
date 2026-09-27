---
id: private-exit-materialized-drafts-do-not-refresh-the-inbox
status: backlog
priority: very-low
area: "inbox, settings"
created: 2026-09-26
source: "review adversarial de `private-exit-loses-unmaterialized-inbound-captures` (lente de efectos colaterales)"
---

# Los borradores que crea la espera del cierre privado no aparecen en la Bandeja hasta el siguiente refresco

## Qué pasa, en lenguaje de usuario

Empiezo a cerrar sesión, la espera convierte en borrador un pago de Apple Pay que estaba en cola, y yo toco «Ahora
no» y vuelvo a la app. La Bandeja no lo enseña hasta que salgo y vuelvo, o hasta que llega otro cambio.

## Lo medido (2026-09-26)

`InboundCaptureDrain.forSignOut` crea borradores desde `CloudSessionSignOut`, que no toca `sessionState`, y
`InboxView` refresca con `dataVersion`. Los otros drenados (arranque, foreground, remote-change) sí incrementan
`dataVersion`. Solo cosmético: el borrador está en el store.
