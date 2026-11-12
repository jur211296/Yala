---
id: notification-tap-opens-inbox-then-inbox-notice-pops-after
status: done
priority: high
area: notifications
created: 2026-10-30
updated: 2026-10-30
source: tablero tablero-tocar-una-notificacion-abre-su-destino-e-0443 (pedido de Jürgen, 2026-10-29 05:36 Lima)
---
# Tocar una notificación abre su destino; la de Apple Pay abre la Bandeja sin el aviso detrás

Pedido: al tocar una notificación automática se abría la Bandeja y después salía el aviso «tienes gastos en la Bandeja».
Sesión autónoma de noche (S27g): las decisiones abiertas se tomaron por la opción conservadora; están en el Paso 0 de
`encargos/lanzados/2026-10-30-notificaciones-abrir-destino-correcto.md` y en el PR.

## Qué cambia para quien usa Yala

- Al tocar la notificación de un pago de Apple Pay (o de un dictado de Siri) se abre la Bandeja con el pago, y el aviso
  «tienes borradores nuevos» **ya no sale**: ni con la Bandeja abierta, ni al cerrarla, ni la siguiente vez que abras Yala.
- Si el aviso llegó a salir un instante antes que el toque, se cierra solo y aparece la Bandeja en su lugar.
- Lo mismo al abrir la Bandeja con su botón del Panel mientras el aviso esperaba turno: ya no salta al cerrarla.

## Causa

La notificación lleva `deepLink: "inbox"` y su toque encola `.navigate(.inbox)` (→ `.presentInboxSheet` en el Panel). El
mismo primer plano convierte lo encolado por Apple Pay o Siri en borradores (`InboundCaptureDrain`) y pide
`.showInboxAlert` (`checkForPendingInboxDrafts`). Solo había dos defensas: la orden de abrir tiraba el aviso que ya
esperaba en cola, y la puerta tiraba el que llegaba con la hoja ya pintada. Un aviso que llegaba **entre medias** —con
`.navigate(.inbox)` o `.presentInboxSheet` aún en cola, o con la hoja abriéndose— entraba, esperaba detrás de la hoja
(`contentViewHoldsForForeignPresentation`) y salía al cerrarla. Y como un aviso tirado no quemaba sus firmas, volvía en
el primer plano siguiente con los mismos borradores (el residual que documentaba `commitPendingInboxAlertSignatures`).

## Hecho

- `IntentSupersessionLogic`: regla `queuedInboxOpening_supersedes_incomingShowInboxAlert` (campo nuevo
  `dropsIncomingWhenQueued`) y `opensInbox(_:)`.
- `RouterEntryGate.inboxSheetDidAppear()`: la hoja de la Bandeja, al aparecer, retira los avisos en cola y da por avisados
  sus borradores (`PanelSheetsModifier`).
- `ContentView.routerRevisionChanged()`: con el aviso en pantalla y la orden de abrir la Bandeja en cola, cierra el aviso
  antes de drenar (hallazgo de la review).
- `checkForPendingInboxDrafts`: con la Bandeja abierta en la ventana de delante, quema sin pedir aviso. Solo la de
  delante: con la hoja abierta en una ventana de detrás (iPad) el aviso se aplaza como antes (hallazgo de la review).
- Seam `-uitest-inbox-notification-tap <cold|warm-tap-first|warm-check-first|foreground>` +
  `-uitest-notification-tap-link <deepLink>`: el toque entra por `routeTap` y el aviso lo pide su productor real.
- `docs/entry-points.md`: tabla «Tocar una notificación: a dónde lleva cada una».

## Mapa: cada notificación → destino

Ver la tabla en `docs/entry-points.md` («Tocar una notificación»). Cobertura en el simulador:

| Notificación | Cerrada | Segundo plano | Delante |
|---|---|---|---|
| Apple Pay / Siri (`inbox`) | XCUITest | XCUITest (toque antes y después del aviso) | XCUITest (con el aviso en pantalla) |
| Resumen de pagos (`scheduledPayments`) | XCUITest | XCUITest | XCUITest |
| Recordatorio diario (`recordsStandalone`) | XCUITest | XCUITest | XCUITest |
| Push de varios grupos (`groups`) | XCUITest | XCUITest | XCUITest |
| Pago (`scheduledPayments/<uuid>`), tarjeta (`accounts/<id>`), presupuesto (`budgets/<uuid>`) | mismo `routeTap` | mismo `routeTap` | XCUITest previos (L9-5, L10-13, L10-14) |
| Informe (`statistics/…`), grupo (`groups/<uuid>`) | XCUITest previos (enlace) | — | XCUITest previos |

El destino lo decide `parseDestination` y es el mismo en los tres estados: lo que cambia entre ellos es el camino de
entrada (aplazado en frío, en el `.active` al volver, directo delante), que es lo que cubren las tres columnas.

## QA en iPhone (no bloquea el merge)

Lo único que el simulador no puede: el banner real de iOS y el orden real de `didReceive` frente al primer plano.
Montaje: Yala Dev o TestFlight con este cambio; la automatización de Wallet que llama a «Registrar pago de Apple Pay»
(Atajos › Automatización › Wallet). Si no la tienes, Siri vale igual: «Oye Siri, anota en Yala 20 soles de taxi».

1. **Con Yala en segundo plano.** Abre Yala, ve al Panel y sal al inicio (desliza hacia arriba). Paga con Apple Pay (o usa
   Siri). Toca la notificación «Pago de … por revisar».
   Esperado: se abre la Bandeja con ese pago. **No** sale el aviso «tienes borradores nuevos». Cierra la Bandeja con la X:
   tampoco sale.
2. **Vuelve a abrir Yala** desde el icono sin tocar nada. Esperado: no sale el aviso de ese pago.
3. **Con Yala cerrada.** Ciérrala desde el selector de apps (desliza la tarjeta hacia arriba). Repite el pago y toca la
   notificación. Esperado: Yala arranca, se abre la Bandeja con el pago y no sale el aviso, ni al cerrar la Bandeja.
4. **Con Yala delante.** Con Yala abierta, usa Siri desde el botón lateral para anotar un gasto; cuando baje el banner,
   tócalo. Esperado: se abre la Bandeja con el dictado; sin aviso detrás.
5. **Control.** Con Yala en segundo plano, paga (o usa Siri) pero **no** toques la notificación: abre Yala desde el icono.
   Esperado: ahora sí sale el aviso «tienes borradores nuevos» (esto no cambió).

## Encontrado (fuera de alcance)

- `.navigate(.groups)` sin id saca la hoja educativa de Grupos en el `onAppear`, sin candado (anotado por S27f, sin medir).
- El push de varios grupos (`deepLink: "groups"`) no lo retira `clearDeliveredGroupNotifications`, que filtra por
  `hasPrefix("groups/")` (anotado por S27f).
- Delante y sin pasar por `.active`, un pago de Apple Pay encolado no se materializa hasta el primer plano siguiente o el
  borde del cambio remoto: en la práctica Wallet o Siri dejan la app inactiva y al volver se drena. Se mira en el paso 4.

Cerrado en el barrido de QA 2026-10-30: criterio estricto (filtro doble); motivo y evidencia en docs/qa/tanda-qa-jurgen-2.2-barrido-2026-10-30.md.
