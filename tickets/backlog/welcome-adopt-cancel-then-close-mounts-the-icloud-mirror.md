---
id: welcome-adopt-cancel-then-close-mounts-the-icloud-mirror
status: backlog
priority: low
area: "onboarding, modo-nube"
created: 2026-11-04
updated: 2026-11-04
source: "review adversarial (lente de montaje) del lote N1 de la 2.3, bienvenida"
---

# Cancelar la entrada a la cuenta en la bienvenida y cerrar la app monta el espejo de iCloud y entra a la app

## En lenguaje de usuario

Instalación nueva. En la bienvenida toco «Ya tengo una cuenta», entro, empieza a traer mi cuenta y toco «Cancelar»:
vuelvo a la bienvenida. Si cierro Yala ahí y la abro, ya no veo la bienvenida y el teléfono adjunta mi iCloud privado.

## Lo leído (2026-11-04, inferido; no medido en un aparato)

- `onAdoptStarted` (`ContentView.swift`) retira el neutro (`retireNeutralMountOnChoice`) y pone
  `hasCompletedOnboarding = true` (su seguridad ante un kill), y la salida del adopt por `onBack` no deshace ninguna de
  las dos. El `hasShownWelcomeChooser = false` del lote N1 no recupera el neutro.
- Ya pasaba antes del lote N1 (`welcome-cloud-back-leaves-chooser-marked-seen`, `welcome-fresh-install-neutral-mount-lasts-one-launch`).

## Qué habría que decidir

Si la salida del adopt (cancelar, o el techo) devuelve el neutro y el onboarding a «sin hacer», o si basta con lo de
hoy porque el adopt cancelado ya dejó escrito algo de la cuenta.
