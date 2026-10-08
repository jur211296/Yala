---
id: welcome-cancel-during-the-identity-step-does-not-return-to-the-chooser
status: backlog
priority: medium
area: "modo-nube, onboarding"
created: 2026-09-24
updated: 2026-10-08
source: "review adversarial de `migration-takeover-uploads-without-a-lineage-check` (2026-09-24), lente del runner y el copy"
---

# Cancelar desde la bienvenida con la activación al 35 % no te devuelve a elegir

## El problema, en lenguaje de usuario

Entro en mi cuenta desde la bienvenida («Ya tengo una cuenta») y la cuenta tenía una activación a medias de otro
teléfono: este toma el relevo y la barra se queda al 35 % mientras comprueba que sus datos casan con los de la cuenta. Si
toco «Cancelar la activación», la pantalla no vuelve a la de elegir: se queda en la barra.

## Lo medido (2026-09-24, leído en el código, sin ejecutar)

- La marca `.cancelled` (`MigrationState.adoptClaimExitRaw`) solo se escribe si `AdoptClaimScope.isAdoptClaim`, que cubre el
  claim y la espera del seguidor, no `assigningIdentity`.
- `WelcomeAdoptCancel.afterCancel` exige esa marca para volver al chooser; sin ella devuelve `.keepPolling` y la pantalla
  sigue en `.adopting(0)`.
- El hueco ya existía, pero el paso de identidad duraba segundos. Desde la comprobación de linaje del relevo puede durar
  hasta 15 min, justo en la entrada de la bienvenida.

## Criterios de aceptación

- [ ] «Cancelar la activación» en la bienvenida devuelve a elegir también con la activación en la identidad.

## Medido en 2.1 (triage 2026-10-08)

- `ForwardCancelScope.offersCancel` incluye `.assigningIdentity` (`MigrationRunner.swift`, ~193), así que el botón sale; `AdoptClaimScope.isAdoptClaim` solo cubre `claimingMigration` y `waitingForLeader` (~255), y la cancelación no escribe `.cancelled`.
- `WelcomeAdoptCancel.afterCancel` (`CloudWelcomeSignInFlow.swift`) exige esa marca: devuelve `.keepPolling` y la pantalla se queda en `.adopting(0)`. Ahí `canGoBack` es `false`, y «Retomar» con `cancelRequested` solo llama a `resumeIfNeeded`, que no hace nada sobre un `notStarted`.
- La única salida es matar la app, y aterriza en MainTab vacío (el onboarding ya se marcó en `onAdoptStarted`), no en la bienvenida. Por eso sube: es una pantalla sin salida, aunque solo en el relevo con comprobación de linaje.

Triage 2026-10-08: abierto · low → medium · tras cancelar en la identidad la pantalla no tiene salida y solo matando la app se sale (WelcomeAdoptCancel.afterCancel).
