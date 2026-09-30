---
id: groups-gate-wipe-failed-notice-can-outlive-its-attempt
status: backlog
priority: low
area: "modo-nube, groups"
created: 2026-09-30
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
