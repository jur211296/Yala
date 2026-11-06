---
id: apple-pay-capture-in-a-groups-only-session-has-no-personal-inbox
status: qa
priority: medium
area: "intents, inbox, sesiones"
created: 2026-10-08
updated: 2026-11-06
source: "medido de paso en `after-session-redesign-review-widgets-siri-applepay-and-web-copy` (punto «Siri y Apple Pay con sesión solo grupos»)"
---

# Una compra de Apple Pay en una sesión solo grupos se convierte en un borrador personal que esa sesión no enseña

## Lo medido (2026-10-08, árbol `da5efd6fb`)

- El atajo de Apple Pay no mira la sesión: `ApplePayTransactionIntent.perform` (`Yala/App/Intents/QuickExpenseIntent.swift`) encola
  el pago en el App Group sin más puerta que el importe.
- Al volver a primer plano, `InboundCaptureDrain.drain` lo convierte en `InboxDraft` del store PERSONAL. Su única puerta
  es el borrado de cierre armado; no mira `PrivateSessionMark`.
- En solo grupos el store personal no tiene cuentas reales, así que el borrador nace con la cuenta pendiente.
- `AppBootstrapper.checkForPendingInboxDrafts` tampoco mira la sesión: cuenta ese borrador para el aviso de la Bandeja.
- Siri sí se para (`SiriNaturalEntryIntent`): con el snapshot de contexto escrito, `hasRealAccount == false` en solo grupos y el intent contesta
  «no hay cuentas» sin encolar.

## Lo inferido, sin medir

- Que la shell de solo grupos no enseña la Bandeja personal (`TabBarConfiguration.forMode(reduceToGroupsOnly:)`): el
  borrador quedaría invisible hasta activar Yala completo, y el aviso de la Bandeja podría salir sobre una shell que no
  la tiene.

## Lo que hay que decidir (Jürgen)

1. **Nada**: el borrador espera y aparece al activar Yala completo, que es la puerta que el widget ya ofrece.
2. **El atajo contesta como Siri**: en solo grupos no encola y dice que falta activar Yala completo.
3. **Se encola pero no se materializa** hasta que haya sesión privada.

## Criterios de aceptación

- [ ] Medido en el simulador: con `-uitest-seed solo-grupos-tras-aviso` y un pago encolado, qué pasa al abrir.
- [ ] La opción elegida tiene su test de comportamiento.

## Resuelto (2026-11-06, encargo «Lote · Grupos: Vaciar datos y Apple Pay»)

La decisión de producto ya estaba tomada: el 2026-10-27 (encargo S11e) Jürgen eligió la opción 2 y el atajo de Apple
Pay no encola en «Solo grupos» (`GroupsOnlyIntentGate`, avisa y enlaza a Yala completo). Siri igual. El aviso de la
Bandeja ya estaba pausado en esa shell (`PersonalRemindersPause`).

Lo que quedaba abierto, y se cierra aquí: los pagos que YA esperaban en la cola (encolados antes de quedarse en solo
grupos, o por un build anterior) los materializaba `InboundCaptureDrain.drain` como borrador del store personal sin
sesión privada. Ahora, sin sesión privada (eje, gate de datos), Apple Pay y Siri se quedan en el App Group y se
convierten en borrador al activar Yala completo. Con sesión privada y «Solo grupos» elegido se materializan como
siempre: el store personal es real y el aviso espera.

Tests: `PrivateExitInboundCaptureLogicTests` (con y sin sesión privada) y el source-scan del drenaje.

Pendiente de device-QA (no bloquea): con un teléfono en solo grupos sin sesión privada, un pago de Apple Pay que ya
estaba en cola no aparece como borrador; al activar Yala completo, sí.
