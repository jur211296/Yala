---
id: subscription-success-without-pro
status: in-progress
priority: high
area: subscription
created: 2026-08-22
updated: 2026-08-26
source: YalaWiki/Bugs/tf-suscripcion-exito-sin-pro.md
---


# Sheet de éxito de suscripción sin quedar Pro (TF 2.1 build 11)

## Síntoma

En TestFlight (2.1 build 11), cuenta oficial de Yala en dispositivo personal: el sheet de suscripción sandbox completa, aparece el sheet de éxito, pero la app **no** queda Pro (sigue el límite de cuentas Free, etc.).

## Por qué importa

En TF la compra sandbox debe dejar Pro igual que en producción. Celebrar sin entitlement es engañoso y puede pasar en prod si `currentEntitlements` va atrasado al éxito de `purchase()`.

## Hipótesis (código, no PASS)

En `StoreKitManager.purchase`:
1. `product.purchase` → `.success`
2. `transaction.finish()`
3. `await updateSubscriptionStatus()` (lee `Transaction.currentEntitlements`)
4. `didJustSubscribe = true` **siempre**, sin comprobar `isProUser`

`SubscriptionView` abre `SubscriptionSuccessView` solo con `didJustSubscribe`. Si el paso 3 no ve aún la suscripción activa, hay celebración y Free.

## Qué no es

- No es “quirk esperado de TF”.
- No confundir con Yala Dev (bundle `.dev` fuerza Free salvo flags).

## Repro

1. TF 2.1 (11), cuenta día a día, Free.
2. Suscribirse (sandbox).
3. Ver sheet de éxito.
4. Comprobar límites Free (cuentas, etc.).

## Checks owner

- Force-quit + reopen: ¿Pro?
- Restaurar compras: ¿Pro?


## Owner check 2026-08-22 (Jurgen, TF 2.1 build 11)

- Force-quit + reopen: **sigue Free**.
- Restaurar compras: pide contraseña Apple; al ingresarla **no pasa nada** (sigue Free, sin feedback claro).

No es race de un segundo tras el sheet. Entitlement no queda activo (o no se lee) tras compra ni tras `AppStore.sync()`.

## Fix propuesto (cuando haya slice)

- Tras `.success`, marcar Pro desde la `Transaction` verificada de la compra (no solo re-leer entitlements).
- Abrir sheet de éxito solo si `isProUser == true`; si no, reintentar `updateSubscriptionStatus` / escuchar `Transaction.updates` antes de celebrar.

## Estado 2026-08-22

- PR #20 merged a `2.1` @ `299ca811` (head `74ddaf01`).
- Mini pull 2.1 al día @ `299ca811`.
- CI tests SUCCESS (UI ~55 min).
- **No ok_ / no PASS device.** Fix en árbol; verificación en TF pendiente (solo si Jurgen pide upload build 12).
- HOLD: App Store, tag, A7/M5.

## TestFlight 2026-08-22

- 2.1 build **12** VALID en TestFlight (asc id `e961a77b`, bump `f4cf3d2b`).
- Fix PR #20 está en ese binario.
- **No ok_ / no PASS device** hasta check owner en TF 12.
- HOLD: App Store, tag, A7/M5.

migrated from YalaWiki Bugs/tf-suscripcion-exito-sin-pro.md @ 1934e8ad
