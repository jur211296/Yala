---
id: cloud-migration-offers-the-cloud-to-a-phone-without-app-attest
status: backlog
priority: low
area: "modo-nube, attest, migración"
created: 2026-09-16
updated: 2026-09-16
source: "alcance de `cloud-onboarding-offers-the-cloud-to-a-phone-without-app-attest` (2026-09-16): la puerta del attest solo gatea el alta"
---

# «Migrar a la nube» se ofrece a un teléfono que no puede conseguir App Attest

## El problema, en lenguaje de usuario

Tengo mis datos en mi iCloud privado y mi teléfono no tiene App Attest. En Ajustes → «¿Dónde viven tus datos?» me ofrecen
«Migrar a la nube». Acepto el consentimiento, confirmo dos veces y la migración no termina nunca, y no sé por qué.

## Lo medido (leído en el código, sin ejecutar)

- Desde el 2026-09-16, «Es mi primera vez» no ofrece la nube a un teléfono sin App Attest
  (`WelcomeAccountChoiceLogic.visibleNewOptions`, con `AppAttestClient.canObtainSessionToken`). Esa puerta solo gatea el
  ALTA, por decisión del encargo.
- La card de la migración no mira el attest: `StorageRowGateLogic.offersCloudMigrationEntry` es
  `remoteEnabled || isEngaged`, y `StorageSettingsView.abortIfCloudEntryClosed` re-mide solo ese término.
- La migración sube con `SyncPushClient` y un `attestProvider` que devuelve `nil` sin token
  (`CloudMigrationController.makeExecutor`, `{ try? await session.attestToken() }`). `/sync/push` exige attest en producción
  (`requireUserAndAttest`, `.claude/rules/gateway-attest.md`).
- `MigrationSnapshotUploader` trata un push que no da 2xx como `.transient`, y el runner reintenta después: el rechazo del
  attest no tiene una clasificación propia.

## Lo inferido, sin ejecutar

- **No deja a nadie atrapado**: según `MigrationStateMachine`, el servidor confirma antes de que se persista el modo, así que
  una subida rechazada no debería cambiar a `.cloud`.
- **Qué ve la persona, no se sabe**: por el `.transient` de arriba lo probable es un reintento sin fin, pero no está medido
  si la pantalla enseña un progreso parado, el error genérico u otra cosa.

## Lo que hay que decidir (Jürgen)

1. Extender la puerta del alta a la card de migración: sin App Attest no se ofrece «Migrar a la nube».
2. Ofrecerla igual y decir por qué falla, con un error propio del attest.
3. Dejarlo: la población está sin medir y la migración no pierde datos.

## Relación con otros tickets

- `cloud-onboarding-offers-the-cloud-to-a-phone-without-app-attest` — la puerta del alta, de donde sale.
- `cloud-sign-in-screen-offers-sign-up-to-a-phone-without-app-attest` — las dos salidas al alta de la pantalla de entrar.
  Desde el 2026-09-16 pasan por la puerta, así que de los dos sitios que reclaman una cuenta completa en la nube
  (`BornCloudSignUpService` y el claim de `MigrationWorkExecutor`) este es el único que no la mira.
- `cloud-hydration-spinner-never-gives-up-without-attest` — lo que ve quien entra con una cuenta que ya existe, que la
  puerta tampoco cubre.
