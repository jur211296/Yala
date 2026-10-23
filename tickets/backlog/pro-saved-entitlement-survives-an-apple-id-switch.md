---
id: pro-saved-entitlement-survives-an-apple-id-switch
status: backlog
priority: low
area: pro
created: 2026-10-22
updated: 2026-10-22
---

# El Pro de un Apple ID sigue en el teléfono al entrar con otro Apple ID sin Yala

## Qué le pasa al usuario

Uso Yala Pro con mi Apple ID. En el mismo iPhone cambio a otro Apple ID que nunca compró Yala. Yala sigue en Pro
hasta que vence lo que pagó el primero, sin que el segundo pague nada.

## Por qué

`StoreKitManager` guarda el último derecho verificado en `UserDefaults.standard` (`yala.lastVerifiedPro*`), por
teléfono y no por Apple ID. Con `Transaction.currentEntitlements` vacío, `ProSubscriptionActivationLogic.localActive`
lo conserva a propósito (el retraso de StoreKit tras comprar), y nada lo borra al cambiar de Apple ID.

Desde el 2026-10-22 (card `tablero-al-renovar-desde-tu-suscripcion-termino-7c97`) el derecho guardado lleva el
`originalID` de la suscripción, y una transacción caducada de OTRO Apple ID ya no lo conserva: sigue mandando. Lo que
queda abierto es la lista vacía: el Apple ID nuevo no tiene nada de Yala que listar.

## Lo que hay que decidir

Si el caso merece cerrarse. Pasa en un teléfono donde el primer Apple ID sí pagó, y cerrar la lista vacía obliga a
distinguir «StoreKit aún no lista la compra» de «este Apple ID no tiene nada». Lo midió la review adversarial del
2026-10-22 leyendo el código; no se ha reproducido en un teléfono.
