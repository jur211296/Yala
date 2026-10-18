---
id: account-line-relink-can-diverge-when-two-phones-repair-the-same-collapse
status: backlog
priority: low
area: "accounts, cloudkit, identity"
created: 2026-10-18
updated: 2026-10-18
source: review adversarial de multi-currency-accounts-1-model-and-sync (lente de modelo, 2026-10-18)
---

# Dos teléfonos que reparan la misma identidad colapsada pueden dejar una línea de tarjeta suelta

## Qué le pasa al usuario

Una línea en otra divisa de su tarjeta aparece como cuenta suelta y hay que volver a vincularla. No se pierde dinero
ni movimientos: el enlace se lee roto y la cuenta se ve, que es como falla `AccountLineLogic` a propósito.

## Escenario (inferido, no medido)

1. iCloud entrega a dos teléfonos la principal P de una tarjeta con su `shortcutID` colapsado, y la línea L apuntando a
   ese valor.
2. Los dos corren `repairCollapsedIdentityUUIDs` antes de verse: cada uno da a P un UUID aleatorio distinto y reenlaza
   L a su valor.
3. Si en CloudKit gana el registro de P de un teléfono y el de L del otro, L apunta a un valor que no existe en ningún
   sitio, y ningún reenlace posterior lo arregla porque el valor viejo ya no colisiona.

Es la misma clase que ya tienen los espejos CSV de presupuestos con esa reparación, sin la red de la relación M2M.
Requiere un colapso de identidad en una cuenta vieja que después se vinculó: poco probable.

## Qué podría hacerse

Un UUID nuevo determinista (derivado del valor viejo y de algo estable de la cuenta) en vez de aleatorio, para que los
dos teléfonos elijan el mismo. Afecta a todas las identidades que repara, no solo a esta.
