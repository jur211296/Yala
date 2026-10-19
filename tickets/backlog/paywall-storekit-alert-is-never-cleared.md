---
id: paywall-storekit-alert-is-never-cleared
status: backlog
priority: low
area: pro, paywall, storekit
created: 2026-10-19
updated: 2026-10-19
source: lote decidido 2.2 · 06 — Yala Pro (encargo 2026-10-19-lote-decidido-2-2-06-yala-pro, PR #561)
---

# El aviso de error de StoreKit no se vacía en el paywall y en la oferta: el mismo error dos veces no avisa

## Qué pasa

`StoreKitManager.errorMessage` y `alertTitle` no se vacían nunca en `SubscriptionView` ni en `ProTrialOfferSheet`: las dos vistas muestran la alerta en el `onChange(of: store.errorMessage)`. Si el mismo error sale dos veces seguidas (p. ej. `purchaseNotActivated`), el `onChange` no salta y no se avisa nada. Y un `alertTitle` viejo («No hay compras que restaurar») puede titular un error posterior que no lo fija, como el de verificación de `purchase`.

## Contexto

El lote 06 lo arregló en «Función Pro» (`UpgradePromptSheet.clearStoreAlert()`), que ahora es el camino principal de compra. En el paywall y en la oferta queda como estaba.

## Arreglo

Vaciar los dos al cerrar la alerta en las dos vistas, con el mismo molde.
