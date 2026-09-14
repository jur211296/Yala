---
id: activation-resume-returns-to-restore-on-an-emptied-zone
status: backlog
priority: low
area: "onboarding, modo-nube"
created: 2026-09-14
source: "review adversarial del PR de `activation-restore-start-fresh-keeps-the-imported-rows` (2026-09-14); NO reproducido en device"
---

# Matar la app justo después de borrar devuelve a «Restaurar», sobre una cuenta ya vacía

## El síntoma, en lenguaje de usuario

Borro mis datos de iCloud desde «Activar Yala completo», empiezo el onboarding y cierro la app por lo que
sea. Al reabrirla me sale otra vez la pantalla de **Restaurar**, buscando en un iCloud que yo mismo acabo
de vaciar. Me dice que no encuentra nada.

## Lo medido (2026-09-14)

- `FullModeActivationResumeStore` sigue valiendo `.restore` hasta `completeFullActivation`
  (`FullModeActivationView.swift`), así que `initialScreen` reabre la activación en `.restore`.
- Es **recuperable**: «Empezar desde cero» vuelve a la puerta, que mide vacío y deja pasar al onboarding.
  Pero es un sitio confuso donde aterrizar justo después de haber descartado a conciencia.
- Lo barato sería reescribir la marca a `.privateOnboarding` cuando el borrado confirma — el mismo gesto
  que ya hace `WelcomePendingDestinationStore` con su destino.

## Criterios de aceptación

- [ ] Tras un borrado confirmado, un kill durante el onboarding reabre la activación **en el onboarding**,
      no en Restaurar.
- [ ] Un kill ANTES de que el borrado confirme sigue volviendo a la puerta, que re-mide (eso no cambia).

## Relacionados

- [[activation-restore-start-fresh-keeps-the-imported-rows]]
