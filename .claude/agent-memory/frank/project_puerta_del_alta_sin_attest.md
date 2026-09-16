---
name: puerta-del-alta-sin-attest
description: 16-sep — sin App Attest no se ofrece la nube ni por el Welcome (card, «Crear mi cuenta», «Crear cuenta con…») ni por la tarjeta de Ajustes (migrar y activar); los tres tickets en qa esperan pasos en iPhone real, y el simulador sin el secreto de dev no crea cuentas en la nube, a propósito
metadata:
  type: project
---

**Un teléfono que no puede conseguir App Attest ya no entra en la nube por ninguna puerta que la ofrezca** (2026-09-16,
tres encargos, opción 1 en los tres). En el Welcome, una sola puerta, `WelcomeNewOptionsGate` (`offersCloudSignUp` =
`live.contains(.cloudAccount)`); en Ajustes, `StorageRowGateLogic.offersCloudMigrationEntry`, con la misma entrada:

- PR #180 (`cloud-onboarding-offers-the-cloud-to-a-phone-without-app-attest`): la card «Tu cuenta en la nube» de «Es mi
  primera vez», «Crear otra cuenta» y «Activar Yala completo».
- PR #181 (`cloud-sign-in-screen-offers-sign-up-to-a-phone-without-app-attest`): «Crear mi cuenta» tras «No encontramos
  una cuenta» y «Crear cuenta con…» del mismatch. Sin la puerta, «No encontramos una cuenta» ofrece «Volver»: lo decidió
  Jürgen a las 6:1x cuando la review cazó que mi primera versión dejaba solo la flecha de la esquina.
- PR #182 (`cloud-migration-offers-the-cloud-to-a-phone-without-app-attest`): la tarjeta de «Dónde viven tus
  datos» **entera**, también «Activar la nube en este dispositivo», que es entrar a una cuenta que ya existe. Lo eligió
  Jürgen a las 7:1x: sin token las dos caras acaban en el mismo reintento sin fin. Y a las 8:0x eligió **anotar, no
  arreglar**, el colateral de Grupos («Se decide en Ajustes») en `groups-block-has-no-route-to-storage-settings`.

**Why:** era la decisión del owner del 2026-07-06. El fallo caro es el inverso —un iPhone real que pierde la card, el
botón o la tarjeta— y ningún simulador lo prueba: por eso los tres tickets se quedan en `qa`.

**How to apply:**

- Si un `/qa` coge estos tickets, los pasos en iPhone real comparten montaje (instalación nueva de TestFlight y, para
  Ajustes, datos en iCloud privado). **Borrar la app se lleva lo que no esté en iCloud o en la nube**: el guion lo avisa,
  respétalo. Y el faro de iCloud puede cambiar «No encontramos una cuenta» por el mismatch: los dos valen.
- **Si en el simulador no sale «Tu cuenta en la nube», «Crear mi cuenta» o la tarjeta de Ajustes, no es la configuración
  remota: es esta puerta.** La devuelve `Yala Dev` con `YALA_DEV_SHARED_SECRET` en el scheme, y ese secreto **no está en
  `~/Secrets`** (medido dos veces el 16-sep): es un secret de Wrangler del gateway de staging, que no se lee de vuelta. Lo
  tiene Jürgen o hay que rotarlo.
- Lo que la puerta no cubre, a propósito: entrar con una cuenta que ya existe desde el Welcome
  (`cloud-hydration-spinner-never-gives-up-without-attest`) y quien ya empezó una migración antes del cambio.

Relacionado: [[telefono-sin-attest-veredicto-y-salida]] · [[aviso-attest-personal-en-dos-superficies]] ·
[[el-source-scan-de-dos-literales-no-es-una-red]]
