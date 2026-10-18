---
id: notification-deeplink-accounts-not-parsed
status: done
priority: low
area: notifications
created: 2026-10-10
updated: 2026-10-18
source: auditoría de puntos de entrada del encargo 2026-10-10-share-image-reading-does-not-always-start
---

# El aviso de saldo de una cuenta no lleva a ningún sitio al tocarlo

## Qué pasa (medido en el código)

`ScheduledPaymentNotificationService` manda la notificación de cuenta con `deepLink: "accounts"`, y
`NotificationService.parseDestination` no tiene ese caso (reconoce `statistics`, `planning`, `budgets`, `records`,
`categories`, `inbox`, `scheduledPayments`, `recordsStandalone` y `groups`). Tocar la notificación abre Yala donde
estuviera, sin navegar.

## Qué falta decidir

A dónde debe llevar: el Panel (donde viven las cuentas) o la ficha de esa cuenta. Con el Panel basta un caso más en
`parseDestination`; la ficha necesita el id de la cuenta en el `userInfo`.

Ver `docs/entry-points.md`.

## Lote 10 (2026-10-14)

Propuesta L10-14 de la auditoría UX 2.2, con card para Jürgen: recomendado abrir la ficha de la tarjeta (hace falta mandar su id en el aviso).

## Resolución (2026-10-18)

Hecho con L10-14 B (Jürgen, 2026-10-15): el aviso de la tarjeta lleva `accounts/<shortcutID>` y abre su ficha en el Panel; «accounts» a secas (avisos ya programados) abre el Panel (`AlertDeepLink`, `PanelAccountAlertOpening`). Tests: `UXAudit22Lote10AlertRoutingTests` y `ScheduledPaymentsLote10UITests#test_cardReminderTap_opensTheAccountSheet`.
