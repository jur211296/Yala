---
id: restore-icloud-disabled-asks-a-born-cloud-user-for-icloud
status: backlog
priority: low
area: "welcome, restore"
created: 2026-11-05
updated: 2026-11-05
source: "§2 de `restore-beacon-outlives-account-deletion`, fuera del lote N3"
---

# Restaurar sin iCloud le pide iCloud a quien nació en la nube

## Qué le pasa al usuario

Quien creó su cuenta en la nube y reinstala con iCloud apagado elige «Restaurar» y lee «Necesitas tener iCloud activado para recuperar tus datos». Sus datos no están en iCloud: están en su cuenta de Yala.

## Medido (2026-11-05)

`WelcomeRestoreView.startSearch()` corta por `iCloudSyncService.shared.isAccountAvailable` antes que nada y pinta `.iCloudDisabled`. El faro vive en el iCloud-KV, así que con iCloud apagado no se puede leer: no hay señal en el teléfono que separe a los dos usuarios.

## Qué hay que decidir

Si el texto de `.iCloudDisabled` añade una salida para quien tiene cuenta en la nube («¿Usas tu cuenta de Yala? Entra con ella»), o se deja.
