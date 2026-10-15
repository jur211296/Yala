---
id: inbox-alert-scheduled-count-has-no-singular
status: backlog
area: "l10n, bandeja"
priority: low
created: 2026-10-15
updated: 2026-10-15
source: "Barrido de QA 2.1 (Frank, 2026-10-15), visto en el simulador"
---

# El aviso de la Bandeja dice «Se añadieron 1 pagos planificados»

## Qué pasa

Con un solo pago planificado vencido, al abrir Yala sale «¡Tienes pagos pendientes!» con el texto
«Se añadieron 1 pagos planificados a tu bandeja.». Debería decir «Se añadió 1 pago planificado».

Visto en el barrido de QA del 2026-10-15, en el simulador (Yala Dev, iPhone 17 Pro, iOS 27.0), con un pago «Una sola
vez» que vencía ese día. Captura: `~/Claude/worktrees/_capturas/2026-10-15-barrido-qa-2-1/a4-2-toque-en-frio-abre-presupuestos.png`.

## Medido en el código (`a10168931`)

- `L10n.swift:6544` arma el texto con `String(format: ls("inbox.alert.message.scheduled"), count)`.
- `inbox.alert.message.scheduled` e `inbox.alert.message.subscriptions` solo existen en `Localizable.strings`, en
  plural fijo, en los 16 idiomas (32 líneas).
- Su vecino `inbox.alert.message.automations` sí está en `Localizable.stringsdict` con `one`/`other` (commit
  `a4a71f0ca`, M4). Las otras dos claves se quedaron fuera de esa tanda.
- `scheduled.draftCreatedMessage` («Se añadieron %d pagos planificados a tu bandeja. Revísalos cuando quieras.») tiene la
  misma forma; comprobar si se usa con 1.

## Hecho cuando

Con 1 pago o 1 suscripción el aviso sale en singular en los 16 idiomas, y la batería de paridad de l10n sigue verde.
