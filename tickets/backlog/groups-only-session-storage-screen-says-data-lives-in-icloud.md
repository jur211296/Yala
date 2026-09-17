---
id: groups-only-session-storage-screen-says-data-lives-in-icloud
status: backlog
priority: low
area: "sesiones, ajustes, copy"
created: 2026-09-16
updated: 2026-09-16
source: "review adversarial de `cloud-migration-offers-the-cloud-to-a-phone-without-app-attest` (2026-09-16)"
---

# En una sesión solo-grupos, «Dónde viven tus datos» dice que tus datos viven en tu iCloud privado

## El problema, en lenguaje de usuario

Uso Yala solo para mis grupos: en este teléfono no tengo finanzas personales. En Perfil, «Tu cuenta de Yala» me dice «Tu
cuenta solo guarda tus grupos; en este dispositivo no hay datos personales». Justo debajo, «Dónde viven tus datos» me
abre una pantalla que dice «iCloud privado: Tus datos viven en tu dispositivo y se sincronizan por tu iCloud privado». Las
dos no pueden ser verdad a la vez.

## Lo medido (leído en el código, sin ejecutar)

- La fila de Perfil no mira la forma de la sesión: `StorageRowGateLogic.isVisible` pide backend configurado y
  `remoteEnabled || isEngaged || hasGroupsAccountToDetach` (`ProfileView.swift`, bloque de `storage_settings_row`), y
  `isGroupsOnlyShell` (`!SessionState.shared.hasPrivateSession`) no entra. Producción sirve `cloudModeRolloutPercent: 100`
  (`curl …/config`, 2026-09-16), así que la fila se ve.
- Dentro, `StorageSettingsView.statusCard` pinta «iCloud privado» con `storage.status.icloudBody` para todo lo que no sea
  `.cloud`. La sección de Grupos es `.notApplicable` en `.cloudGroupsOnly` (`GroupsAssociationLogic.sectionState`).
- Lo que «Tu cuenta de Yala» dice en esa sesión sale de `settings.yalaAccountDataLocationGroupsOnlyNoPrivate`
  (`YalaAccountView.swift`).
- **Desde el 2026-09-16 es lo único que hay en la pantalla para un teléfono sin App Attest**: la tarjeta de la nube se
  esconde sin App Attest (`cloud-migration-offers-the-cloud-to-a-phone-without-app-attest`). La contradicción es
  anterior: con App Attest la pantalla enseña además «Migrar a la nube» a una sesión sin datos personales, y **qué haría
  esa migración en una sesión solo-grupos no está medido**.

- **Y el aviso de «Migrar a la nube» promete un gesto que aquí no existe** (segunda pasada de la review de
  `settings-migrate-to-cloud-adopts-silently-instead-of-migrating`, 2026-09-16). Si la cuenta de esa sesión se completó
  en otro dispositivo, «Activar la nube» enseña «Esa cuenta ya tiene finanzas personales» con el cuerpo
  `storage.migrateBlock.personalDataBodyNoSwitch`, que termina en «primero desasocia esta en «Grupos»», y en una sesión
  solo-grupos esa sección es `.notApplicable`. Medido que la sección no está; que esa sesión llegue a la tarjeta con una
  cuenta completa es inferido. Si se mantiene la fila (opción 2), el cuerpo se elige con
  `GroupsAssociationLogic.offersDetach`.

## Lo que hay que decidir (Jürgen)

1. Ocultar la fila en una sesión solo-grupos, como ya se oculta «Importar» (`if !isGroupsOnlyShell`).
2. Mantenerla y darle a esa sesión su propio texto de estado (copy nuevo en 16 idiomas).
3. Dejarlo: la fila no rompe nada y la población solo-grupos es pequeña.

## Relación con otros tickets

- `cloud-migration-offers-the-cloud-to-a-phone-without-app-attest` — de donde sale.
- `shell-derives-from-two-session-axes` — el eje de sesión que decide qué filas ve cada forma de sesión.
