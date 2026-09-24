---
id: welcome-adopt-exit-offers-retry-on-a-blocked-account
status: backlog
priority: low
area: "modo-nube, onboarding, adopt"
created: 2026-09-23
updated: 2026-09-23
source: "review adversarial de `welcome-adopt-effect-failure-has-no-reason-and-no-cancel` (2026-09-23), lente de SwiftUI y copy"
---

# Si la cuenta no te deja entrar, la bienvenida puede ofrecer «Reintentar» bajo un «Escríbenos»

## El problema, en lenguaje de usuario

Si el claim del adopt vence su techo de 15 min con la cuenta rechazándolo (403) y la bienvenida ya no tiene el bloqueo
en memoria, la pantalla dice «ahora mismo no podemos darte acceso a esta cuenta. Escríbenos a…» con un botón
«Reintentar» que no arregla nada. La pantalla propia del 403 (`.accountBlocked`) no lo ofrece.

## Por qué pasa (leído el 2026-09-23; no ejecutado)

`CloudWelcomeSignInPhase.adoptExit(.accountUnavailable)` siempre pinta «Reintentar», como la tarjeta de Almacenamiento.
Normalmente gana antes `claimBlocker` (`.accountBlocked`), que el runner guarda en memoria; que falte con la marca puesta
es inferido y raro: ocurre solo si el proceso perdió ese estado sin perder la pantalla.

## Qué habría que hacer

Mapear `.adoptExit(.accountUnavailable)` a `.accountBlocked`, o quitar «Reintentar» en ese motivo. Técnico, low.
