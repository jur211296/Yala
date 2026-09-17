---
id: migrate-attempt-session-survives-a-relaunch-mid-attempt
status: backlog
priority: low
area: "modo-nube, settings"
created: 2026-09-16
source: "review adversarial de `settings-migrate-to-cloud-adopts-silently-instead-of-migrating` (lente de identidad, hallazgo 3), 2026-09-16"
---

# Si Yala se cierra a mitad de «Activar la nube», la cuenta con la que se firmó se queda como cuenta de grupos

## El problema, en lenguaje de usuario

Toco «Activar la nube», acepto, entro con una cuenta de Google y, mientras Yala comprueba la cuenta, se cierra la app
(o la cierro yo). Al volver a abrirla no ha migrado nada, pero esa cuenta aparece como mi cuenta para grupos, aunque
sea una cuenta que ya tenía finanzas de otra persona. Y «Activar la nube» ya no me ofrece «Usar otra cuenta».

## Lo medido (2026-09-16, rama `encargo/2026-09-16-settings-migrate-to-cloud-adopts-silently-instead-of-migrating`)

- `CloudMigrationController.continueToClaim` cierra la sesión que abrió el intento en toda parada, antes de devolver el
  runner al inicio. Pero entre firmar y ese cierre hay una llamada de red (`/account/exists`) y, si deja pasar, el
  claim entero.
- Tras un relanzamiento, `authenticating` se normaliza a `notStarted` y la sesión sigue viva. El registrador del
  arranque (`GroupsAssociationRegistrar.syncFromLiveSessionIfNeeded`, `AppBootstrapper`) la asocia como cuenta de grupos
  en un iPhone con sesión privada, sin mirar si es completa.
- Un claim aparcado que contesta `existing_stable` al retomar tras un relanzamiento sí se para (la intención va en el
  journal, y el arranque pasa por `CloudMigrationController.resumeIfNeeded` → `resume`), pero
  `announceForwardClaimRefusal` ya no tiene el intento en memoria: no cierra la sesión, el aviso sale sin «Usar otra
  cuenta» y con el motivo genérico, «Esa cuenta ya tiene finanzas personales», también si la cuenta volvió a iCloud.

## Opciones, sin decidir

- Una marca persistida de «sesión abierta por un intento de migrar, sin veredicto» que el arranque cierre antes del
  registrador.
- Journalear junto a la intención si la sesión la abrió el intento.

## Criterios de aceptación

- [ ] Un relanzamiento a mitad del intento no deja asociada como cuenta de grupos la cuenta con la que se firmó.
- [ ] La sesión de grupos que ya había antes del intento no se cierra nunca.
