---
id: migration-activation-drops-pending-effects-it-never-restores
status: backlog
priority: medium
area: "modo-nube, migración"
created: 2026-09-16
source: "review adversarial de `settings-migrate-to-cloud-adopts-silently-instead-of-migrating` (lente de máquina y runner, hallazgo 3), 2026-09-16"
---

# Tocar «Activar la nube» tira los pendientes de la fase de origen, y cancelar no los devuelve

## El problema, en lenguaje de usuario

Vuelvo a iCloud sin conexión: la app termina en iCloud, pero la llamada que le dice al servidor que la vuelta acabó se
queda pendiente. Antes de que se reintente, toco «Activar la nube» sin red y veo «No pudimos comprobar tu cuenta. No
cambiamos nada». Sí cambió algo: esa llamada ya no se reintenta nunca, y la cuenta se queda en la nube a medio cerrar.

## Lo medido (2026-09-16, rama `encargo/2026-09-16-settings-migrate-to-cloud-adopts-silently-instead-of-migrating`)

- El cierre de la vuelta a iCloud journalea `icloudActive` con `[.deleteCloudKitMarker, .clearCloudBeacon,
  .persistICloudMode, .completeReverseServer]` (`MigrationStateMachine`, `(.reverseUpload, .reverseUploadCompleted)`).
  Sin red, `.completeReverseServer` queda pendiente; es lo único que llama a `reverse_complete`
  (`MigrationWorkExecutor`), que escribe `reverted_at` y `kind = 'groups_only'`.
- `(.icloudActive, .userActivated)` y `(.notStarted, .userActivated)` pasan a `consent` sin efectos, y
  `MigrationRunner.handle` **reemplaza** los pendientes al journalear (`state.setPendingEffects(nextPending)`). Solo la
  vuelta a iCloud guarda y repone los del origen (`ReverseOriginPendingEffects`); la ida no.
- Las salidas de la ida vuelven a `notStarted` sin efectos: `consentDeclined`, `signInFailed` y, desde el ticket de
  origen, `claimRefusedExistingAccount`.

**No es una regresión de ese ticket**: la pérdida ya ocurría con «Cancelar» en el consentimiento o con un inicio de
sesión fallido. La comprobación nueva añade otra salida por la que pasa, y un aviso que dice «No cambiamos nada».

## Qué se espera

Aplicar a la ida el molde de la vuelta: guardar los pendientes del origen al tocar y reponerlos en toda salida que
vuelva antes del claim (`consentDeclined`, `signInFailed`, `claimRefusedExistingAccount`). Es la lección de
`.claude/agent-memory/frank/feedback_mi_arreglo_deja_el_mecanismo_sin_productor.md`: una salida que deshace un gesto
devuelve lo que la entrada tiró.

## Criterios de aceptación

- [ ] Con `.completeReverseServer` pendiente en `icloudActive`, tocar «Activar la nube» y salir antes del claim deja el
      pendiente en el journal, y el siguiente `resume` lo ejecuta.
- [ ] Un claim que sí empieza la migración no repone nada (test con el executor falso).
