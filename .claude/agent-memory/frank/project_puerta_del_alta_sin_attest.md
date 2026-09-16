---
name: puerta-del-alta-sin-attest
description: 16-sep — sin App Attest no se ofrece darse de alta en la nube por ninguna puerta del Welcome (card, «Crear mi cuenta», «Crear cuenta con…»); los dos tickets en qa esperan pasos en iPhone real, y el simulador sin el secreto de dev ya no crea cuentas en la nube, a propósito
metadata:
  type: project
---

**Un teléfono que no puede conseguir App Attest ya no se da de alta en la nube desde el Welcome** (2026-09-16, dos encargos,
opción 1 en los dos). Una sola puerta, `WelcomeNewOptionsGate` (`offersCloudSignUp` = `live.contains(.cloudAccount)`):

- PR #180 (`cloud-onboarding-offers-the-cloud-to-a-phone-without-app-attest`): la card «Tu cuenta en la nube» de «Es mi
  primera vez», «Crear otra cuenta» y «Activar Yala completo».
- El PR siguiente (`cloud-sign-in-screen-offers-sign-up-to-a-phone-without-app-attest`): «Crear mi cuenta» tras «No
  encontramos una cuenta» y «Crear cuenta con…» del mismatch. Sin la puerta, «No encontramos una cuenta» ofrece «Volver»:
  lo decidió Jürgen a las 6:1x cuando la review cazó que mi primera versión dejaba solo la flecha de la esquina.

**Why:** era la decisión del owner del 2026-07-06. El fallo caro es el inverso —un iPhone real que pierde la card o el
botón— y ningún simulador lo prueba: por eso los dos tickets se quedan en `qa`.

**How to apply:**

- Si un `/qa` coge estos tickets, los pasos en iPhone real comparten montaje (instalación nueva de TestFlight). **Borrar la
  app se lleva lo que no esté en iCloud o en la nube**: el guion lo avisa, respétalo. Y el faro de iCloud puede cambiar
  «No encontramos una cuenta» por el mismatch: los dos valen.
- **Si en el simulador no sale «Tu cuenta en la nube» ni «Crear mi cuenta», no es la configuración remota: es esta
  puerta.** La devuelve `Yala Dev` con `YALA_DEV_SHARED_SECRET` en el scheme, y ese secreto **no está en `~/Secrets`**
  (medido dos veces el 16-sep): es un secret de Wrangler del gateway de staging, que no se lee de vuelta. Lo tiene Jürgen
  o hay que rotarlo.
- Queda en `backlog` «Migrar a la nube» (`cloud-migration-offers-the-cloud-to-a-phone-without-app-attest`), el único
  camino al alta completa que no mira la puerta.

Relacionado: [[telefono-sin-attest-veredicto-y-salida]] · [[aviso-attest-personal-en-dos-superficies]] ·
[[el-source-scan-de-dos-literales-no-es-una-red]]
