---
id: group-share-to-zero-leaves-the-recharge-entry-orphaned
status: backlog
priority: low
area: "grupos, puente"
created: 2026-11-02
updated: 2026-11-02
source: "review adversarial del encargo 2026-11-02-grupos-b-cabos-sueltos (lente de consumidores), previo al cambio"
---

# Si tu parte de un gasto pasa a 0, la entrada de su recarga se queda huérfana

En el Caso B (pagó otro), cuando tu parte baja a 0, `GroupTransactionBridge.createCaseBVirtualMyShare` borra la pata de
«Grupos» con `context.delete(existing)`, no con `deleteLegWithEntries`. Si esa pata era la salida de una recarga (la ancla
de la receta era una recarga), su entrada en la cuenta destino se queda sin pareja. Y el aviso de «no cuadra» de esa
pasada sale con `holder: nil`. Inferido leyendo el código: no está comprobado que un `SplitShare` de importe 0 llegue a
ese camino (puede que el reparto lo quite antes).
