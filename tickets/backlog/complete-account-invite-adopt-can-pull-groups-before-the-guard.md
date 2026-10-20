---
id: complete-account-invite-adopt-can-pull-groups-before-the-guard
status: backlog
priority: medium
area: "groups, modo-nube, onboarding"
created: 2026-10-19
updated: 2026-10-19
source: "review adversarial de `invite-sign-in-with-a-complete-account-blocks-on-its-own-groups` (2026-10-19)"
---

# Con una cuenta completa por enlace, el arranque o el primer plano aún pueden bajar sus grupos antes del guard

## En lenguaje de usuario

Entro por un enlace con mi cuenta completa y, si a mitad del recorrido Yala se relanza o paso por otra app, puede volver a decirme «Este dispositivo tiene datos de otra cuenta» por mis propios grupos.

## Lo medido (leído en el código, 2026-10-19)

- `invite-sign-in-with-a-complete-account-blocks-on-its-own-groups` quitó el arranque del canal de Grupos de la hoja de Grupos con destino `.adoptAsCompleteAndOpenGroups`.
- Pero el arranque en frío (`AppBootstrapper`, paso del canal de Grupos) y la vuelta a primer plano también llaman a `GroupsSyncClient.startIfEligible`, que solo mira el flag y la sesión. Entre la firma de la hoja y el recuento del guard del Welcome (`CrossAccountEntryGuardLogic`, que cuenta `SplitGroup`), cualquiera de los dos baja los grupos de la cuenta.
- INFERIDO, sin medir en un aparato: con qué frecuencia cae una activación en ese hueco. Un relanzamiento a mitad lo hace seguro.

## Lo que habría que decidir

Un candado durable «alta de cuenta completa en curso» (por `sub`, con caducidad) que `startIfEligible` respete hasta `onAdoptStarted`, o que el guard no cuente los grupos que bajó la propia sesión que firma.
