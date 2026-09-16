---
name: puerta-del-alta-sin-attest
description: PR del 16-sep — sin App Attest el chooser ya no ofrece «Tu cuenta en la nube»; en qa espera UN paso en iPhone real, y el simulador sin el secreto de dev tampoco la enseña, a propósito
metadata:
  type: project
---

**«Tu cuenta en la nube» ya no se ofrece a un teléfono que no puede conseguir App Attest** (PR #180, 2026-09-16, encargo
nocturno, opción 1). Cubre las tres puertas del gate compartido: «Es mi primera vez», «Crear otra cuenta» y «Activar Yala
completo». El ticket `cloud-onboarding-offers-the-cloud-to-a-phone-without-app-attest` está en `qa`.

**Why:** era la decisión del owner del 2026-07-06, que vivía en una función sin llamador. El fallo caro es el inverso —que
un iPhone real deje de ver la card— y ningún simulador lo prueba: por eso el ticket no va a `done`.

**How to apply:**

- Si un `/qa` coge el ticket, es **un solo paso en iPhone real** con el TestFlight del cambio (guion en el ticket). No hay
  nada que montar en simulador: el lado sin App Attest ya lo cubren tres XCUITest con el predicado real.
- **Si en el simulador no sale «Tu cuenta en la nube», no es la configuración remota: es esta puerta.** El simulador no
  tiene App Attest. La devuelve `Yala Dev` con `YALA_DEV_SHARED_SECRET` en el scheme, y ese secreto **no está en
  `~/Secrets`** (medido el 16-sep: en `yala-gateway/` solo hay `prod-jwt-signing-secret`).
- Quedan dos decisiones de Jürgen en `backlog`, las dos nacidas de medir el alcance:
  `cloud-sign-in-screen-offers-sign-up-to-a-phone-without-app-attest` (trampa o pared en dos pantallas que él abrió) y
  `cloud-migration-offers-the-cloud-to-a-phone-without-app-attest`.

Relacionado: [[telefono-sin-attest-veredicto-y-salida]] · [[aviso-attest-personal-en-dos-superficies]] ·
[[el-source-scan-de-dos-literales-no-es-una-red]]
