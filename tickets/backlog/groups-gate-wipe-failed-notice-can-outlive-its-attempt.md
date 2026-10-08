---
id: groups-gate-wipe-failed-notice-can-outlive-its-attempt
status: backlog
priority: low
area: "modo-nube, groups"
created: 2026-09-30
updated: 2026-10-08
source: "review adversarial de `sign-out-wipe-abort-loops-the-groups-gate` (lentes 1 y 2)"
---

# El aviso «No pudimos preparar este teléfono» puede salir días después sin un intento detrás

## Lo medido (2026-09-30)

El testigo `GroupsGateWipeFailureMarker` se retira al salir del aviso, cuando la puerta deja pasar, con un borrado
que completa, con «Vaciar datos» y con `-uitest-reset`. Queda un camino sin retirada: la persona ve el aviso, **mata
la app sin tocar nada**, y en el arranque siguiente (el destino ya se consumió) elige Restaurar o el onboarding
privado y entra en la app. El testigo sigue puesto (`cloudSync.*` lo saca del barrido).

Si más adelante vuelve a la puerta de Grupos con datos y el espejo montado, la primera vez ve «No pudimos…» sin que
se haya intentado nada. Se cura con un «Volver». No hay pérdida de datos ni bucle.

## Por dónde va

- Que el testigo guarde la fecha y caduque (p. ej. 24 h), o
- retirarlo cuando el onboarding termina (`hasCompletedOnboarding = true`).

## Criterios de aceptación

- [ ] Un testigo de un intento de hace días no enseña el aviso en una puerta nueva.
- [ ] El aviso sigue saliendo en el arranque que sigue al borrado que no pudo.

## Medido en 2.1 (triage 2026-10-08)

- `GroupsGateWipeFailureMarker` sigue siendo un `Bool` sin fecha (`cloudSync.groupsGate.wipeCouldNotDelete`), y nadie lo retira al completar el onboarding: las retiradas son la salida del aviso y el paso de la puerta (`WelcomeGroupsGateView`), un borrado que completa (`SwiftDataConfiguration`, `DataWipeService`) y `-uitest-reset`.
- El único commit posterior que lo toca (`9e5b6b0bf`) no cambió eso.

Triage 2026-10-08: abierto · low → low · el testigo sigue sin caducidad ni retirada al terminar el onboarding; el aviso falso se cura con «Volver» y no pierde datos.
